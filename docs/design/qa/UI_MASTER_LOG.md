# UI fidelity work log

## 2026-10-09 — core lesson feedback/header claim

Owner: root. Assigned area: UI-FIDELITY-001 / UI-EXTENDED-QA-010,
`apps/mobile/lib/core/design/lesson_motion.dart`, existing lesson presentation,
targeted tests and `test/goldens/ui_master/`. Mock data only. Owner's
2026-10-10 decision accepts B01–B07 for this UI work; three-service architecture
remains final. No backend, contracts, Appwrite or dependency changes.

Read the required plans, skills and ordered index before implementation. Live
Gummble pattern search returned no lesson-feedback family; exact Duolingo flow
search succeeded. Fetched all 33 Starting a lesson steps and all 22 Completing
a lesson steps (55 ordered metadata entries, not 55 visually inspected screens).
Deep-inspected these archived iOS references before changes:

- [Selected image / highlight](https://gummble.com/screens/sc_b7f6add9477e4c57ba0ed0bc101a37d9),
  Completing a lesson step 5.
- [Correct feedback](https://gummble.com/screens/sc_925a41252ecb4262a3c24780ef20f885),
  step 6: green overlay covers lower choices without resizing the exercise.
- [Incorrect feedback](https://gummble.com/screens/sc_3b88d8f19d7e4f3597bdce7d3ea169b7),
  step 9: red correction, explanation and Got it; heart count is four.
- [Streak progress](https://gummble.com/screens/sc_bab6c64dec12434297fede3f7c0bef68),
  Starting a lesson step 33: orange fill with lighter inset highlight.

Source dimensions: 1179/1180 × 2556. Existing catalog identifies these as
archived iOS captures; no current installed-app or source-animation claim.
Measured target: rounded 16px progress track with inset highlight. Current gaps:
plain linear fill, resizing feedback, no outcome haptic or heart-loss shake.
Preserve authored English/Vietnamese content, existing explanation/report actions,
routes, grading and retry state. Reuse bundled illustrations only.

Motion fallback research:
[Duolingo character animation](https://blog.duolingo.com/building-character/)
and [streak animation](https://blog.duolingo.com/streak-milestone-design-animation/).
These explain celebratory animation intent, not exact UI durations. The owner's
100ms press / 250ms feedback request supplies timing targets; progress ease-out
and heart shake remain explicitly authored approximations until recordings exist.

Validation and final artifacts will be appended after the slice passes.

### UI-MASTER-01 lesson slice acceptance

- [x] Correct/incorrect feedback overlays choices without changing their
  illustration viewport; correct feedback has one primary Continue action.
- [x] 250ms upward entrance, semantic live region and bottom safe-inset color.
- [x] 16px rounded progress with inset shine and 300ms ease-out fill.
- [x] One haptic per graded answer; duplicate checks do not replay it.
- [x] Heart decrease shakes once, settles, stops on background and does not
  replay on resume; reduced motion is immediate and still.
- [x] 390×844 ready/selected/correct/incorrect goldens and eight 360/430 ×
  text1/2 correct/incorrect goldens; decoded bundled illustrations asserted.

Additional deep inspection:
[Lily meaning feedback](https://gummble.com/screens/sc_6d64b91d069a4a50a74981811fddb082),
Starting a lesson step 20. Correct feedback removes the extra explanation CTA;
incorrect feedback preserves the existing explanation route and identifier.

RED evidence: all three initial behavior cases failed before implementation:
choice rectangle moved upward by 26px, feedback did not slide, and no haptic
was emitted. A separate compact-feedback case failed while the extra correct
explanation CTA was still visible. The original RED commands used the same
proxy-free test invocation below with `test/lesson_fidelity_test.dart`.
The first test harness needed authored exercises to avoid awaiting a mock timer
inside fake time; that harness issue was corrected before the RED receipt.

Commands from `apps/mobile`, after `. /workspace/tools/env.sh`:

```sh
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost flutter test --dart-define=ENABLE_MASCOT_MOTION=false test/lesson_fidelity_test.dart test/lesson_ui_master_golden_test.dart test/learning_flow_test.dart test/english_spoken_lesson_test.dart test/explanation_test.dart
flutter analyze --fatal-infos
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost flutter test --update-goldens --dart-define=ENABLE_MASCOT_MOTION=false test/lesson_ui_master_golden_test.dart
```

Results: 37 targeted tests pass, analyzer reports no issues, and all 12 golden
generation/responsive cases pass. Golden files:
`apps/mobile/test/goldens/ui_master/core_lesson_image_{ready,selected,correct,incorrect}.png`
(390×844), and `core_feedback_{correct,incorrect}_{360,430}_text{1,2}.png`.
Opened correct/incorrect native goldens plus 360/text2 incorrect and 430/text2
correct; compared hierarchy, clipped lower choices, highlight and safe inset
against the live Gummble stills. Goldens pin Flutter rendering, not source
pixel equivalence. Fonts and icons load from the existing bundled assets.

Known remaining differences: authored English choices/illustrations and course
content differ from the French reference; existing art crops retain white
backgrounds on selected cards; archived share-toolbar and explanation-decoration
variants remain unclosed. No new artwork, dependency, route or backend changes.
Exact motion requires source recordings. Haptic calls are tested with Flutter's
platform-channel mock; physical device feel is unverified. No browser tool is
available, so UI-BROWSER-026 and UI-QA-014 retain their live browser requirement.
UI-CATALOG-008, UI-EXTENDED-009 and whole-app UI-FIDELITY-001 /
UI-EXTENDED-QA-010 remain open beyond this slice. Next priority: path/intro,
remaining exercise state variants, completion counters/celebration, then stats
and tab/section details before secondary families.

Repository checks initially could not start because `node_modules` was absent.
`pnpm install --frozen-lockfile` restored the existing tools (56.3s, no lock
change).

Full repository commands, after restoring dependencies:

```sh
pnpm backend:verify
pnpm backend:smoke
pnpm contracts:check
pnpm api:lint
pnpm audit:check
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u all_proxy NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost pnpm verify
dart run rive_native:setup --verbose --clean --platform linux
```

Backend verify/smoke, contracts (94 schemas / 30 fixture cases), API lint and
audit pass. `pnpm verify` passes blueprint, all-file format and analyzer, then
records **454 passing tests and 5 failures** (3m21s test run). All five failures
are native rig-loading tests: three in `avatar_motion_test.dart` and two in
`character_motion_test.dart`. This host reports `aarch64`; `file` identifies
the downloaded `librive_native.so` as x86-64. Clean official Rive setup succeeds
but supplies the same incompatible architecture. This is an unresolved host
capability limit; the full gate is not green. No tests are deleted or disabled.
The UI slice's 37 targeted cases and 12 golden cases pass on this host.

`flutter build web --release` is compiling at the first slice commit; its receipt
will be appended when it finishes. Flutter's automatic dependency resolution
rewrote hosted URLs/transitive entries in `pubspec.lock`; those incidental
changes were restored to HEAD bytes. No lock change is included in this task.

### Path-node press slice claim (after ea2ff75)

Area: existing `PathNode`, core motion tokens, focused press/cancellation tests
and home/lesson-intro goldens. Fresh Gummble path search returned an unrelated
goal flow; reused the exact Completing a lesson flow already fetched above.
Deep-inspected steps 1 and 2:
[path](https://gummble.com/screens/sc_e793f7fdfb3349cc8a32a78d9648ee07) and
[lesson intro](https://gummble.com/screens/sc_59c6c255ba9e4d26b6dfd59922951d8a).
Keep the current English course, stats, node placement and routes. The static
node has a 7px base but no press collapse/release bounce. Requested 100ms press
and authored 250ms release are motion targets; the public animation sources
above do not establish a measured native node timeline.

The first web compile finished successfully in 135.8s. That command proves
compilation only; the next build explicitly supplies the existing mock-auth
and bundled Rive-host defines required for the local preview.

### Path-node slice acceptance

- [x] 100ms face depression and 7px base collapse; ring geometry stays fixed.
- [x] 250ms release scale overshoot; cancellation restores without navigation.
- [x] Reduced motion uses zero-duration transitions; disposal has no queued tap.
- [x] Existing native path → intro → English exercise route remains working.
- [x] 390×844 `core_path.png` and `core_lesson_intro.png` goldens generated and
  opened against the two live source steps. Current English/energy/top-bar and
  five-tab variants remain; this press slice does not close their fidelity gaps.

RED: the baseline face stayed at its original Y while held; the regression
expected +7px. After implementation the focused route/cancellation/scale and
existing course/lesson tests all pass (17 cases). Analyzer reports no issues.
Commands from `apps/mobile` (same proxy-free prefix as above):

```sh
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/path_node_fidelity_test.dart
flutter test --no-pub --update-goldens --dart-define=ENABLE_MASCOT_MOTION=false test/path_node_fidelity_test.dart test/path_ui_master_golden_test.dart test/course_flow_test.dart test/learning_flow_test.dart
flutter analyze --no-pub --fatal-infos
flutter build web --no-pub --no-wasm-dry-run --release --dart-define=USE_MOCK_AUTH=true --dart-define=RIVE_NATIVE_WASM_HOST=rive/
```

Path tokens live in `core/design/path_motion.dart`; no new package, artwork,
provider or route. The full gate's five native host failures above remain.
The mock release rebuild is running at this small commit; append its outcome
before any browser/preview claim. Tests/goldens verify widgets and routes, not
physical haptics, native motion parity or browser delivery.

### 2026-10-09 continuation — completion motion claim

The prior mock rebuild was terminated during compilation (exit 143) at the
process limit. It is retried with the same mock-auth/local-Rive flags; no build
success is claimed for the terminated invocation. Continue from `a446a08`.
The resumed invocation completed successfully in 45.4s with mock auth and the
bundled Rive web host; no lock changes (`--no-pub`). This compilation covers
the two committed slices, not the later completion changes or browser QA.

Area: existing lesson summary and streak result, core count/celebration widgets,
focused tests and completion/streak goldens. Fresh live Gummble Completing a
lesson search resolves both 22-step and 13-step variants. Fetch the entire
13-step flow `238c4339-7173-4257-89c5-2716a8a68c44`; deep inspect
[Flawless](https://gummble.com/screens/sc_23afb65ade9a45f19dba4cf32e1fd5ab),
[older completion](https://gummble.com/screens/sc_a022c38e7b314af6a1b26f7f3ecea43e)
and [streak](https://gummble.com/screens/sc_80524686d64f4b2ca387b31023436c15).
Observed: yellow completion heading, bundled celebratory illustration/sparkles,
three bordered metric cells and blue bottom CTA; large orange streak numeral.
Current numerals are static. Animate actual immutable receipt XP/accuracy and
existing mock streak; never modify receipts or award from an animation callback.
Use authored geometric confetti consistent with inspected lesson celebration
stills, existing colors and the public motion references above. Exact particle
trajectories/timing remain authored approximations, not archived motion proof.

### Completion slice acceptance

- [x] XP and accuracy count to actual receipt values in 500ms; streak counts to
  the existing mock value. Rebuilding does not restart a finished counter.
- [x] Screen-reader labels expose final data throughout the interpolation.
- [x] 600ms geometric confetti ends, never blocks Continue, stops on background
  and does not replay on resume; reduced motion has final counts and no particles.
- [x] Animation never claims XP or modifies the receipt/progress provider.
- [x] Three 390×844 goldens: `core_completion.png`,
  `core_completion_celebrating.png` (150ms) and `core_streak.png`. All opened and
  compared with live result/streak references. Source labels AMAZING/BLAZING,
  exact illustration/layout variants and calendar history remain unclosed;
  this motion slice preserves existing metric labels and authored fixture data.
- [x] 360/430 × text1/2 reduced-motion cases keep Claim XP reachable.

RED: static XP was already 20 on the first frame, and no confetti layer existed.
New acceptance cases failed before implementing the widgets. A semantics handle
in the test harness was then moved to `try/finally` cleanup. The existing summary
test now waits for the finite count animation before asserting its final values;
its artwork/layout/receipt assertions are preserved.

Commands from `apps/mobile`, with the same documented proxy-free prefix:

```sh
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false test/completion_fidelity_test.dart
flutter test --no-pub --update-goldens --dart-define=ENABLE_MASCOT_MOTION=false test/completion_fidelity_test.dart test/completion_ui_master_golden_test.dart test/lesson_summary_test.dart test/learning_flow_test.dart test/english_spoken_lesson_test.dart
flutter analyze --no-pub --fatal-infos
```

25 targeted cases pass, including full mock claim/return and speaking/retry
flows; analyzer reports no issues. Tokens and lifecycle handling are in
`core/design/reward_motion.dart`. No route, dependency, reward formula,
backend write or new artwork file. Full `pnpm verify` and a mock/local-Rive web
build were started again after this slice; results will be appended separately.
Total UI master goldens so far: 17. All six top-level frontend task IDs remain
open pending their full acceptance, source-variant reconciliation and browser QA.


## 20-team-phaseA I1 local commit gate — 2026-10-10

ImageChoice/MatchPairs source corrections, typed state and16 new goldens are
locally verified;12 affected legacy image/feedback goldens are regenerated and
compared without tolerance changes. Analyzer0; targeted45/45; lesson regression
71/71; palette0 NEW against68 legacy baseline colors. Latest user authorization
permits this scoped commit with remaining visual/global/full gates explicit.
[Review, exact commands and known art/source gaps](I1_COMMIT_RECEIPT.md).
Whole ticket stays open; no device/browser/native/production claim.
