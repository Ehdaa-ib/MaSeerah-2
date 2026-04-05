# Cloud Functions — password reset

These callable functions send a **6-digit code** by email and update the user password using the Firebase Admin SDK.

## Deploy

From the project root (with Firebase CLI logged in):

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

## Email (SMTP)

For production, set environment variables for your mail provider (Gmail, SendGrid, etc.):

- `SMTP_HOST` — e.g. `smtp.gmail.com`
- `SMTP_PORT` — e.g. `587`
- `SMTP_USER` — SMTP username
- `SMTP_PASS` — SMTP password or app password
- `SMTP_FROM` — From address shown to users

With **Firebase Functions v2**, configure secrets or environment in the Google Cloud Console for the function, or use:

```bash
firebase functions:secrets:set SMTP_PASS
```

Refer to current Firebase docs for binding secrets to `process.env`.

If SMTP is **not** configured, the 6-digit code is **only written to Cloud Logging**. Open **Firebase Console → Functions → Logs** to see the code while testing.

## Firestore

Collection `password_reset_codes` is written only by these functions. Client apps cannot read or write it (see `firestore.rules`).
