# MaSeerah

**MaSeerah** is a Flutter app for interactive cultural exploration in Medina. Browse journeys, purchase and play guided routes, complete landmark challenges, capture memories, and manage content from an admin dashboard.

This guide focuses on **running and testing the app on a real phone** (Android or iOS).

---

## Prerequisites

| Tool | Why |
|------|-----|
| [Git](https://git-scm.com/) | Clone the repo |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable, Dart **^3.10.8**) | Build and run the app |
| Android Studio **or** Xcode | Android build tools / iOS builds |
| Internet connection | App uses Firebase (auth, data, media, payments) |

Verify your setup:

```bash
flutter doctor
```

Fix anything marked with `✗` for the platform you care about (Android or iOS).

---

## Clone and install

```bash
git clone https://github.com/Ehdaa-ib/MaSeerah-2.git
cd MaSeerah-2

flutter pub get
```

Firebase client config is already in the repo for project **`maseerah-2`**:

- Android: `android/app/google-services.json`
- App options: `lib/firebase_options.dart`

You do **not** need to set up your own Firebase project to try the shared demo backend.

---

## Test on a physical device

### Option A — Run from source (recommended for developers)

#### Android phone

1. On the phone: **Settings → About phone → tap Build number 7 times** to enable Developer options.
2. Enable **USB debugging** (and **Install via USB** if present).
3. Connect the phone with a USB cable and allow the PC when prompted.
4. Confirm Flutter sees the device:

```bash
flutter devices
```

5. Run the app:

```bash
flutter run
```

If multiple devices are listed, pick the phone explicitly:

```bash
flutter run -d <device_id>
```

#### iPhone (macOS + Xcode required)

1. Open `ios/Runner.xcworkspace` in Xcode once, select your **Team** under **Signing & Capabilities**, and plug in the iPhone.
2. Trust the developer certificate on the phone if iOS asks (**Settings → General → VPN & Device Management**).
3. From the project root:

```bash
flutter devices
flutter run
```

> **Note:** Moyasar checkout (journey purchase) works on **Android and iOS only**, not web or desktop.

### Option B — Install a release APK (Android testers without Flutter)

Anyone with Flutter installed can build a shareable APK:

```bash
flutter build apk --release
```

The file is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Share that APK (Drive, email, USB). On the phone:

1. Download the APK.
2. Open it and allow **Install unknown apps** for your browser/file manager if asked.
3. Install and open **MaSeerah**.

Package id: `com.example.maseerah_app`.

---

## First run checklist

| Check | Details |
|-------|---------|
| Internet | Keep Wi‑Fi or mobile data on |
| Account | Use **Sign Up** to create a user, or sign in if you already have one |
| Journey | **Darb Al-Sunnah** (`journey_1`) is the playable demo; other cards may show **Coming Soon** |
| Permissions | Allow **camera / photos** when asked (memories & feedback) |
| Payments | Uses **Moyasar test mode** — use [Moyasar test cards](https://docs.moyasar.com/), not real cards |

---

## Admin / demo access

- **Regular users:** create an account in the app.
- **Admin dashboard** (`/admin`): allowed for emails listed in `lib/core/validators.dart` (and matching Firestore `users/{uid}.role = admin` when used).  
  Admin passwords are **not** stored in this repo — get them from the project team, or create matching Auth users in Firebase if you own the project.

---

## Emulator / desktop (optional)

```bash
# List available targets
flutter devices

# Android emulator or iOS simulator
flutter run
```

For a full payment flow, prefer a **phone** or mobile emulator over web/desktop.

---

## Cloud Functions & rules (only if you own Firebase)

Most testers using the team project can skip this.

```bash
# Deploy rules if permission errors appear (requires Firebase project access)
firebase login
firebase use maseerah-2
firebase deploy --only firestore:rules,storage
```

Password-reset OTP needs Cloud Functions + SMTP — see [`functions/README.md`](functions/README.md) and [DEPLOY_FIRESTORE_RULES.md](DEPLOY_FIRESTORE_RULES.md).

---

## Common issues

| Problem | What to try |
|---------|-------------|
| `flutter devices` empty | Unlock phone, accept USB debugging, try another cable/port; run `flutter doctor` |
| `permission-denied` in app | Sign in; ensure network works; rules must be deployed on your Firebase project |
| Empty journeys / map | Confirm you’re on the shared `maseerah-2` config (don’t replace `firebase_options.dart` unless intentional) |
| Payment UI missing | Use Android or iOS (not Chrome/desktop) |
| Photos won’t upload | Grant camera/gallery permission; check Storage access |
| SDK / `pub get` errors | Upgrade Flutter stable so Dart matches `pubspec.yaml` (^3.10.8) |

---

## Project layout & tests

Source overview: [`lib/README.md`](lib/README.md)

```bash
flutter test
```

Automated tests do not replace a device demo; use `flutter run` or the release APK for end-to-end testing.

---

## MVP notice

Capstone MVP: English UI, one primary playable journey, Firebase backend, Moyasar **test** payments. Built for evaluation and demos, not production. Support contact in-app: `MaSeerah.help@gmail.com`.
