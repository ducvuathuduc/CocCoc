# Onboarding, mock login and Duo motion QA

Historical receipt for the first approved slice. The later [full mock frontend receipt](FULL_FRONTEND_REPORT.md) supersedes its scope/build/test totals; original Android flow and motion evidence below remains historical device evidence.

Date: 2026-10-04, Asia/Saigon. User-selected original Duolingo appearance; mock data first; browser preview requested for review. Branch: `codex/flutter-onboarding-login`; no remote push/publication.

## Executed checks

| Command / surface | Actual result |
|---|---|
| `pnpm verify` | PASS: blueprint validation, Dart format check, analyzer with fatal infos, **102 Flutter tests** |
| `flutter test test/visual_capture_test.dart test/login_visual_capture_test.dart --dart-define=CAPTURE_UI=true --dart-define=ENABLE_MASCOT_MOTION=false` | 20 onboarding + 8 auth fixtures captured at 1179/1180×2556; bundled fonts/native widgets; source system bars excluded from metrics |
| `flutter drive --driver=test_driver/integration_driver.dart --target=integration_test/onboarding_test.dart -d emulator-5554` | Both native Android flow cases passed: onboarding/durable restart; mock login/error/recovery/reset/new-password sign-in/saved chooser/Back. Executed before motion integration; separate motion run below exercises the added renderer |
| `flutter drive --driver=test_driver/integration_driver.dart --target=integration_test/motion_test.dart -d emulator-5554` | All five original vector timelines rendered and advanced on Android, with two native captures per pose |
| `flutter build apk --debug` | PASS after integration runs: normal `lib/main.dart` application APK restored |
| `flutter build web --release --dart-define=USE_MOCK_AUTH=true` | PASS; local preview opened in Codex Browser and app interaction observed. No cloud calls |

The full 102-test gate includes controller races, no duplicate busy command, retained input on errors, reset/recovery negative cases, disk/bootstrap restoration, tactile press/cancel/release, 360/390/430 logical-width fixtures with text scale 2, and six dedicated original-motion/lifecycle tests. The frame export test is opt-in evidence generation; its no-capture mode is not extra motion proof.

APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
SHA-256: `39934e95e262ca6ba89e48b944557844f977b171639667e49ad3ef0b5a0d87c4`.

Preview: http://127.0.0.1:4173/preview.html . Run `node tools/scripts/mobile-preview.mjs` after a web build to restart the local server. It listens only on loopback. The Android emulator created for testing was stopped to free resources during browser review.

## Visual evidence and limits

Original Gummble sources: `../references/onboarding/manifest.json`, `../references/login/manifest.json`. Native Flutter captures: `onboarding/01.png`–`20.png`, login fixtures `02,03,04,05,07,13,15,16.png`, and `android-*` screenshots. Original vector frame exports and Android renderer probes: `motion/`. Browser review snapshot: `web/welcome.png` (captured while the user was at the language step; filename is historical).

`onboarding/metrics.json` and `login/metrics.json` report mean absolute RGB error on both the whole body and foreground union. They are diagnostics, not a percentage of pixel-perfect fidelity. Whitespace hides misalignment in whole-body means. Current measured residuals include font rasterization, bubble/row geometry, borders and some vertical anchors. The latest choice-gap and sheet-tint adjustments were verified by analyzer/build; all eight auth fixtures were recaptured afterward.

Original web wave/idle/pencil/celebration/reading art was inspected frame by frame and matches the corresponding illustrated poses closely. Composition frame ranges and local byte provenance are in [motion analysis](../flows/03_DUO_MOTION.md). Playback uses original articulated vector layers, with fixed source viewports. The two special login mascots (tilted Duo and phone success Duo) retain original still artwork; matching motion sources were not found in the bounded first-party search. Current web timelines are not proof of identical Dec 2025 iOS timing. No physical 60fps or 100% motion claim is made.

The web app is a real Flutter build in a phone-size iframe, not a screenshot mockup. One `MutationObserver` console error was observed during browser accessibility inspection; the app continued responding and the user navigated the flow. Its origin/impact is not established, so browser-console cleanliness is not certified. This does not invalidate the separate native flow runs.

Android tooling emitted a future compatibility warning for `flutter_web_auth_2` and built-in Kotlin; the current build passed. Web emitted an unused Cupertino font-family warning; visible UI uses bundled Duolingo fonts/Material icons. iOS, physical-device performance, real Appwrite/OAuth/recovery delivery, lessons/path, launcher-icon customization and the entire 42-route inventory remain unverified or unimplemented.

Mock fixtures deliberately narrow auth input to Email and use demo identity data. Recovery sends no email; Okay opens a demo reset. Permissions/home-screen widgets/Super are local preview actions. These are scoped UI behaviors, not production capability claims.
