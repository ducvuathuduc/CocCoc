# CocEnglish — Flutter frontend

Architecture audit and local backend foundation refreshed 2026-10-09–10: [current entry](docs/00_START_HERE.md), [freeze report](docs/ARCHITECTURE_FREEZE_REPORT.md), [Windows commands](docs/devops/LOCAL_SETUP_WINDOWS.md). Three separately bundled service scaffolds and fake async tests exist; hosted business integration remains disabled and unproven.

Research baseline: **2026-10-03**. Current frontend snapshot: **2026-10-09, Asia/Saigon**.

New collaborator: start with the [developer handoff](docs/agent/DEVELOPER_HANDOFF.md)
for current capabilities, backend documentation, task order and clean-clone commands.

The runnable Flutter app is in [apps/mobile](apps/mobile/README.md). It includes onboarding/mock login and an English learning preview with lessons, practice, stories, subscriptions, streaks, achievements, Friends Clash and social feed/status flows. Screen analysis precedes implementation: [onboarding](docs/design/flows/01_ONBOARDING.md), [login](docs/design/flows/02_LOGIN.md), [frontend plan](docs/agent/FRONTEND_FLOW_PLAN.md).

Use Flutter 3.47.0 / Dart 3.13.0. From the repository root, run `pnpm verify` for format, analyzer, Flutter tests and blueprint validation; `pnpm build:android` also builds a debug APK. To run on a connected Android device/emulator: `cd apps/mobile`, `flutter pub get`, then `flutter run`.

Local browser preview: set `FLUTTER_ROOT` to your Flutter SDK directory, then run `pnpm build:web` and `pnpm preview:web` from the repository root. Open http://127.0.0.1:4173/preview.html . The build enables mock auth and uses the bundled Rive web runtime. Current lesson states and checks are recorded in the [English lesson receipt](docs/design/qa/ENGLISH_LESSON_REPORT.md). The [persistent checklist](docs/design/qa/FLOW_CHECKLIST.md) inventories archived reference journeys and per-screen evidence; those records are not independent product flows. Source files and reference/QA assets belong to the project. Regenerate ignored build outputs before previewing; the historical [GitHub snapshot](docs/design/qa/GITHUB_SNAPSHOT.md) records older artifact checks.

Debug builds use local mock data by default. Demo email: `demo@cocenglish.test`; password: `duolingo-demo`. Google, Facebook and Apple buttons simulate the demo account. Mock recovery advances to an in-app password-reset preview. No cloud account is created and no email is sent. See the module README for runtime switches and limitations.

The product is a Flutter Android/iOS language learning app. The frozen design uses three independently deployable TypeScript services — Learning, Progress, AI — and Appwrite Auth, TablesDB, Storage, and Functions. Infrastructure benefits and external AI quotas are conditional; the fallback demo uses local Node services and bounded Appwrite Free resources.

Backend architecture/API/data/auth/migration/operations documentation exists, but the service directories currently contain instructions rather than runnable implementations. The full phase gates remain in [implementation plan](docs/agent/IMPLEMENTATION_PLAN.md). This mock frontend does not certify backend foundations, production authentication, every archived variant, exact pixel/motion equivalence, physical-device performance or an iOS build. The original [architecture blueprint](docs/ARCHITECTURE_BLUEPRINT_V1.md) and [reading order](docs/00_READ_ME_FIRST.md) remain canonical.
