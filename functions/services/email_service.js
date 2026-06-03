/**
 * Transactional email via Nodemailer SMTP (Gmail, Outlook, or any SMTP provider).
 * Configuration: functions/config/smtp_params.js + Secret Manager SMTP_PASS.
 */

const nodemailer = require('nodemailer');
const { HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const { readSmtpConfig } = require('../config/smtp_params');

function isFunctionsEmulator() {
  return process.env.FUNCTIONS_EMULATOR === 'true';
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
 * Verifies SMTP credentials before send (surfaces auth errors early).
 * @param {import('nodemailer').Transporter} transporter
 */
async function verifySmtpConnection(transporter, contextLabel) {
  try {
    await transporter.verify();
    logger.info(`[${contextLabel}] SMTP connection verified`, {
      host: transporter.options.host,
      port: transporter.options.port,
    });
  } catch (err) {
    logger.error(`[${contextLabel}] SMTP verify failed`, {
      err,
      message: err && err.message,
      code: err && err.code,
    });
    const reason = err && err.message ? String(err.message) : 'SMTP authentication failed';
    throw new HttpsError(
      'failed-precondition',
      `SMTP connection failed: ${reason}. Check SMTP_HOST, SMTP_USER, SMTP_PASS (App Password for Gmail), and SMTP_FROM.`,
    );
  }
}

/**
 * @param {{ from: string, to: string, subject: string, text: string, replyTo?: string }} mail
 */
async function deliverMail(mail, contextLabel) {
  const config = readSmtpConfig();

  logger.info(`[${contextLabel}] deliverMail start`, {
    to: mail.to,
    subject: mail.subject,
    replyTo: mail.replyTo || null,
    smtpHost: config.host || '(missing)',
    smtpPort: config.port,
    smtpUser: config.user ? `${config.user.slice(0, 3)}***` : '(missing)',
    smtpConfigured: config.configured,
    emulator: isFunctionsEmulator(),
  });

  if (!config.configured) {
    if (isFunctionsEmulator()) {
      logger.warn(`[${contextLabel}] SMTP not configured (emulator). Would send:`, {
        to: mail.to,
        subject: mail.subject,
        preview: mail.text.slice(0, 200),
        replyTo: mail.replyTo,
      });
      return { messageId: 'emulator-log-only' };
    }
    throw new HttpsError(
      'failed-precondition',
      'Email delivery is not configured. Set SMTP_HOST, SMTP_USER, SMTP_PASS, and SMTP_FROM in ' +
        'functions/.env (or Cloud Run env vars on sendpasswordresetotp and sendfeedbackreply), then run: ' +
        'firebase deploy --only functions',
    );
  }

  const transporter = createTransporter(config);
  await verifySmtpConnection(transporter, contextLabel);

  try {
    const info = await transporter.sendMail({
      from: mail.from,
      to: mail.to,
      replyTo: mail.replyTo || undefined,
      subject: mail.subject,
      text: mail.text,
    });
    logger.info(`[${contextLabel}] email accepted by SMTP`, {
      to: mail.to,
      messageId: info.messageId,
      response: info.response,
      replyTo: mail.replyTo,
    });
    return info;
  } catch (err) {
    logger.error(`[${contextLabel}] sendMail failed`, {
      err,
      message: err && err.message,
      code: err && err.code,
      command: err && err.command,
      to: mail.to,
      host: config.host,
      port: config.port,
    });
    const reason = err && err.message ? String(err.message) : 'unknown error';
    throw new HttpsError(
      'failed-precondition',
      `Could not send email (${reason}). Check SMTP_PASS (Gmail App Password), SMTP_FROM, and Cloud Function logs.`,
    );
  }
}

/**
 * @param {string} to
 * @param {string} plainCode
 */
async function sendPasswordResetOtpEmail(to, plainCode) {
  const config = readSmtpConfig();
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
 * @param {{ to: string, subject: string, text: string, adminEmail: string }} params
 */
async function sendFeedbackReplyEmail({ to, subject, text, adminEmail }) {
  const config = readSmtpConfig();
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

module.exports = { sendPasswordResetOtpEmail, sendFeedbackReplyEmail, deliverMail };
