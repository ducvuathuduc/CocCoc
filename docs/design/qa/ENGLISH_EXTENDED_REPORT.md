# English extended frontend receipt

2026-10-05. User-authorized mock frontend, English learning focus. This extends
the [130-test baseline](FULL_FRONTEND_REPORT.md); it does not certify all148
catalog flows, production capabilities, or100% archived-iOS pixel/motion fidelity.

Current native slices: English lesson/practice/guide/score/flags, Words + sort +
recall, Sections + details, Energy, Super trial/plan/tour/subscription/family/cancel,
Story + questions, Radio + transcript/pairs/multi-choice, typed Roleplay + feedback,
Rapid Review + countdown/pause/expiry/retry, Legendary + milestone/results,
Oscar's passport Adventure + object choices, Explain My Answer + votes/back,
eight-title Stories library + independent sessions, Max reminder/individual/family
plans + mock checkout + resumable tour/cancellation, and Timer Boost purchase/
inventory/success +60-second expired-challenge continuation, streak/friend
invitations/shield/calendar, family reactions, achievements/monthly badges,
Friends Clash and status/feed/comments/learning-detail previews.
Text, buttons, forms, feedback, cards and navigation are native Flutter widgets.

## Executed checks

| Command | Evidence |
| --- | --- |
| `node tools/scripts/mobile-check.mjs --with-blueprint` | PASS blueprint, format, fatal-info analyzer,239 tests. `english-current-gate.log`. Previous177/182/200-test receipts remain historical. |
| `flutter test test/timer_boost_test.dart test/max_flow_test.dart test/full_frontend_qa_test.dart --dart-define=ENABLE_MASCOT_MOTION=false` | PASS23 tests before final full gate: real modal dismiss/reopen/purchase return, duplicate tap, timer background/resume, wallet at360/text2, Max Back/resume/cancel and baseline tab/Shop regression. `timer-boost-routed.log`. |
| `flutter test --dart-define=ENABLE_MASCOT_MOTION=false test/challenge_test.dart test/duo_motion_test.dart` | PASS countdown stops when hidden, restarts correctly, wrong-answer retry, reduced motion and original vector parsing. `challenge-motion-tests.log` |
| `flutter test --dart-define=ENABLE_MASCOT_MOTION=false test/adventure_test.dart` | PASS5 tests: wrong input preserved, idempotent claim,360/430 × text1/2. `adventure-green.log` |
| `flutter test --dart-define=ENABLE_MASCOT_MOTION=false test/explanation_test.dart` | PASS6 tests: real lesson→explanation→back retains wrong selection/feedback; twelve explanations covered; long answers at360/430 × text1/2. `explanation-green.log`; actual overflow RED in `explanation-red.log` |
| Static capture tests: `extended_capture_test.dart`, `social_capture_test.dart`, `status_feed_capture_test.dart`, with `CAPTURE_UI=true` / `ENABLE_MASCOT_MOTION=false` | 124 source-sized static PNGs in `english-extended/`,1180×2556 with390 logical width and59/34 safe insets. Latest social/status captures include source art preload and corrected illustration aspect ratios. `social-capture.log`, `status-feed-capture.log`; earlier extended capture logs remain historical. |
| `flutter test test/clash_runtime_capture_test.dart --dart-define=CAPTURE_CLASH_RIVE=true` | PASS1 test with actual inner RiveWidget assertion; four actual Eddy/Zari/Oscar/reaction frames. `clash-rive-capture.log`. Run separately from static capture settling because the original animation advances continuously. |
| `flutter test --dart-define=CAPTURE_MOTION=true test/motion_reference_capture_test.dart` | PASS original timeline frames, including Bea0/110/220/330. `motion-source-capture.log`, `motion/` |
| Original Rive test with `CAPTURE_CAST=true` | PASS3 tests, all ten files and exact inputs, actual cast renders, Falstaff reaction frames. `character-tests.log`, `cast/` |
| `node tools/scripts/reference-asset-audit.mjs` | PASS951 ordered instances across18 families;201 bundled PNGs match saved source hashes. `reference-assets.json` |
| `node tools/scripts/mobile-web-build.mjs` | PASS current release web with local Rive44 JS/WASM,87.8s. `english-current-web-build.log` |
| `flutter build apk --release --split-per-abi` | PASS current mock-default release APKs: armeabi-v7a40,870,471 bytes, arm6444,182,381 bytes, x86_6446,070,238 bytes,136.3s. `english-current-android-build.log`; hashes in [artifact receipt](english-current-artifacts.json). |
| `flutter build apk --debug --dart-define=USE_MOCK_AUTH=true` | PASS normal Android debug APK. `english-android-build.log`. No new device execution in this slice. |

Commands with Windows Rive native tests first prepend the SDK release DLL
directory to the existing case-insensitive Path key. The repository check script
handles this and runs the SDK setup step. No SDK source patch is required.

Release compilation retains SDK diagnostics for an unbundled CupertinoIcons
font family, Android SDK XML-version mismatch and the plugins' future Built-in Kotlin migration. These builds
succeeded; they are not zero-warning or iOS validation receipts.

## Mascot evidence by placement

| Placement | Actual asset/control | Verified limit |
| --- | --- | --- |
| Welcome/intro | Original wave, measured viewport, one-shot600–755 on welcome | Native lifecycle/reduced-motion; archived iOS timing unproven |
| Onboarding reactions/writing/building | Original celebration/idle/pencil/reading timelines | Viewports retain original still fallback |
| Learning path | Original jump/flap0–220, loop | Twirl identified but not asserted active |
| Lesson prompt | Original Falstaff Rive,99×149, reset/correct/incorrect triggers | Web rendering inspected; no viseme inputs in this rig |
| Rapid introduction | Original Bea s'mores0–440 at60fps,185×250 viewport | Four actual frames inspected; revised crop retains head/feet/fire |
| Rapid/Legendary prompt | Original Oscar/Junior Rive,135×180; same verified triggers | Actual cast renders inspected; archived timing unproven |
| Story/Radio completion | Original Duo celebration plus archived still | UI content intentionally English; no original Radio audio/lip-sync |
| Legendary gold/milestone/results | Original still ROIs | No matching original animated gold rig obtained |
| Roleplay/Lily call | Original restaurant/call illustration, native replies | No original call head/body/viseme export obtained; microphone/AI simulated |
| Adventure | Original airport/collected-passport/Lucy/Eddy+Duo artwork | Walking rig and source dialogue timing unresolved; native tappable objects |
| Stories library | Eight original cover illustration regions; native titles/cards/scripts | Source speaker rigs for seven authored scripts remain absent; library thumbnails are stills |
| Max offer/tour/family | Original black Duo, Lily call, benefits/invite/completion art; native thin progress bar/circular markers | Original black Duo flight/call viseme rigs absent; missing archived tour2/3 scenes use verified feature icons |
| Timer Boost | Original clock/basket/barrel and blue rays illustration regions | Native sheet/tactile transition only; no original success timeline obtained |
| Streak/family/achievement/monthly | Original source art regions with native calendars, cards, states and sheets | Joint scenes and unmatched motion remain stills; archived calendar/badges are explicit fixtures |
| Friends Clash | Original Eddy coach and Zari/Oscar makerInLesson exports, verified reset/correct/incorrect inputs | Four actual Rive captures; archived pose/frame timing remains unresolved; competition is local mock state |
| Feed/status | Original Oscar/Eddy exports in mapped detail screens; original status/feed art regions | Premium status symbols and joint scenes are stills; dashed avatar ring/source variants remain fidelity gaps |

All ten makerInLesson Rive assets verify artboard `character`, machine
`character_statemachine`, three reaction triggers and dark/RTL booleans.
Files/URLs/hashes: [original character receipt](original-character-assets.json).
No speech inputs were invented. [First-party Lily implementation](https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life)
describes additional head/body combinations and visemes; the article does not
provide that original export. [Duolingo's viseme engineering](https://blog.duolingo.com/world-character-visemes/)
also requires audio/phoneme timing absent from still screenshots.

## Visual review and practical limits

Opened the native Story/Radio/Roleplay, Rapid introduction, Adventure object grid
and completion, and correct/wrong explanations alongside their original sources.
Original object/character art is preserved. Rapid title/color, illustration size,
label/value divider and Bea composition crop were corrected after inspection.
Explanations initially overflowed on long pair answers; bounded scrolling fixes
the verified failure. ReferenceArt no longer retains every decoded source forever:
Flutter's bounded cache and mounted-widget ownership pass eviction/release tests.

The web wrapper now displays a390×844 logical phone scaled to available browser
height, preserving wrap points while making the entire screen visible. The
loopback server runs separately from tool sessions. Browser inspection can emit
an unattributed MutationObserver error; rendered UI still works. Do not report a
clean console without resolving its source. Current screenshots/controls are
checked through the selected browser, not a replacement image mockup.

Current release web was exercised directly through the in-app browser: Home→
Practice→Stories library→Jacket entry→reading; Home→Shop→Timer Boost single→
insufficient funds→explicit demo balance→success→Shop showed585gems/one boost;
Shop→Max offer→comparison→3-day reminder→Family plan→local checkout confirmation→
welcome→invite skip→Video Call tour. Browser screenshots are `stories-browser.jpg`,
`story-reading-browser.jpg`, `timer-offer-browser.jpg`, `timer-success-browser.jpg`,
`timer-shop-browser.jpg`, `max-offer-browser.jpg`, `max-checkout-browser.jpg` and
`max-call-browser.jpg` in `english-extended/`. The same unattributed
MutationObserver diagnostic remains in the browser log. Browser interaction,
native test/capture evidence and production capability proof are distinct.

Routed review fixed two Max lifecycle defects: confirmed-tour Back now resumes
the current page instead of checkout; cancellation discards prior plan/reminder/
tour state. Stories retains the same story's selected answer and draft after
exit/resume, grades wrong choice/word order and returns completion to the library.
Timer purchases atomically debit the local wallet and increase inventory once.
Expired Rapid can consume one boost for60foreground seconds without losing its
answer. A stale second tap cannot open checkout after resuming. Insufficient
funds preserve selection and expose one clearly labeled local demo top-up.

Narrow text-scale2 purchase testing exposed a37px Home status-row overflow after
the wallet increased; native status controls now wrap while retaining text size.
RED: `timer-wallet-text2-red.log`; final239-test gate includes the fix. Home and
Shop now display the same local wallet. A baseline Shop test required a settled
frame after scrolling to its now-lower freeze purchase button; its original
insufficient-funds behavior remains covered.

Social continuation was analyzed from ordered Gummble sources before coding;
see flows16–19. Draft status dismissal preserves committed state, premium unlock
checks the owned wallet, comments preserve invalid input, and route return/timer
pause/stale actions are covered. Freeze purchase also now checks its owned wallet
instead of trusting a caller-supplied balance. Local reactions, invitations,
comments, sharing and Clash opponents do not send anything to external accounts.
Native source review corrected achievement artwork bounds and preserved source
illustration aspect ratios. Browser proofs are `streak-friends-browser.png` and
`clash-coach-browser.png`; actual Rive pose differences remain documented rather
than hidden by a fabricated crop or pinned frame.

English/Vietnamese phrases and local rewards are authored fixtures. Card/feedback
adaptations and missing source transitions remain visible differences; there is
no numerical pixel-perfect pass. Some Super/Max gradient-art edges remain visible.
The exact archived font binary, all motion timing, device FPS/memory, real audio,
cloud auth/sync/AI, billing, OS sharing/widgets and iOS execution are unverified.
The previous universal debug APK is276,587,592 bytes; debug native libraries across ABIs
are not a production download-size acceptance result. Current release ARM64 is
44,182,381 bytes; compilation is not a physical-device performance proof. The source PNG bundle contains
201 byte-audited PNGs. Device profiling requires its own receipt.

## Remaining catalog reconciliation

All148 scoped flows have ordered metadata and original PNGs:912 steps,779 distinct
images. They contain duplicate versions and entitlement/platform variants.
Remaining native families/variants include additional Stories scripts/speaker variants, avatar creation,
additional status/feed/friend-streak/Clash/nudge/invite/removal and achievement/monthly variants, course
removal/goals/skip-unit, additional Max/family/gifting and platform checkout variants,
phone/password/saved-account variants, Schools/support/privacy/widget/Live
Activities/year-review/app-icon states, and older Hearts variants. Already
implemented families still require variant-by-variant reconciliation. Continue
analyze→implement→inspect rather than treating downloaded screenshots as done.

Frozen architecture and full P1/P2/P3 production gates remain pending. The user
authorized the current private GitHub source/build upload; see [snapshot scope](GITHUB_SNAPSHOT.md).
No deployment, external purchase, user messaging or live AI is part of this receipt.
