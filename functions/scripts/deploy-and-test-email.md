# Deploy feedback email functions

1. Create `functions/.env` from `.env.example` with real Gmail App Password.
2. `npm run test:smtp -- your@email.com` — must print `SMTP verify OK` and `Send OK`.
3. `firebase login`
4. From repo root: `firebase deploy --only functions`
5. In Google Cloud Console → Cloud Run, confirm **sendfeedbackreply** and **sendpasswordresetotp** have the same SMTP_* variables (or rely on `.env` from deploy).
