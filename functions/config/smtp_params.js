/**
 * SMTP configuration from Cloud Run / Functions environment variables.
 */
const { logStep, logError } = require('../util/log_step');

/**
 * @returns {string[]}
 */
function missingSmtpEnvKeys() {
  const missing = [];
  if (!String(process.env.SMTP_HOST || '').trim()) missing.push('SMTP_HOST');
  if (!String(process.env.SMTP_USER || '').trim()) missing.push('SMTP_USER');
  if (!String(process.env.SMTP_PASS || '').trim()) missing.push('SMTP_PASS');
  return missing;
}

/**
 * @returns {{ host: string, port: number, user: string, pass: string, from: string, configured: boolean, missing: string[] }}
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
  const missing = missingSmtpEnvKeys();
  const configured = missing.length === 0;

  logStep('readSmtpConfig', {
    smtpHost: host || '(missing)',
    smtpPort: port,
    smtpUser: user ? `${user.slice(0, 3)}***` : '(missing)',
    smtpFrom: from ? `${from.slice(0, 3)}***` : '(missing)',
    hasPass: Boolean(pass),
    configured,
    missing,
  });

  return { host, port, user, pass, from, configured, missing };
}

/**
 * Logs env presence (never logs password value).
 */
function logSmtpEnvPresence() {
  logStep('SMTP env check', {
    SMTP_HOST: process.env.SMTP_HOST ? 'set' : 'MISSING',
    SMTP_PORT: process.env.SMTP_PORT || '587 (default)',
    SMTP_USER: process.env.SMTP_USER ? 'set' : 'MISSING',
    SMTP_PASS: process.env.SMTP_PASS ? 'set' : 'MISSING',
    SMTP_FROM: process.env.SMTP_FROM ? 'set' : '(optional, defaults to SMTP_USER)',
  });
}

module.exports = { readSmtpConfig, missingSmtpEnvKeys, logSmtpEnvPresence };
