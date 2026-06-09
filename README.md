# MaSeerah

**MaSeerah** is a capstone MVP mobile application for interactive cultural exploration in Medina. Users browse journeys, purchase and play guided routes with storytelling and landmark challenges, capture memories, submit feedback, and view journey history. Administrators manage catalog content, landmarks, recommendations, and user feedback through an in-app admin dashboard.

The app is **English only** in this release. The first playable catalog journey is **Darb Al-Sunnah** (`journey_1`); other home cards open a **Coming Soon** screen.

---

## Main features

- User registration, sign-in, and profile management
- Journey catalog, purchase (Moyasar), and playthrough progress
- Interactive SVG map with landmark stories and puzzle challenges
- Landmark photo memories (per playthrough instance)
- System recommendations near landmarks
- Journey completion, feedback, and history
- Active journeys list with 72-hour inactivity handling
- Admin dashboard (users, journeys, landmarks, recommendations, feedback)
- Password reset via email OTP (Firebase Cloud Functions)

---

## Tech stack

| Layer | Technology |
|--------|------------|
| Mobile app | Flutter (Dart SDK ^3.10.8) |
| Backend | Firebase (Auth, Firestore, Storage, Cloud Functions) |
| Payments | Moyasar (test keys in client for MVP) |
| Maps | External links via `url_launcher` (Google Maps) |
| Optional email | SMTP via Cloud Functions (password reset OTP) |

Source layout is documented in [`lib/README.md`](lib/README.md).

---

## Prerequisites

Install before cloning:

1. **Git**
2. **Flutter SDK** (stable channel, compatible with Dart ^3.10.8)  
   - Verify: `flutter doctor`
3. **Android Studio** (Android SDK + emulator) and/or **Xcode** (iOS simulator on macOS)
4. **Node.js 20** (only if deploying or running Cloud Functions)
5. **Firebase CLI** (`npm install -g firebase-tools`) — for rules/functions deploy
6. **Active internet connection** — the app is online-first (Firebase)

---

## Installation

```bash
# 1. Clone the repository
git clone <YOUR_REPO_URL>
cd MaSeerah-2-2

# 2. Install Flutter dependencies
flutter pub get

# 3. Generate localization (if needed)
flutter gen-l10n
```

### Firebase client configuration

This project is wired to Firebase project **`maseerah-2`** (see `.firebaserc` and `lib/firebase_options.dart`).

- **Android:** `android/app/google-services.json` is included in the repo.
- **iOS / other platforms:** Ensure platform config files match your Firebase project. If you use a different Firebase project, regenerate config:

```bash
# Requires FlutterFire CLI: dart pub global activate flutterfire_cli
flutterfire configure --project=maseerah-2
```

> **Examiner note:** If you use the team's shared Firebase project, the bundled `firebase_options.dart` and `google-services.json` should work as-is. If you fork to your own Firebase project, you must reconfigure and deploy rules (below).

### Firestore & Storage rules (required)

Security rules are enforced at runtime. Deploy them to the Firebase project you use:

```bash
firebase login
firebase use maseerah-2   # or your project id
firebase deploy --only firestore:rules,storage
```

If `firestore.indexes.json` exists and the console reports missing indexes, also run:

```bash
firebase deploy --only firestore:indexes
```

See also [DEPLOY_FIRESTORE_RULES.md](DEPLOY_FIRESTORE_RULES.md).

---

## Run the Flutter app

```bash
# List devices
flutter devices

# Run on a connected phone or emulator (recommended: Android or iOS)
flutter run

# Release build (example — Android)
flutter build apk
```

**Recommended for exam/demo:** Android emulator or physical device.  
**Payments:** The Moyasar checkout UI runs on **Android and iOS only** (not web/desktop).

Entry routes:

| Route | Screen |
|--------|--------|
| `/` (home) | Landing page with journey cards |
| `/login` | Sign in |
| `/create` | Create account |
| `/admin` | Admin dashboard (admin users only) |

---

## Backend / Cloud Functions (optional for most flows)

There is **no custom REST server**. Optional **Firebase Cloud Functions** (`functions/`) support **password reset OTP** email flow only.

### Setup (team / deploy)

```bash
cd functions
npm install
cp .env.example .env    # fill SMTP placeholders — do not commit .env
cd ..
firebase deploy --only functions
```

Required for production OTP:

- Secret **`OTP_PEPPER`** (min 16 characters) — see [`functions/README.md`](functions/README.md)
- SMTP variables in `functions/.env` or Cloud Run env: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`

Admin feedback replies use the device **email app** (`mailto`), not Cloud Functions.

Full details: [`functions/README.md`](functions/README.md)

---

## Test and demo accounts

### Regular user

Create a new account from the app (**Sign Up**). No shared demo password is stored in the repository.

### Admin access

Admin is granted if the signed-in email is in the allowlist in `lib/core/validators.dart` (kept in sync with `firestore.rules`), **or** if `users/{uid}.role` is `admin` in Firestore.

Configured admin **email patterns** (see codebase for current list):

- `ehdaa.test@admin.com`
- `q.test@admin.com`
- `m.test@admin.com`
- `r.test@admin.com`
- `malak@admin.com`

**Passwords are not in the repo.** Use credentials provided by the project team, or create matching users in **Firebase Authentication** console for your own Firebase project.

After sign-in, admins can open **`/admin`** or use the admin dashboard route from the app shell.

### Payments (test mode)

Moyasar **test** publishable/secret keys are in `lib/core/moyasar_config.dart`. Use Moyasar test card details from [Moyasar documentation](https://docs.moyasar.com/) when purchasing a journey in the app.

---

## Important notes for examiners

| Topic | Behavior |
|--------|----------|
| **Internet** | Required for auth, Firestore, Storage, payments, and images |
| **Permissions** | Camera and photo library for landmark memories and feedback photos (`AndroidManifest.xml`) |
| **Location / GPS** | No live GPS navigation in the MVP; map is guided progression; directions open external Google Maps |
| **Storage** | User media stored in Firebase Storage; metadata in Firestore |
| **Journey availability** | Only `journey_1` is playable by default; `journey_2` / `journey_3` show **Coming Soon** (overridable via Firestore `isAvailable` / `status`) |
| **Active journey** | Unfinished progress expires after **72 hours** of inactivity; user must purchase again |
| **Language** | English UI only in this MVP |
| **Support email** | `MaSeerah.help@gmail.com` (contact link in app) |

---

## Common errors and quick fixes

| Symptom | Likely cause | Fix |
|---------|----------------|-----|
| `permission-denied` on Firestore | Rules not deployed or user not signed in | Deploy `firestore.rules`; sign in; check `users/{uid}` exists |
| Empty journey / map data | Wrong Firebase project or missing seed data | Confirm `firebase_options.dart` project; check Firestore `journeys`, `journey_landmarks` |
| Payment screen unavailable | Running on web/desktop | Use Android or iOS emulator/device |
| Password reset OTP fails | Functions not deployed or `OTP_PEPPER` / SMTP missing | See `functions/README.md`; deploy functions and secrets |
| Photos not uploading | Storage rules or missing permission | Deploy `storage.rules`; grant camera/photos permission on device |
| Admin dashboard redirects to login | Email not in admin allowlist | Use an allowlisted admin email or set `role: admin` on user doc |
| `flutter pub get` / SDK errors | Flutter version mismatch | Run `flutter doctor`; use SDK compatible with `pubspec.yaml` (^3.10.8) |

---

## Running tests

```bash
flutter test
```

Some widget tests do not initialize Firebase; a full app demo should use `flutter run` on a device/emulator.

---

## MVP / capstone notice

This repository is the **Capstone 2 MVP** implementation of MaSeerah: one primary playable journey, English-only UI, Firebase-backed data, and test payment integration. It is intended for **academic evaluation and demonstration**, not production deployment. Features such as additional journeys, Arabic localization, live GPS, and production payment/backend hardening are out of scope for this version.

For questions during evaluation, contact the project team or use the in-app support email above.
