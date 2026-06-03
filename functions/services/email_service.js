/**
 * Transactional email (Nodemailer SMTP). Swap implementation here for SendGrid/Resend/etc.
 *
 * Environment (Cloud Run / `functions/.env` in emulator):
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
 *
 * Emulator: if SMTP is missing, logs the message only. Production: throws so the app does not
 * claim the email was sent when nothing was delivered.
 */

const nodemailer = require('nodemailer');
const { HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');

function isFunctionsEmulator() {
  return process.env.FUNCTIONS_EMULATOR === 'true';
}

function getSmtpConfig() {
  const host = (process.env.SMTP_HOST || '').trim();
  const port = process.env.SMTP_PORT
    ? parseInt(String(process.env.SMTP_PORT).trim(), 10)
    : 587;
  const user = (process.env.SMTP_USER || '').trim();
  const pass = process.env.SMTP_PASS != null ? String(process.env.SMTP_PASS) : '';
  const fromRaw = (process.env.SMTP_FROM || '').trim();
  const from = fromRaw || user;
  return { host, port, user, pass, from };
}

function assertSmtpConfigured(contextLabel) {
  const { host, user, pass } = getSmtpConfig();
  if (host && user && pass) return getSmtpConfig();
  if (isFunctionsEmulator()) return null;
  throw new HttpsError(
    'failed-precondition',
    'Email delivery is not configured. Set SMTP_HOST, SMTP_USER, SMTP_PASS, and SMTP_FROM ' +
      `on Cloud Functions (see functions/README.md), then redeploy. Context: ${contextLabel}.`,
  );
}

function createTransporter(config) {
  const { host, port, user, pass } = config;
  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    requireTLS: port === 587,
    auth: { user, pass: pass.trim() },
  });
}

/**
 * @param {{ from: string, to: string, subject: string, text: string, replyTo?: string }} mail
 */
async function deliverMail(mail, contextLabel) {
  const config = assertSmtpConfigured(contextLabel);
  if (!config) {
    logger.warn(`[${contextLabel}] SMTP not configured. Would send to ${mail.to}:`, {
      subject: mail.subject,
      preview: mail.text.slice(0, 200),
      replyTo: mail.replyTo,
    });
    return { messageId: 'emulator-log-only' };
  }

  const transporter = createTransporter(config);
  try {
    const info = await transporter.sendMail({
      from: mail.from,
      to: mail.to,
      replyTo: mail.replyTo || undefined,
      subject: mail.subject,
      text: mail.text,
    });
    logger.info(`${contextLabel} email accepted by SMTP`, {
      to: mail.to,
      messageId: info.messageId,
      replyTo: mail.replyTo,
    });
    return info;
  } catch (err) {
    logger.error('sendMail failed', {
      err,
      to: mail.to,
      host: config.host,
      port: config.port,
      contextLabel,
    });
    const reason = err && err.message ? String(err.message) : 'unknown error';
    throw new HttpsError(
      'internal',
      `Could not send email (${reason}). Check SMTP_PASS (e.g. Gmail App Password), ` +
        'SMTP_FROM matches your account, and Cloud Function logs.',
    );
  }
}

/**
 * @param {string} to
 * @param {string} plainCode - 6-digit OTP (only in memory; never stored in Firestore)
 */
async function sendPasswordResetOtpEmail(to, plainCode) {
  const config = getSmtpConfig();
  const from = config.from || config.user;
  await deliverMail(
    {
      from,
      to,
      subject: 'MaSeerah — Your password reset code',
      text:
        `Your password reset code is: ${plainCode}\n\n` +
        'It expires in 15 minutes.\n\n' +
        'If you did not request a password reset, ignore this email.',
    },
    'password-reset-otp',
  );
}

/**
 * Admin feedback reply to a customer.
 *
 * @param {{ to: string, subject: string, text: string, adminEmail: string }} params
 */
async function sendFeedbackReplyEmail({ to, subject, text, adminEmail }) {
  const config = getSmtpConfig();
  const smtpFrom = config.from || config.user;
  const admin = String(adminEmail || '').trim();
  const from =
    admin && smtpFrom
      ? `"MaSeerah Customer Service (${admin})" <${smtpFrom}>`
      : smtpFrom;

  await deliverMail(
    {
      from,
      to,
      replyTo: admin || undefined,
      subject: String(subject || 'Feedback Response').trim() || 'Feedback Response',
      text: String(text || '').trim(),
    },
    'feedback-reply',
  );
}

module.exports = { sendPasswordResetOtpEmail, sendFeedbackReplyEmail };
