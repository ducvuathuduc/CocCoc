# CocEnglish — Flutter frontend

Research baseline: **2026-10-03**. Current frontend snapshot: **2026-10-05, Asia/Saigon**.

The runnable Flutter app is in [apps/mobile](apps/mobile/README.md). It includes onboarding/mock login and an English learning preview with lessons, practice, stories, subscriptions, streaks, achievements, Friends Clash and social feed/status flows. Screen analysis precedes implementation: [onboarding](docs/design/flows/01_ONBOARDING.md), [login](docs/design/flows/02_LOGIN.md), [frontend plan](docs/agent/FRONTEND_FLOW_PLAN.md).

Use Flutter 3.47.0 / Dart 3.13.0. From the repository root, run `pnpm verify` for format, analyzer, Flutter tests and blueprint validation; `pnpm build:android` also builds a debug APK. To run on a connected Android device/emulator: `cd apps/mobile`, `flutter pub get`, then `flutter run`.

Local browser preview: set `FLUTTER_ROOT` to your Flutter SDK directory, then run `pnpm build:web` and `pnpm preview:web` from the repository root. Open http://127.0.0.1:4173/preview.html . The build uses the bundled Rive web runtime. The [current QA receipt](docs/design/qa/ENGLISH_EXTENDED_REPORT.md) records 239 passing tests, release builds and remaining fidelity gaps. Source files, reference/QA assets and download packaging are described in the [GitHub snapshot](docs/design/qa/GITHUB_SNAPSHOT.md).

Debug builds use local mock data by default. Demo email: `demo@cocenglish.test`; password: `duolingo-demo`. Google, Facebook and Apple buttons simulate the demo account. Mock recovery advances to an in-app password-reset preview. No cloud account is created and no email is sent. See the module README for runtime switches and limitations.

The product is a Flutter Android/iOS language learning app. The frozen design uses three independently deployable TypeScript services — Learning, Progress, AI — and Appwrite Auth, TablesDB, Storage, and Functions. Infrastructure benefits and external AI quotas are conditional; the fallback demo uses local Node services and bounded Appwrite Free resources.

The full phase gates remain in [implementation plan](docs/agent/IMPLEMENTATION_PLAN.md). This mock frontend does not certify backend foundations, production authentication, all 148 archived language/shared flow variants, exact pixel/motion equivalence, physical-device performance or an iOS build. The original [architecture blueprint](docs/ARCHITECTURE_BLUEPRINT_V1.md) and [reading order](docs/00_READ_ME_FIRST.md) remain canonical.
