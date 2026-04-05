/**
 * Password reset with 6-digit code sent by email.
 *
 * Deploy: firebase deploy --only functions
 *
 * Set SMTP for real emails (Firebase Console → Functions → configuration, or .env for emulator):
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
 * Without SMTP, the code is only logged in Cloud Logging (check Firebase console after testing).
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

if (!admin.apps.length) {
  admin.initializeApp();
}

/** Must match Flutter: FirebaseFunctions.instanceFor(region: 'us-central1'). */
const callableRegion = 'us-central1';

function authErrorCode(err) {
  if (!err) return '';
  if (typeof err.code === 'string') return err.code;
  if (err.errorInfo && typeof err.errorInfo.code === 'string') {
    return err.errorInfo.code;
  }
  return '';
}

function docIdForEmail(email) {
  return crypto.createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

async function sendEmailWithCode(email, code) {
  const host = process.env.SMTP_HOST;
  const port = process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : 587;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.SMTP_FROM || 'noreply@localhost';

  if (!host || !user || !pass) {
    logger.warn(`[password-reset] SMTP not set. Code for ${email}: ${code}`);
    return;
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });

  await transporter.sendMail({
    from,
    to: email,
    subject: 'MaSeerah — Your verification code',
    text:
      `Your verification code is: ${code}\n\n` +
      'It expires in 15 minutes.\n\n' +
      'If you did not request a password reset, you can ignore this email.',
  });
}

exports.sendPasswordResetCode = onCall(
  { region: callableRegion },
  async (request) => {
    const email =
      request.data && request.data.email ? String(request.data.email).trim() : '';
    if (!email || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'Valid email is required.');
    }

    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (e) {
      const ac = authErrorCode(e);
      if (ac === 'auth/user-not-found') {
        throw new HttpsError('not-found', 'No account found with this email.');
      }
      logger.error('getUserByEmail failed', { code: ac, err: e });
      throw new HttpsError(
        'internal',
        'Could not verify this email. Check Firebase Auth and billing, then try again.',
      );
    }

    const code = String(Math.floor(100000 + Math.random() * 900000));
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + 15 * 60 * 1000,
    );

    try {
      await admin
        .firestore()
        .collection('password_reset_codes')
        .doc(docIdForEmail(email))
        .set({
          email,
          code,
          expiresAt,
          uid: userRecord.uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (e) {
      logger.error('password_reset_codes write failed', e);
      throw new HttpsError(
        'internal',
        'Could not save the verification code. Check Firestore rules and APIs.',
      );
    }

    try {
      await sendEmailWithCode(email, code);
    } catch (e) {
      logger.error('sendEmailWithCode failed', e);
      await admin
        .firestore()
        .collection('password_reset_codes')
        .doc(docIdForEmail(email))
        .delete()
        .catch(() => {});
      throw new HttpsError(
        'internal',
        'Could not send the email. Check SMTP settings for this function.',
      );
    }

    return { ok: true };
  },
);

exports.verifyPasswordResetCode = onCall({ region: callableRegion }, async (request) => {
  const email =
    request.data && request.data.email ? String(request.data.email).trim() : '';
  const code =
    request.data && request.data.code ? String(request.data.code).trim() : '';
  if (!email || !code) {
    throw new HttpsError('invalid-argument', 'Email and code are required.');
  }
  if (code.length !== 6 || !/^\d{6}$/.test(code)) {
    throw new HttpsError('invalid-argument', 'Enter the 6-digit code.');
  }

  const ref = admin
    .firestore()
    .collection('password_reset_codes')
    .doc(docIdForEmail(email));
  const doc = await ref.get();
  if (!doc.exists) {
    throw new HttpsError(
      'permission-denied',
      'Incorrect or expired verification code.',
    );
  }
  const d = doc.data();
  if (d.code !== code) {
    throw new HttpsError('permission-denied', 'Incorrect verification code.');
  }
  if (d.expiresAt.toMillis() < Date.now()) {
    throw new HttpsError(
      'deadline-exceeded',
      'This code has expired. Request a new one.',
    );
  }
  return { ok: true };
});

exports.completePasswordResetWithCode = onCall({ region: callableRegion }, async (request) => {
  const email =
    request.data && request.data.email ? String(request.data.email).trim() : '';
  const code =
    request.data && request.data.code ? String(request.data.code).trim() : '';
  const newPassword =
    request.data && request.data.newPassword
      ? String(request.data.newPassword)
      : '';
  if (!email || !code || !newPassword) {
    throw new HttpsError(
      'invalid-argument',
      'Email, code, and new password are required.',
    );
  }
  if (newPassword.length < 6) {
    throw new HttpsError(
      'invalid-argument',
      'Password must be at least 6 characters.',
    );
  }

  const ref = admin
    .firestore()
    .collection('password_reset_codes')
    .doc(docIdForEmail(email));
  const doc = await ref.get();
  if (!doc.exists) {
    throw new HttpsError(
      'permission-denied',
      'Incorrect or expired verification code.',
    );
  }
  const d = doc.data();
  if (d.code !== code) {
    throw new HttpsError('permission-denied', 'Incorrect verification code.');
  }
  if (d.expiresAt.toMillis() < Date.now()) {
    throw new HttpsError(
      'deadline-exceeded',
      'This code has expired. Request a new one.',
    );
  }

  await admin.auth().updateUser(d.uid, { password: newPassword });
  await ref.delete();
  return { ok: true };
});
