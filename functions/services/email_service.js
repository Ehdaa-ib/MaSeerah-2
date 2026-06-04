/**
 * Transactional email via Nodemailer SMTP (Gmail, Outlook, etc.).
 */
const nodemailer = require('nodemailer');
const { readSmtpConfig, logSmtpEnvPresence } = require('../config/smtp_params');
const { logStep, logError } = require('../util/log_step');
const { throwCallableError } = require('../util/callable_errors');

function isFunctionsEmulator() {
  return process.env.FUNCTIONS_EMULATOR === 'true';
}

/**
 * @param {{ host: string, port: number, user: string, pass: string }} config
 */
function createTransporter(config) {
  const { host, port, user, pass } = config;
  logStep('Creating transporter...', { host, port, user: `${user.slice(0, 3)}***` });

  const auth = { user, pass: pass.trim() };

  if (host.includes('gmail.com') || user.includes('@gmail.com')) {
    return nodemailer.createTransport({
      service: 'gmail',
      auth,
    });
  }

  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    requireTLS: port === 587,
    auth,
    tls: { minVersion: 'TLSv1.2' },
  });
}

/**
 * @param {import('nodemailer').Transporter} transporter
 * @param {string} contextLabel
 */
async function verifySmtpConnection(transporter, contextLabel) {
  logStep(`${contextLabel}: Verifying SMTP connection...`);
  try {
    await transporter.verify();
    logStep(`${contextLabel}: SMTP verify OK`);
  } catch (err) {
    logError(`${contextLabel}: SMTP verify failed`, err);
    const reason = err && err.message ? String(err.message) : 'SMTP authentication failed';
    throwCallableError(
      'failed-precondition',
      `SMTP connection failed: ${reason}. For Gmail use an App Password (not your normal password).`,
    );
  }
}

/**
 * @param {{ from: string, to: string, subject: string, text: string, replyTo?: string }} mail
 * @param {string} contextLabel
 */
async function deliverMail(mail, contextLabel) {
  logStep(`${contextLabel}: deliverMail start`);
  logSmtpEnvPresence();

  const config = readSmtpConfig();

  if (!mail.to || !String(mail.to).trim()) {
    throwCallableError('invalid-argument', 'Recipient email is required.');
  }
  if (!mail.subject || !String(mail.subject).trim()) {
    throwCallableError('invalid-argument', 'Email subject is required.');
  }
  if (!mail.text || !String(mail.text).trim()) {
    throwCallableError('invalid-argument', 'Email message body is required.');
  }

  logStep(`${contextLabel}: Recipient email`, { to: mail.to });
  logStep(`${contextLabel}: Subject`, { subject: mail.subject });

  if (!config.configured) {
    if (isFunctionsEmulator()) {
      logStep(`${contextLabel}: emulator — SMTP not configured, skipping send`);
      return { messageId: 'emulator-log-only' };
    }
    throwCallableError(
      'failed-precondition',
      `Email delivery is not configured. Missing: ${config.missing.join(', ')}. ` +
        'Set them in functions/.env and run: firebase deploy --only functions',
    );
  }

  const transporter = createTransporter(config);
  await verifySmtpConnection(transporter, contextLabel);

  logStep(`${contextLabel}: Sending email...`);
  try {
    const result = await transporter.sendMail({
      from: mail.from || config.from || config.user,
      to: mail.to,
      replyTo: mail.replyTo || undefined,
      subject: mail.subject,
      text: mail.text,
    });
    console.log('Email sent:', result);
    logStep(`${contextLabel}: Email sent`, {
      messageId: result.messageId,
      response: result.response,
    });
    return result;
  } catch (err) {
    logError(`${contextLabel}: EMAIL SEND ERROR`, err);
    const reason = err && err.message ? String(err.message) : 'unknown error';
    throwCallableError(
      'failed-precondition',
      `Could not send email (${reason}). Check SMTP_PASS and SMTP_FROM.`,
    );
  }
}

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

module.exports = { sendPasswordResetOtpEmail, deliverMail };
