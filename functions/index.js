/**
 * Password reset via 6-digit OTP (email). Does NOT use Firebase Auth reset links.
 *
 * Callables (region us-central1 — match Flutter FirebaseFunctions.instanceFor):
 *   sendPasswordResetOtp, verifyPasswordResetOtp, resetPasswordWithOtp
 *
 * Firestore: password_reset_otps/{sha256(email)} — client denied by rules; Admin SDK only.
 *
 * Secrets / env:
 *   OTP_PEPPER     — required in production (min 16 chars), HMAC key for hashing OTPs
 *   SMTP_*         — see services/email_service.js
 *
 * Deploy: firebase deploy --only functions
 */

require('./load_env').loadEnvFile();

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { sendPasswordResetOtpEmail } = require('./services/email_service');

if (!admin.apps.length) {
  admin.initializeApp();
}

/** Binds Secret Manager → process.env at runtime when listed in `secrets: []` below. */
const otpPepperSecret = defineSecret('OTP_PEPPER');

const callableRegion = 'us-central1';

const OTP_TTL_MS = 15 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_RESENDS = 5;
const MAX_VERIFY_ATTEMPTS = 5;

function authErrorCode(err) {
  if (!err) return '';
  if (typeof err.code === 'string') return err.code;
  if (err.errorInfo && typeof err.errorInfo.code === 'string') {
    return err.errorInfo.code;
  }
  return '';
}

function docIdForEmail(email) {
  return crypto.createHash('sha256').update(normalizeEmail(email)).digest('hex');
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function isValidEmailFormat(email) {
  const e = normalizeEmail(email);
  return e.length > 3 && e.includes('@') && !e.startsWith('@') && e.includes('.');
}

function getOtpPepper() {
  const fromEnv = process.env.OTP_PEPPER;
  if (fromEnv && String(fromEnv).trim().length >= 16) {
    return String(fromEnv).trim();
  }
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    logger.warn(
      'OTP_PEPPER not set; using emulator-only default (set OTP_PEPPER for production).',
    );
    return 'emulator-only-otp-pepper-min-16-chars!!';
  }
  try {
    const fromSecret = otpPepperSecret.value();
    if (fromSecret && String(fromSecret).trim().length >= 16) {
      return String(fromSecret).trim();
    }
  } catch (err) {
    logger.warn('Could not read OTP_PEPPER secret', err);
  }
  throw new HttpsError(
    'failed-precondition',
    'Password reset is not configured yet. Ask the developer to set OTP_PEPPER ' +
      '(a random secret, at least 16 characters) for Cloud Functions, then redeploy. ' +
      'Command: firebase functions:secrets:set OTP_PEPPER',
  );
}

function hashOtp(email, plainCode, pepper) {
  const payload = `${normalizeEmail(email)}|${plainCode}`;
  return crypto.createHmac('sha256', pepper).update(payload).digest('hex');
}

function generateSixDigitCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

exports.sendPasswordResetOtp = onCall(
  { region: callableRegion, secrets: [otpPepperSecret] },
  async (request) => {
  const emailRaw =
    request.data && request.data.email ? String(request.data.email) : '';
  const email = normalizeEmail(emailRaw);
  if (!isValidEmailFormat(email)) {
    throw new HttpsError('invalid-argument', 'Enter a valid email address.');
  }

  let pepper;
  try {
    pepper = getOtpPepper();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError('internal', 'Configuration error.');
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
    throw new HttpsError('internal', 'Could not verify account. Try again later.');
  }

  const docId = docIdForEmail(email);
  const ref = admin.firestore().collection('password_reset_otps').doc(docId);
  const now = Date.now();

  let snap = await ref.get();
  let d = snap.exists ? snap.data() : null;

  if (d && d.consumed === true) {
    await ref.delete().catch(() => {});
    d = null;
  }

  if (d) {
    const lastSent =
      d.lastSentAt && d.lastSentAt.toMillis ? d.lastSentAt.toMillis() : 0;
    const resendCount = typeof d.resendCount === 'number' ? d.resendCount : 0;
    if (resendCount >= MAX_RESENDS) {
      throw new HttpsError(
        'resource-exhausted',
        'Maximum resend attempts reached. Try again later.',
      );
    }
    if (lastSent > 0 && now - lastSent < RESEND_COOLDOWN_MS) {
      const waitSec = Math.ceil((RESEND_COOLDOWN_MS - (now - lastSent)) / 1000);
      throw new HttpsError(
        'resource-exhausted',
        `Please wait ${waitSec} seconds before requesting another code.`,
      );
    }
  }

  const plainCode = generateSixDigitCode();
  const hashedCode = hashOtp(email, plainCode, pepper);
  const expiresAt = admin.firestore.Timestamp.fromMillis(now + OTP_TTL_MS);
  const lastSentAt = admin.firestore.FieldValue.serverTimestamp();

  const nextResend = d
    ? (typeof d.resendCount === 'number' ? d.resendCount : 0) + 1
    : 1;

  const createdAtValue =
    d && d.createdAt ? d.createdAt : admin.firestore.FieldValue.serverTimestamp();

  const payload = {
    email,
    hashedCode,
    uid: userRecord.uid,
    createdAt: createdAtValue,
    expiresAt,
    attemptCount: 0,
    resendCount: nextResend,
    lastSentAt,
    verified: false,
    consumed: false,
  };

  try {
    await ref.set(payload, { merge: false });
  } catch (e) {
    logger.error('password_reset_otps write failed', e);
    throw new HttpsError('internal', 'Could not save reset code. Try again.');
  }

  try {
    await sendPasswordResetOtpEmail(email, plainCode);
  } catch (e) {
    logger.error('sendPasswordResetOtpEmail failed', e);
    await ref.delete().catch(() => {});
    if (e instanceof HttpsError) throw e;
    throw new HttpsError(
      'internal',
      'Could not send email. Configure SMTP for Functions or check logs.',
    );
  }

  return { ok: true };
  },
);

exports.verifyPasswordResetOtp = onCall(
  { region: callableRegion, secrets: [otpPepperSecret] },
  async (request) => {
  const email = normalizeEmail(
    request.data && request.data.email ? String(request.data.email) : '',
  );
  const code =
    request.data && request.data.code ? String(request.data.code).trim() : '';
  if (!isValidEmailFormat(email) || !code) {
    throw new HttpsError('invalid-argument', 'Email and 6-digit code are required.');
  }
  if (code.length !== 6 || !/^\d{6}$/.test(code)) {
    throw new HttpsError('invalid-argument', 'Enter the 6-digit code.');
  }

  let pepper;
  try {
    pepper = getOtpPepper();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError('internal', 'Configuration error.');
  }

  const ref = admin
    .firestore()
    .collection('password_reset_otps')
    .doc(docIdForEmail(email));
  const doc = await ref.get();
  if (!doc.exists) {
    throw new HttpsError(
      'permission-denied',
      'Incorrect or expired code.',
    );
  }

  const data = doc.data();
  if (data.consumed === true) {
    throw new HttpsError('permission-denied', 'This code has already been used.');
  }
  if (data.expiresAt.toMillis() < Date.now()) {
    throw new HttpsError(
      'deadline-exceeded',
      'This code has expired. Request a new one.',
    );
  }

  const attempts = typeof data.attemptCount === 'number' ? data.attemptCount : 0;
  if (attempts >= MAX_VERIFY_ATTEMPTS) {
    throw new HttpsError(
      'permission-denied',
      'Too many incorrect attempts. Request a new code.',
    );
  }

  const expectedHash = data.hashedCode;
  const actualHash = hashOtp(email, code, pepper);
  if (actualHash !== expectedHash) {
    await ref.update({
      attemptCount: admin.firestore.FieldValue.increment(1),
    });
    throw new HttpsError('permission-denied', 'Incorrect code.');
  }

  await ref.update({ verified: true });
  return { ok: true };
  },
);

exports.resetPasswordWithOtp = onCall(
  { region: callableRegion, secrets: [otpPepperSecret] },
  async (request) => {
  const email = normalizeEmail(
    request.data && request.data.email ? String(request.data.email) : '',
  );
  const code =
    request.data && request.data.code ? String(request.data.code).trim() : '';
  const newPassword =
    request.data && request.data.newPassword
      ? String(request.data.newPassword)
      : '';

  if (!isValidEmailFormat(email) || !code || !newPassword) {
    throw new HttpsError(
      'invalid-argument',
      'Email, code, and new password are required.',
    );
  }
  if (code.length !== 6 || !/^\d{6}$/.test(code)) {
    throw new HttpsError('invalid-argument', 'Enter the 6-digit code.');
  }
  if (newPassword.length < 6) {
    throw new HttpsError(
      'invalid-argument',
      'Password must be at least 6 characters.',
    );
  }

  let pepper;
  try {
    pepper = getOtpPepper();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError('internal', 'Configuration error.');
  }

  const ref = admin
    .firestore()
    .collection('password_reset_otps')
    .doc(docIdForEmail(email));
  const doc = await ref.get();
  if (!doc.exists) {
    throw new HttpsError('permission-denied', 'Incorrect or expired code.');
  }

  const data = doc.data();
  if (data.consumed === true) {
    throw new HttpsError('permission-denied', 'This code has already been used.');
  }
  if (data.verified !== true) {
    throw new HttpsError(
      'failed-precondition',
      'Verify your code before setting a new password.',
    );
  }
  if (data.expiresAt.toMillis() < Date.now()) {
    throw new HttpsError(
      'deadline-exceeded',
      'This code has expired. Request a new one.',
    );
  }

  const actualHash = hashOtp(email, code, pepper);
  if (actualHash !== data.hashedCode) {
    throw new HttpsError('permission-denied', 'Incorrect code.');
  }

  try {
    await admin.auth().updateUser(data.uid, { password: newPassword });
  } catch (e) {
    logger.error('updateUser password failed', e);
    throw new HttpsError('internal', 'Could not update password. Try again.');
  }

  await ref
    .update({
      consumed: true,
      hashedCode: admin.firestore.FieldValue.delete(),
    })
    .catch(() => {});
  await ref.delete().catch(() => {});

  return { ok: true };
  },
);

