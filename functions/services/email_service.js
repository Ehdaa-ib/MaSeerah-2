/**
 * Password-reset OTP email. Swap implementation here for SendGrid/Resend/etc.
 *
 * Environment (Cloud Run service for `sendPasswordResetOtp`, or `functions/.env` in emulator):
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
 *
 * Emulator: if SMTP is missing, logs the OTP only. Production: throws so the app does not claim
 * the email was sent when nothing was delivered.
 */

const nodemailer = require('nodemailer');
const { HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');

function isFunctionsEmulator() {
  return process.env.FUNCTIONS_EMULATOR === 'true';
}

/**
 * @param {string} to
 * @param {string} plainCode - 6-digit OTP (only in memory; never stored in Firestore)
 */
async function sendPasswordResetOtpEmail(to, plainCode) {
  const host = (process.env.SMTP_HOST || '').trim();
  const port = process.env.SMTP_PORT
    ? parseInt(String(process.env.SMTP_PORT).trim(), 10)
    : 587;
  const user = (process.env.SMTP_USER || '').trim();
  const pass = process.env.SMTP_PASS != null ? String(process.env.SMTP_PASS) : '';
  const fromRaw = (process.env.SMTP_FROM || '').trim();
  const from = fromRaw || user;

  if (!host || !user || !pass) {
    if (isFunctionsEmulator()) {
      logger.warn(
        `[password-reset-otp] SMTP not configured. OTP for ${to}: ${plainCode}`,
      );
      return;
    }
    throw new HttpsError(
      'failed-precondition',
      'Email delivery is not configured. Set SMTP_HOST, SMTP_USER, SMTP_PASS, and SMTP_FROM ' +
        'on the sendPasswordResetOtp Cloud Run service (see functions/README.md), then redeploy.',
    );
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    requireTLS: port === 587,
    auth: { user, pass: pass.trim() },
  });

  try {
    const info = await transporter.sendMail({
      from,
      to,
      subject: 'MaSeerah — Your password reset code',
      text:
        `Your password reset code is: ${plainCode}\n\n` +
        'It expires in 15 minutes.\n\n' +
        'If you did not request a password reset, ignore this email.',
    });
    logger.info('password-reset OTP email accepted by SMTP', {
      to,
      messageId: info.messageId,
    });
  } catch (err) {
    logger.error('sendMail failed', { err, to, host, port });
    const reason = err && err.message ? String(err.message) : 'unknown error';
    throw new HttpsError(
      'internal',
      `Could not send email (${reason}). Check SMTP_PASS (e.g. Gmail App Password), ` +
        'SMTP_FROM matches your account, and Cloud Function logs.',
    );
  }
}

module.exports = { sendPasswordResetOtpEmail };
