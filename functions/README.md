# Cloud Functions — password reset (email OTP)

Callable functions send a **6-digit OTP** by email, verify it, and set the user password with the **Firebase Admin SDK**. The app does **not** use Firebase Auth’s password-reset **link** for this flow.

## Callables (region: `us-central1`)

| Name | Purpose |
|------|--------|
| `sendPasswordResetOtp` | Ensures user exists in Auth, rate-limits resends, stores **hashed** OTP in Firestore, emails plain OTP |
| `verifyPasswordResetOtp` | Checks hash, expiry, attempt limit; sets `verified: true` |
| `resetPasswordWithOtp` | Requires `verified`, updates password, deletes session doc |

## Deploy

From the project root (Firebase CLI logged in, **Blaze** required for Functions):

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
firebase deploy --only firestore:rules
```

## Required configuration

### `OTP_PEPPER` (required in production)

Used to **HMAC-hash** OTPs before storing in Firestore. Must be **at least 16 characters**.

**If you see:** *“Set OTP_PEPPER (min 16 characters)”* in the app — the secret is not set or functions were not redeployed after setting it.

**Recommended (Firebase Secret Manager):**

```bash
# Create a strong random value (example: 32+ characters). Paste when prompted.
firebase functions:secrets:set OTP_PEPPER

# Redeploy so all three callables receive the secret
firebase deploy --only functions
```

The code uses `defineSecret('OTP_PEPPER')` and attaches it to `sendPasswordResetOtp`, `verifyPasswordResetOtp`, and `resetPasswordWithOtp`.

**Alternative:** In [Google Cloud Console](https://console.cloud.google.com/) → **Cloud Run** → open each `sendpasswordresetotp`, `verifypasswordresetotp`, `resetpasswordwithotp` service → **Edit & deploy new revision** → **Variables** → add `OTP_PEPPER` = your long random string (must match across all three).

In the **local emulator**, if unset, a dev-only default is used (see `index.js`).

### Email (SMTP)

Implemented in `services/email_service.js` so you can swap providers later.

**Why the app said “sent” but you got no mail:** older behavior only **logged** the OTP in Cloud Logging when SMTP was missing. In production, missing SMTP now returns an error instead. You must set the variables below on the **`sendPasswordResetOtp`** runtime (2nd gen = a Cloud Run service).

**Set environment variables (Google Cloud Console)**

1. Open [Cloud Run](https://console.cloud.google.com/run) for the same project as Firebase.
2. Find the service whose name includes **`sendpasswordresetotp`** (Firebase lowercases names).
3. **Edit & deploy new revision** → **Variables & Secrets** → **Add variable** for each:

| Variable | Example (Gmail) |
|----------|-----------------|
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | Your full Gmail address |
| `SMTP_PASS` | [App Password](https://myaccount.google.com/apppasswords) (16 characters, not your normal password) |
| `SMTP_FROM` | Same as `SMTP_USER` or an alias Google allows |

4. Deploy the revision. No need to change OTP / Firestore logic.

**Or use `functions/.env` on deploy:** copy `.env.example` to `.env`, fill in real values, run `firebase deploy --only functions` from your machine. Firebase CLI loads `.env` for 2nd gen functions; `.env` is gitignored so secrets are not committed.

**Gmail checklist:** 2-Step Verification must be on to create App Passwords. Use port **587** (TLS). Check **Spam** for `MaSeerah`. If send still fails, open **Cloud Run → service → Logs** and look for `sendMail failed`.

**Local emulator:** create `functions/.env` (do not commit) with the same keys; OTP is also printed in the terminal if SMTP is omitted.

- `SMTP_HOST` — e.g. `smtp.gmail.com`
- `SMTP_PORT` — e.g. `587`
- `SMTP_USER` — SMTP username
- `SMTP_PASS` — app password or provider secret
- `SMTP_FROM` — visible From address (defaults to `SMTP_USER` if unset)

## Firestore

Collection **`password_reset_otps`** — document ID = SHA-256 of normalized email. Fields include:

- `email`, `uid`, `hashedCode`, `createdAt`, `expiresAt`, `attemptCount`, `resendCount`, `lastSentAt`, `verified`, `consumed`

Clients **cannot** read or write this collection (`firestore.rules`).

## Limits (server)

- OTP TTL: 15 minutes  
- Resend cooldown: 60 seconds  
- Max resends per session: 5  
- Max wrong verify attempts: 5  
