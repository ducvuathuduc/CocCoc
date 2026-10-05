# Full mock frontend verification

2026-10-04, Asia/Saigon. User authorized continuing every planned UI family after approving onboarding/login, with mock data and the original Duolingo reference appearance. This receipt extends the historical [onboarding/login receipt](REPORT.md); full production phase gates remain pending.

## Implemented scope

| Family | Native Flutter interactions |
|---|---|
| Learning | Curved path/current/locked/completed/resume nodes, courses, guide, guest demo and ten-original placement,12 exercise renderers, authored hint, local report, correct/error feedback, two bounded mistake-review passes, pause/resume/abandon, seven result steps and return to path |
| Practice | Hub, words reveal/recall, mistakes/empty, unavailable listening media and typed substitution, speaking capability/recording simulation/unscored result, typed Lily call/connect/reconnect/end/transcript |
| Progress/social | First-entry monthly quest introduction/hub/daily progress/local eligible claim, locked/ranked league, own/public profile, friends search/follow, activity/empty, virtual shop funds/slots/receipt, streak and score |
| Account | Age/name/email/password registration, duplicate validation/input retention, local verification, profile editing, preferences, reminder configuration/denial, sync/recovery scenarios, logout and mock deletion receipt |

Five indexed-stack tabs preserve the local path and scroll state. Lesson commands retain answers on recoverable grade/completion failures, reject duplicate busy commands and unknown choice IDs, restore paused feedback/retry drafts, and ignore asynchronous responses after disposal. Receipt claims award local XP/gems/progression once; guest/placement/replay do not award ranked progress. These are demo rules, not a replacement for the service-owned production ledger.

## Executed evidence

| Command, from indicated directory | Result / artifact |
|---|---|
| Root: `pnpm verify` | PASS: blueprint,61 Dart files formatted, analyzer with fatal infos,130 Flutter tests. `full-verify.log` |
| Mobile: `flutter test test/full_frontend_qa_test.dart test/progress_preview_test.dart --dart-define=ENABLE_MASCOT_MOTION=false` | PASS: monthly intro→hub, idempotent claim/purchase, route interactions and all57 new fixtures at360/430 logical widths × text1/2. `quest-intro-green.log` |
| Mobile: `flutter test test/full_frontend_qa_test.dart --plain-name "capture analyzed frontend states with original fonts" --dart-define=CAPTURE_UI=true --dart-define=ENABLE_MASCOT_MOTION=false` | PASS:57 native PNGs in `frontend/`, source dimensions1179/1180×2556, local original fonts, illustration sources preloaded. `frontend-capture.log` |
| Root: `node tools/scripts/reference-asset-audit.mjs` | PASS:150 ordered source PNGs in16 families;127 bundled PNGs byte-identical to saved references. Dimensions match saved MCP metadata. `reference-assets.json` |
| Mobile: `flutter build web --release --dart-define=USE_MOCK_AUTH=true` | PASS,97.7s compile. `web-build.log`; local preview at http://127.0.0.1:4173/preview.html |
| Mobile: `flutter build apk --debug --dart-define=USE_MOCK_AUTH=true` | PASS,100.7s Gradle build. `full-android-build.log` |

Current normal application APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
SHA256: `a713be03a0854153ae9f1ced7519c4228e75b560909867d6a32776fe32d09f2b`.

The full lesson widget test presses each of the ten exercise answers, proceeds through all seven result steps, and asserts20XP exactly once and the next path node. Controller tests separately exercise retries, repository failures, disposal and guest/replay reward isolation. Seven original Lottie files parse; dedicated path tests establish advancing frames and reduced-motion still fallback. The earlier Android motion probe covered the original five onboarding poses; current additional flows are compiled on Android, not yet exercised on an Android device or iOS.

Run the capture test by its exact name: a combined capture run stalled after the earlier widget fixtures; its cause has not been established. The isolated process passed in16s, and the final recapture after correcting the practice source mapping passed in34s, generating all57 files. The four responsive cases remain part of the complete gate. No combined-run capture success is asserted.

## References and fidelity limits

Live Gummble MCP was used for the ordered flow manifests and individual screen inspection before implementation. All150 ordered references are under `../references/`; deconstruction precedes code in [path](../flows/04_COURSE_PATH.md), [lesson/results](../flows/05_LESSON_RESULTS.md), [hubs/account](../flows/06_HUBS_ACCOUNT.md) and [registration/social/speech](../flows/07_REGISTRATION_SOCIAL_SPEECH.md). This is16 selected flow families, not every1,103 screen in the latest archived app version.

Text, forms, lists, buttons, progress, navigation and feedback are native widgets. Saved source PNGs supply illustration/icon regions only. All source artwork bytes remain intact; the audit establishes local copy identity, not independent remote integrity. Source families span archived variants; mock names/month/counters, screen contents and unavailable capabilities intentionally differ.

RGB metrics in family `metrics.json` files are diagnostics, not pixel-perfect percentages. The quest introduction now compares to02 and the hub to03; practice compares to its unscrolled hub04. Most standalone captures omit the five-tab shell; only the path fixture captures the routed shell. Mock counters differ from personal source counters. Remaining deviations include hub/card anchors, Material substitute icons, source art cutouts, status-bar/shell backgrounds, mixed archived variants, and font rasterization. No all-screen pixel-equivalence sign-off.

Original wave/idle/writing/celebration/reading and path jump/flap use local first-party vector timelines through pinned Lottie3.6.1; cached compositions respect visibility, lifecycle and Reduce Motion. A seventh twirl timeline is identified and retained, not used on a screen. Special login/result/call character timelines have not been matched to the archived iOS sequence; original still illustrations remain where the source is unresolved. No fabricated lip-sync, physical60fps measurement or100% motion claim. [Motion evidence](../flows/03_DUO_MOTION.md) and [asset provenance](../../../apps/mobile/assets/PROVENANCE.md) name the sources/runtime.

Registration/verification/deletion, speech/audio/call/permission, notifications, purchases and sync are explicitly local fixtures. New learning/progress/account state lives in memory; only the earlier onboarding choices are durably stored. Account-switch isolation, real auth/deep-link guards, Drift journal, microphone/assessment delivery, multi-course content, full subscription/support variants and all production edge cases still require their owning phase tasks. Mock registration is not a verified cloud account. No real Appwrite credentials, provider requests or paid plan was enabled.

Browser review observed all five tabs, start→image choice→correct feedback→pause→Resume, words reveal→remember/next counter, monthly introduction→hub, profile→settings→back, and the locked league. `web/profile-current.png` is a fresh browser capture; `frontend/` contains the complete57 static fixtures. The later browser scroll command and attempts to regain control timed out; final browser control/open-tab retention and console cleanliness are not certified. The compiled local preview remains the review artifact.

The web log records a successful Wasm dry run and an unused Cupertino font-family warning; no Wasm build/runtime verification is claimed. Android reports plugin Built-in Kotlin and SDK XML version warnings. Both actual builds passed. iOS/Xcode and physical-device performance remain unverified. No deployment/publication/push or full P1/P2/P3 completion occurred.
