#!/usr/bin/env node
/**
 * Local SMTP diagnostic. Run from functions/:
 *   node scripts/test-smtp.js you@example.com
 *
 * Loads functions/.env if present (same keys as .env.example).
 */
const path = require('path');
const fs = require('fs');
const nodemailer = require('nodemailer');

function loadDotEnv() {
  const envPath = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, 'utf8').split('\n');
  for (const line of lines) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const eq = t.indexOf('=');
    if (eq === -1) continue;
    const key = t.slice(0, eq).trim();
    let val = t.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = val;
  }
}

loadDotEnv();

const to = process.argv[2] || process.env.SMTP_TEST_TO;
const host = (process.env.SMTP_HOST || '').trim();
const port = process.env.SMTP_PORT
  ? parseInt(String(process.env.SMTP_PORT).trim(), 10)
  : 587;
const user = (process.env.SMTP_USER || '').trim();
const pass = process.env.SMTP_PASS != null ? String(process.env.SMTP_PASS) : '';
const from = (process.env.SMTP_FROM || '').trim() || user;

if (!to) {
  console.error('Usage: node scripts/test-smtp.js recipient@example.com');
  process.exit(1);
}

if (!host || !user || !pass) {
  console.error(
    'Missing SMTP_HOST, SMTP_USER, or SMTP_PASS. Copy functions/.env.example to functions/.env',
  );
  process.exit(1);
}

async function main() {
  console.log('SMTP config:', { host, port, user, from, to });
  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    requireTLS: port === 587,
    auth: { user, pass: pass.trim() },
  });

  console.log('Verifying SMTP connection…');
  await transporter.verify();
  console.log('SMTP verify OK');

  const info = await transporter.sendMail({
    from,
    to,
    subject: 'MaSeerah SMTP test',
    text: 'If you received this, SMTP is configured correctly.',
  });
  console.log('Send OK:', { messageId: info.messageId, response: info.response });
}

main().catch((err) => {
  console.error('SMTP test failed:', err);
  process.exit(1);
});
