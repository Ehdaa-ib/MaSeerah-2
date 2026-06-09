# MaSeerah — `lib/` layout

| Folder | Role |
|--------|------|
| `view/` | Screens and UI (auth, home, journey map, admin, feedback) |
| `widgets/` | Shared UI components (bottom nav, network images, media sheets) |
| `challenge/` | Landmark challenge types and renderers |
| `service/` | App rules and coordination (access, payments, inactivity, purchase flow) |
| `data/` | Firestore data sources and repository implementations |
| `repository/` | Repository interfaces consumed by services and screens |
| `model/` | Domain entities (journey, user, order, feedback, landmarks) |
| `core/` | Colors, map tokens, validators, config |
| `util/` | Small helpers (auth wait, admin access, caching) |
| `l10n/` | Generated and source localization (English) |

Entry point: `main.dart` → `LandingPage` with named routes for login, sign-up, and admin.
