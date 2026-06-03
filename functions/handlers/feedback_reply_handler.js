/**
 * Admin feedback reply — sendFeedbackReply + sendPasswordResetOtp (mode=feedbackReply).
 */
const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { sendFeedbackReplyEmail } = require('../services/email_service');
const { logStep, logError } = require('../util/log_step');
const { throwCallableError } = require('../util/callable_errors');
const { logSmtpEnvPresence } = require('../config/smtp_params');

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

function tokenEmail(request) {
  return request.auth && request.auth.token && request.auth.token.email
    ? normalizeEmail(request.auth.token.email)
    : '';
}

async function resolveAdminEmail(request) {
  const fromToken = tokenEmail(request);
  if (isValidEmailFormat(fromToken)) {
    return fromToken;
  }
  const uid = request.auth && request.auth.uid;
  if (!uid) return '';
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  if (userDoc.exists) {
    const profileEmail = normalizeEmail(userDoc.data().email || '');
    if (isValidEmailFormat(profileEmail)) return profileEmail;
  }
  return fromToken;
}

async function assertCallerIsAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'You must be signed in to send replies.');
  }
  const email = tokenEmail(request);
  if (email && isAdminEmailAddress(email)) {
    return email;
  }
  const uid = request.auth.uid;
  if (uid) {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data().role === 'admin') {
      const profileEmail = normalizeEmail(userDoc.data().email || '');
      return isValidEmailFormat(profileEmail) ? profileEmail : email;
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
      logError('resolveCustomerEmail getUser failed', e);
    }
  }
  return null;
}

async function appendFeedbackAdminResponse(feedbackId, message, adminEmail) {
  const trimmed = String(message || '').trim();
  if (!trimmed) {
    throw new HttpsError('invalid-argument', 'Message body is required.');
  }

  logStep('Saving reply to Firestore', { feedbackId });

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
  logStep('Firestore reply saved');
}

/**
 * @param {import('firebase-functions/v2/https').CallableRequest} request
 */
async function handleSendFeedbackReply(request) {
  console.log('Function started');
  logSmtpEnvPresence();

  const adminEmailAuth = await assertCallerIsAdmin(request);
  logStep('Admin email (auth)', { adminEmail: adminEmailAuth || '(from profile next)' });

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

  if (!feedbackId) {
    throwCallableError('invalid-argument', 'Feedback id is required.');
  }
  if (!subjectRaw) {
    throwCallableError('invalid-argument', 'Subject is required.');
  }
  if (!messageBody) {
    throwCallableError('invalid-argument', 'Message body is required.');
  }
  if (messageBody.length > 12000) {
    throwCallableError('invalid-argument', 'Message is too long.');
  }

  const subject =
    subjectRaw.length > 0 ? subjectRaw.slice(0, 200) : 'Feedback Response';

  const feedbackSnap = await admin
    .firestore()
    .collection('feedback')
    .doc(feedbackId)
    .get();
  if (!feedbackSnap.exists) {
    throwCallableError('not-found', 'Feedback not found.');
  }

  const feedback = feedbackSnap.data();
  const userId = feedback.userId ? String(feedback.userId) : '';
  const recipientEmail = await resolveCustomerEmailForUserId(userId);

  console.log('Recipient email:', recipientEmail || '(missing)');

  if (!recipientEmail) {
    throwCallableError(
      'failed-precondition',
      'No email address found for this customer. They may need to sign in again or update their profile.',
    );
  }

  const adminEmail = await resolveAdminEmail(request);
  console.log('Admin email:', adminEmail || '(missing)');

  if (!adminEmail || !isValidEmailFormat(adminEmail)) {
    throwCallableError(
      'failed-precondition',
      'Your admin account does not have a valid email for replies.',
    );
  }

  console.log('SMTP host:', process.env.SMTP_HOST || '(missing)');

  try {
    await sendFeedbackReplyEmail({
      to: recipientEmail,
      subject,
      text: messageBody,
      adminEmail,
    });
  } catch (e) {
    logError('sendFeedbackReplyEmail failed', e);
    if (e instanceof HttpsError) throw e;
    throwCallableError(
      'internal',
      (e && e.message) || 'Could not send email. Check SMTP configuration.',
    );
  }

  try {
    await appendFeedbackAdminResponse(feedbackId, messageBody, adminEmail);
  } catch (e) {
    logError('appendFeedbackAdminResponse failed', e);
    if (e instanceof HttpsError) throw e;
    throwCallableError(
      'internal',
      (e && e.message) || 'Email was sent but saving the reply failed.',
    );
  }

  logStep('sendFeedbackReply complete', { feedbackId, to: recipientEmail });
  return { ok: true, to: recipientEmail };
}

module.exports = { handleSendFeedbackReply };
