# English course UI continuation — 2026-10-09

UI-COURSE-040, UI-GUIDE-041, UI-SKIP-042 and UI-COURSE-QA-043 are complete within the assigned native mock scope. Root and one isolated worker added eight English section samples, section-specific CEFR/grammar, eight guidebooks, destination-specific practice and five-heart unit/section checks. Prior completion marks remain intact.

The routes preserve their section/unit identity. Invalid or locked-section unit links return safely; cancel/Back preserves input and learning counters. Checks retain wrong answers, advance only after correct feedback, show the last-heart warning once, and acknowledge completion once. A passed check changes the local navigation projection; higher-target practice uses scoped guest receipts without ranked XP. The existing feature-first Riverpod MVVM and dependency pins are retained.

Lin now uses the previously inspected first-party Rive asset and reset/correct/incorrect inputs. A behavior test follows reset → incorrect → retry reset → correct → next-question reset and verifies unchanged XP state. Runtime pause, reduced motion, resource disposal and state-machine exports remain covered by the existing motion suite. Still captures deliberately disable motion and cannot establish archived frame timing. Duolingo describes this state-machine approach in its [official animation article](https://blog.duolingo.com/world-character-visemes/); the [Rive Flutter documentation](https://rive.app/docs/runtimes/flutter/flutter) describes the runtime and resource management.

| Command | Actual result / receipt |
| --- | --- |
| Pre-implementation catalog/guide behavior tests | Two RED cases in [course-finish-red.log](course-finish-red.log) |
| Locked-section route and Lin feedback tests before fixes | Two RED cases in [course-finish-guard-motion-red.log](course-finish-guard-motion-red.log) |
| Native capture + parent/worker behavior + English regression tests | 33 PASS; [capture log](course-finish-captures.log), 17 PNG states at 1180×2556 in [course-finish](course-finish/) |
| flutter test --dart-define=CAPTURE_COURSE_MOTION=true --dart-define=ENABLE_MASCOT_MOTION=true test/course_motion_capture_test.dart | 1 PASS with native Rive enabled; two different idle frames, incorrect/correct reactions and reduced-motion fallback. [Motion log](course-finish-motion.log) and 5 inspected PNGs in [course-finish-motion](course-finish-motion/) |
| node tools/scripts/mobile-check.mjs --with-blueprint | Blueprint, format, fatal-info analyzer and 424 Flutter tests PASS; [gate](course-finish-gate.log) |
| node tools/scripts/reference-asset-audit.mjs | 951 saved sources / 238 bundled original PNGs match; [hash receipt](reference-assets.json) |
| node tools/scripts/avatar-asset-audit.mjs | 18 assets / 8 categories / 282 choices pass; [existing avatar analysis](../flows/24_AVATAR_ASSET_RESEARCH.md) |
| node tools/scripts/mobile-web-build.mjs | Release Flutter web PASS; [build log](course-finish-web-build.log) |
| node .cache/course-http.mjs | 20 HTTP200/no-store checks and served main.dart.js matches latest build; [HTTP receipt](course-finish-http.json) |

Visual review covered catalog/detail/CEFR/grammar, guide header/phrases/tip, check intro/answer/incorrect/warning/failure/pass, returned unit path and section-check entry. Captures assert decoded illustrations. Review corrected source-art clipping, sticky-header geometry, text2 overflow and pink unit2 styling. The legacy English translation assertion is now scoped to its phrase bubble because the new tip intentionally repeats the phrase. Native fixtures cover 320px, text scale2 and reduced motion. The enabled Lin rig uses its complete exported artboard, which has more internal padding than the reference still; these captures do not certify identical mascot bounds at every animation frame. The Rive loader emits a diagnostic while attempting Windows DLL candidates; its successful render, active controller, changing frames and reaction assertions establish this native run. HTTP delivery is separate from live browser interaction and physical-device performance.

The persistent register now has 33 reusable native families, 14 complete ordered mock flows and 105 verified source-screen occurrences. Five source-path occurrences in these five researched flows remain in progress: advanced/completed path geometry is reused rather than asserted identical. Their other 16 states are marked verified with evidence. See [analysis](../flows/29_ENGLISH_COURSE_NAVIGATION.md) and [checklist](FLOW_CHECKLIST.md). Original private Duo timelines, middle-section art variants, full curriculum and production services have separate acceptance scope; this does not certify all 148 flows or 1:1 motion.

Preview: http://127.0.0.1:4173/preview.html . The page hosts the actual Flutter build. Product UI has no engineering/demo credential banner.
