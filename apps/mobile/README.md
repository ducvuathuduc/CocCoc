# CocEnglish mobile frontend

Flutter 3.47.0 / Dart 3.13.0; feature-first manual Riverpod MVVM and go_router. Android/iOS platform projects are generated; recorded Android evidence is kept in QA receipts, and iOS needs macOS/Xcode. New collaborators should start with the [developer handoff](../../docs/agent/DEVELOPER_HANDOFF.md).

Run `flutter pub get` then `flutter run` from this directory. Run `pnpm verify` from the repository root for the complete local gate. Direct regression command: `flutter test --dart-define=ENABLE_MASCOT_MOTION=false`. Dedicated Duo tests enable the actual animation explicitly.

Debug mock login uses `demo@cocenglish.test` / `duolingo-demo`. Any valid demo email accepts that password until reset. Google, Facebook and Apple buttons simulate a demo sign-in. Forgot Password → Next → Okay opens the local reset form; matching passwords must have at least 12 characters. The changed password works for that email in this app instance. Restart resets demo authentication; onboarding choices are stored locally and restored. There is no cloud email, real OAuth or account creation.

`USE_MOCK_AUTH=false` selects the prepared Appwrite adapter. It requires public `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, and an HTTPS `APPWRITE_RECOVERY_URL`; providers additionally require their explicit enable flags and server configuration. Never supply API keys in the app. Real authentication/recovery links are not verified in this slice.

`ENABLE_MASCOT_MOTION=false` selects exact archived still poses for layout comparison. Runtime defaults to local original vector timelines; device Reduce Motion selects still poses too. Reference files and public web animation assets are bundled offline, with [provenance](assets/PROVENANCE.md) and [motion analysis](../../docs/design/flows/03_DUO_MOTION.md). No assertion of identical archived iOS timing is made.

Static reference captures: `flutter test test/visual_capture_test.dart test/login_visual_capture_test.dart --dart-define=CAPTURE_UI=true --dart-define=ENABLE_MASCOT_MOTION=false`. Native flow test: `flutter drive --driver=test_driver/integration_driver.dart --target=integration_test/onboarding_test.dart -d emulator-5554 --dart-define=ENABLE_MASCOT_MOTION=false`. Rebuild `flutter build apk --debug` afterward to restore the normal application entry point.

Scope: onboarding/login and the five-tab English mock app, native lessons/guide/results, Words/sort/recall, Sections/Energy, eight-title Stories library/Radio/typed Roleplay, Rapid/Legendary with owned Timer Boost continuation, passport Adventure, deterministic Explain My Answer, Super/Max reminder/plan/checkout/tour/family/cancellation, streak calendar/shield/friend invitations, family reactions, achievement/monthly badge details, Friends Clash, league status selection and social feed/comments/sharing previews. New learning/account/progress data is held in memory; onboarding choices remain durably stored. Audio, speech, cloud, notifications and purchases are simulated. Active exercises use authored English/Vietnamese content.

Latest recorded frontend gate, 2026-10-09: 439 tests passed with clean analyzer and format. The [English lesson receipt](../../docs/design/qa/ENGLISH_LESSON_REPORT.md) records 31 scoped checks, 15 native states, five enabled original Lily frames and the release web build. The [asset audit](../../docs/design/qa/reference-assets.json) verifies 239 bundled PNGs against saved sources. Older Android builds and screenshots remain historical evidence in the [extended receipt](../../docs/design/qa/ENGLISH_EXTENDED_REPORT.md) and [artifact hashes](../../docs/design/qa/english-current-artifacts.json); regenerate build output after cleanup. Capture current lesson states with `flutter test test/english_lesson_capture_test.dart --dart-define=CAPTURE_ENGLISH_LESSON=true --dart-define=ENABLE_MASCOT_MOTION=false`. Capture enabled Lily separately with `flutter test test/english_lesson_capture_test.dart --dart-define=CAPTURE_ENGLISH_LESSON=true --dart-define=CAPTURE_ENGLISH_LILY_MOTION=true`; continuous animation must not use pumpAndSettle. The complete gate prepares the native Rive test runtime.

Run `pnpm build:web` then `pnpm preview:web` from the root; open http://127.0.0.1:4173/preview.html. The preview serves the actual Flutter build. The build verifies bundled Rive44 web runtime files and supplies `RIVE_NATIVE_WASM_HOST=rive/` and `USE_MOCK_AUTH=true`. Original local Lottie/Rive assets have lifecycle and Reduce Motion fallbacks. Archived source journeys are a reference inventory, not additional product flows. Exact private pixel/motion equivalence, production capabilities, current physical-device runs and iOS require their own acceptance evidence.

Course management/removal, native saved-account management, password changes,
profile report/block/unblock and QR/copy are added in the
[continuation receipt](../../docs/design/qa/ENGLISH_CONTINUATION_REPORT.md).
Completed mock families and individual source steps are kept in the
[persistent checklist](../../docs/design/qa/FLOW_CHECKLIST.md); reuse them before
implementing a pending variant. Original avatar resources and their verified
catalog are documented in the [avatar analysis](../../docs/design/flows/24_AVATAR_ASSET_RESEARCH.md).
