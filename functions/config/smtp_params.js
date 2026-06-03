/**
 * Shared SMTP configuration for all email-sending Cloud Functions (Gen 2).
 *
 * Set via functions/.env (deploy) or Cloud Run environment variables on each service:
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
 */
const { defineString } = require('firebase-functions/params');

const SMTP_HOST = defineString('SMTP_HOST', { default: '' });
const SMTP_PORT = defineString('SMTP_PORT', { default: '587' });
const SMTP_USER = defineString('SMTP_USER', { default: '' });
const SMTP_FROM = defineString('SMTP_FROM', { default: '' });

/**
 * @returns {{ host: string, port: number, user: string, pass: string, from: string, configured: boolean }}
 */
function readSmtpConfig() {
  const host = (SMTP_HOST.value() || process.env.SMTP_HOST || '').trim();
  const portRaw = (SMTP_PORT.value() || process.env.SMTP_PORT || '587').trim();
  const port = parseInt(portRaw, 10) || 587;
  const user = (SMTP_USER.value() || process.env.SMTP_USER || '').trim();
  const pass =
    process.env.SMTP_PASS != null ? String(process.env.SMTP_PASS).trim() : '';
  const fromRaw = (SMTP_FROM.value() || process.env.SMTP_FROM || '').trim();
  const from = fromRaw || user;
  const configured = Boolean(host && user && pass);
  return { host, port, user, pass, from, configured };
}

module.exports = {
  SMTP_HOST,
  SMTP_PORT,
  SMTP_USER,
  SMTP_FROM,
  readSmtpConfig,
};
