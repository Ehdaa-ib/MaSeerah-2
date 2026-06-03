/**
 * Admin feedback reply — shared by sendFeedbackReply and sendPasswordResetOtp (mode=feedbackReply).
 */
const { HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const { sendFeedbackReplyEmail } = require('../services/email_service');

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function isValidEmailFormat(email) {
  const e = normalizeEmail(email);
  return e.length > 3 && e.includes('@') && !e.startsWith('@') && e.includes('.');
}

function isAdminEmailAddress(email) {
  const e = normalizeEmail(email);
  return /^(ehdaa\.test|q\.test|m\.test|r\.test|malak)@admin\.com$/.test(e);
}

async function resolveAdminEmail(request) {
  const tokenEmail = request.auth.token.email
    ? normalizeEmail(request.auth.token.email)
    : '';
  if (tokenEmail && isValidEmailFormat(tokenEmail)) {
    return tokenEmail;
  }
  const uid = request.auth.uid;
  if (uid) {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (userDoc.exists) {
      const profileEmail = normalizeEmail(userDoc.data().email || '');
      if (isValidEmailFormat(profileEmail)) return profileEmail;
    }
  }
  return tokenEmail;
}

async function assertCallerIsAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'You must be signed in to send replies.');
  }
  const tokenEmail = request.auth.token.email
    ? normalizeEmail(request.auth.token.email)
    : '';
  if (tokenEmail && isAdminEmailAddress(tokenEmail)) {
    return tokenEmail;
  }
  const uid = request.auth.uid;
  if (uid) {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data().role === 'admin') {
      const profileEmail = normalizeEmail(userDoc.data().email || '');
      return isValidEmailFormat(profileEmail) ? profileEmail : tokenEmail;
    }
  }
  throw new HttpsError('permission-denied', 'Only admins can send feedback replies.');
}

function authErrorCode(err) {
  if (!err) return '';
  if (typeof err.code === 'string') return err.code;
  if (err.errorInfo && typeof err.errorInfo.code === 'string') {
    return err.errorInfo.code;
  }
  return '';
}

async function resolveCustomerEmailForUserId(userId) {
  const uid = String(userId || '').trim();
  if (!uid) return null;

  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  if (userDoc.exists) {
    const fromProfile = normalizeEmail(userDoc.data().email || '');
    if (isValidEmailFormat(fromProfile)) return fromProfile;
  }

  try {
    const authUser = await admin.auth().getUser(uid);
    const fromAuth = normalizeEmail(authUser.email || '');
    if (isValidEmailFormat(fromAuth)) return fromAuth;
  } catch (e) {
    const ac = authErrorCode(e);
    if (ac !== 'auth/user-not-found') {
      logger.error('getUser failed while resolving feedback recipient', { uid, err: e });
    }
  }
  return null;
}

async function appendFeedbackAdminResponse(feedbackId, message, adminEmail) {
  const trimmed = String(message || '').trim();
  if (!trimmed) {
    throw new HttpsError('invalid-argument', 'Message body is required.');
  }

  const ref = admin.firestore().collection('feedback').doc(feedbackId);
  await admin.firestore().runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Feedback not found.');
    }
    const prev = Array.isArray(snap.data().adminResponses)
      ? snap.data().adminResponses
      : [];
    const next = [
      ...prev,
      {
        message: trimmed,
        adminEmail: String(adminEmail || '').trim(),
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
        channel: 'email',
      },
    ];
    txn.update(ref, {
      adminResponses: next,
      adminResponse: trimmed,
      respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

/**
 * @param {import('firebase-functions/v2/https').CallableRequest} request
 */
async function handleSendFeedbackReply(request) {
  const adminEmail = await assertCallerIsAdmin(request);

  const feedbackId =
    request.data && request.data.feedbackId
      ? String(request.data.feedbackId).trim()
      : '';
  const subjectRaw =
    request.data && request.data.subject
      ? String(request.data.subject).trim()
      : 'Feedback Response';
  const messageBody =
    request.data && request.data.messageBody
      ? String(request.data.messageBody).trim()
      : '';

  logger.info('sendFeedbackReply invoked', {
    feedbackId,
    adminUid: request.auth && request.auth.uid,
    adminEmail: request.auth && request.auth.token.email,
    subjectLength: subjectRaw.length,
    bodyLength: messageBody.length,
  });

  if (!feedbackId) {
    throw new HttpsError('invalid-argument', 'Feedback id is required.');
  }
  if (!messageBody) {
    throw new HttpsError('invalid-argument', 'Message body is required.');
  }
  if (messageBody.length > 12000) {
    throw new HttpsError('invalid-argument', 'Message is too long.');
  }

  const subject =
    subjectRaw.length > 0 ? subjectRaw.slice(0, 200) : 'Feedback Response';

  const feedbackSnap = await admin
    .firestore()
    .collection('feedback')
    .doc(feedbackId)
    .get();
  if (!feedbackSnap.exists) {
    throw new HttpsError('not-found', 'Feedback not found.');
  }

  const feedback = feedbackSnap.data();
  const userId = feedback.userId ? String(feedback.userId) : '';
  const customerEmail = await resolveCustomerEmailForUserId(userId);
  if (!customerEmail) {
    throw new HttpsError(
      'failed-precondition',
      'No email address found for this customer. They may need to sign in again or update their profile.',
    );
  }

  const senderEmail = await resolveAdminEmail(request);
  if (!isValidEmailFormat(senderEmail)) {
    logger.error('sendFeedbackReply: admin has no valid email', {
      tokenEmail: request.auth.token && request.auth.token.email,
      adminEmail,
      uid: request.auth.uid,
    });
    throw new HttpsError(
      'failed-precondition',
      'Your admin account does not have a valid email for replies. Sign in with an admin email or update your profile.',
    );
  }

  logger.info('sendFeedbackReply sending email', {
    feedbackId,
    customerEmail,
    senderEmail,
    subject,
  });

  try {
    await sendFeedbackReplyEmail({
      to: customerEmail,
      subject,
      text: messageBody,
      adminEmail: senderEmail,
    });
  } catch (e) {
    logger.error('sendFeedbackReplyEmail failed', {
      feedbackId,
      err: e,
      message: e && e.message,
      stack: e && e.stack,
    });
    if (e instanceof HttpsError) throw e;
    throw new HttpsError(
      'failed-precondition',
      e && e.message
        ? String(e.message)
        : 'Could not send email. Check SMTP configuration in Cloud Functions.',
    );
  }

  try {
    await appendFeedbackAdminResponse(feedbackId, messageBody, senderEmail);
  } catch (e) {
    logger.error('appendFeedbackAdminResponse after email failed', {
      feedbackId,
      err: e,
      message: e && e.message,
      stack: e && e.stack,
    });
    if (e instanceof HttpsError) throw e;
    throw new HttpsError(
      'failed-precondition',
      'Email was sent but saving the reply in Firestore failed. Check Cloud Function logs.',
    );
  }

  logger.info('sendFeedbackReply success', { feedbackId, to: customerEmail });
  return { ok: true, to: customerEmail };
}

module.exports = { handleSendFeedbackReply };
