/**
 * SMTP configuration from Cloud Run / Functions environment variables.
 * Set via functions/.env on deploy or Cloud Run → Variables for each email service.
 *
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
 */
const { logger } = require('firebase-functions');

/**
 * @returns {{ host: string, port: number, user: string, pass: string, from: string, configured: boolean }}
 */
function readSmtpConfig() {
  const host = String(process.env.SMTP_HOST || '').trim();
  const portRaw = String(process.env.SMTP_PORT || '587').trim();
  const port = parseInt(portRaw, 10) || 587;
  const user = String(process.env.SMTP_USER || '').trim();
  const pass =
    process.env.SMTP_PASS != null ? String(process.env.SMTP_PASS).trim() : '';
  const fromRaw = String(process.env.SMTP_FROM || '').trim();
  const from = fromRaw || user;
  const configured = Boolean(host && user && pass);

  if (!configured) {
    logger.warn('readSmtpConfig: SMTP not fully configured', {
      hasHost: Boolean(host),
      hasUser: Boolean(user),
      hasPass: Boolean(pass),
      hasFrom: Boolean(from),
      port,
    });
  }

  return { host, port, user, pass, from, configured };
}

module.exports = { readSmtpConfig };
