# Exercises I1 implementation spec

Task IDs P2-FE-001 (SC17), UI-FIDELITY-001, UI-CATALOG-008, UI-EXTENDED-QA-010. PM ticket11-exercises-I1 scope: [repo worker brief](../docs/design/qa/PHASE_A_WORKER_BRIEFS.md). Reference research: [I1 review](../docs/design/qa/exercises_i1.qa.md). Baseline before implementation supplied by lead:466passed/5existing Rive native failures, analyzer0issues. Shared core tokens/router/locks belong to lead.

Acceptance: “SC01–22 and12exercise typedfake flows; close state/guard/exit/feedback gaps without screen rewrite”; “12 registered renderers, feedback, retry queue”; “selected blue stroke+check”; “tap updates stable choiceId locally, no network; CHECK validates selection; preserve on timeout”; “one left/right selected, matched disabled; mismatch panel”; “select pair locally; submit full pair set when done; matching correctness rendered from deterministic rule in cached mode and authoritative result online”.

## Live references inspected before edits

Gummble MCP detail fetched for all five:
- [image idle sc_f691b4fff7e747c6b5bb85cdaa49e2e0](https://gummble.com/screens/sc_f691b4fff7e747c6b5bb85cdaa49e2e0)
- [image selected sc_b7f6add9477e4c57ba0ed0bc101a37d9](https://gummble.com/screens/sc_b7f6add9477e4c57ba0ed0bc101a37d9)
- [image correct sc_925a41252ecb4262a3c24780ef20f885](https://gummble.com/screens/sc_925a41252ecb4262a3c24780ef20f885)
- [match idle sc_ceb894f17ed14dd08762802759a22ced](https://gummble.com/screens/sc_ceb894f17ed14dd08762802759a22ced)
- [match green pair sc_5b3164cb9c6448c1838c229517cebe1b](https://gummble.com/screens/sc_5b3164cb9c6448c1838c229517cebe1b)

Archived iOS catalog version800/captured2025-12-30 per existing research, not current app verification. First four source images1179×2556 (~393×852dp at3x); fifth detail does not provide dimensions. French vocabulary maps to current English/Vietnamese mocks without pretending copy is identical. Existing bundled art only; no new asset downloads/copies.

## PM geometry, palette and states (implementation targets)

Image: authored-new-word badge only; purple NEW WORD above23sp/w700 prompt; blue speaker and dotted/underlined vocabulary. Four image choices in two columns,16dp gaps, radius16,2dp border #E5E5E5 and4dp solid lower edge; art centered; labels17sp. Idle white/gray. Selected #DDF4FF surface and #1577A4 border/label/edge. Correct #D7FFB8/#235B00 plus sparkle marks; incorrect #FFE1E1/#A41414. Only selected result tile changes after grading; untouched choices stay idle. Press translateY4dp with lower edge removed. Bottom CHECK disabled until choice, gray #E5E5E5/text #AFAFAF. Keys image_choice_card_<index> and lesson_check_button.

Match: title Tap the matching pairs23sp/w700. Independently ordered left terms/right translations, deterministic once per exercise; matching identity remains original stable term/translation IDs, not visible index.24dp column gap, each tile full-column width and min72dp painted height, radius14,2dp #E5E5E5 border/4dp lower edge, label18sp,18dp rows. Grow/scroll attext2 rather than truncate or overflow. Either-side selected #DDF4FF/#1577A4. Correct pair green #D7FFB8/#235B00 flash then settle into disabled white/gray #E5E5E5 text/border, no edge. Wrong pair #FFE1E1/#A41414 and finite horizontal shake ±6dp/threecycles; return idle without global feedback/hearts/reward changes. Keys match_left_<i>/match_right_<i>.

Existing role tokens: LearningColors.purple/blue/correct; ReferenceColors.surface/border/blueFill/blueBorder. Some existing reference tokens differ from PM exact targets; lead owns shared-token updates. Feature-specific PM target roles may be named in learning_visuals.dart (allowed), without redefining core architecture.

## Motion provenance

LessonMotionTokens.pressDuration100ms, matchFlash150ms, matchSettle200ms, mismatchShake300ms. PM press curve easeOut, displacement4dp. PM mismatch ±6dp/threecycles/300ms; no additional easing curve is supplied (UNKNOWN). Match settle curve UNKNOWN from source/PM; use existing documented project ease token only as an authored approximation, record it. All reduce-motion durations zero and final states immediate; finite effect controllers stop/dispose on lifecycle/exercise changes.

Source timing/curve is UNKNOWN because references are stills. [Official Duolingo animation research](https://blog.duolingo.com/streak-milestone-design-animation/) discusses iterative timing refinement, without specifying these button/match durations. No source-exact motion claim.

## State/model change plan

Existing LessonState stores only selectedPairLeft; selectPairRight ignores right-first taps. Add nullable selectedPairRight and explicit clear flag. Add immutable typed PairAttempt with left/right IDs, matched/mismatched enum and monotonically increasing local attempt identity. VM attempts matching in either order, rejects unknown/already-matched IDs and duplicates, commits correct matchedPairs once, and emits one decoration event. A nonce-checked finish command clears only its own event; stale completions after next/start/pause/abandon cannot mutate newer state. Preserve stage/busy guards and authoritative full-answer grading/reward receipts. Decoration completion never awards XP or matches.

UI owns finite animation, not correctness. Match feedback disables further pair input until resolved; pause cancels transient decorations while preserving authored choices/matched pairs. Next/start/abandon clear both selections and attempts. Reduced-motion resolves final decoration state immediately.

Exercise gains backward-compatible bool isNewWord=false plus copyWith. Lead expanded data/learning_repository.dart allowance only to mark the existing english-01-image fixture explicitly true. Other exercise kinds remain unchanged.

## Meaningful RED plan

New exercises_i1_test.dart: right-first tile selected appearance; right-first then correct-left resolves stable IDs; invalid/matched duplicate calls do not change state; mismatch shows local red and returns idle after300ms without global grade; matched flash green then disabled after150+200ms; image CHECK starts disabled then enables only valid choice; selected result/focus/pressed cancellation preserve IDs; stale completion after pause/start does not affect newer state; feedback locks input; reduced-motion immediate states and text2 no overflow.

Tests initially target existing public methods/widget text to obtain actual assertion RED, not compiler errors from proposed types. After RED implement minimal bounded changes, then add typed/stale-event coverage.

## Screenshot and gate plan

New UI-master390×844 image idle/selected and match idle/right-selected/matched/wrong-midflash; add image correct/incorrect if needed for acceptance.360×800 and430×932 ×text1/text2 for image selected and match idle. Load existing bundled fonts/art, open every capture, compare against corresponding references. Source-selected/mismatch/text2 states not available remain explicit UNKNOWN. Light-only does not close full42screen/dark gate.

Run sourced Flutter analyze --no-pub --fatal-infos, then proxy-free flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false for the two new I1 tests. No concurrent Flutter runner; lead announces free. Lead runs full suite count≥baseline+new tests and QA before any feature commit.

## Visible spec/source disagreements to retain

The archived image idle action reads CONTINUE, while PM requires disabled CHECK. PM selected border/text #1577A4 is darker than the captured bright blue; PM correct text #235B00 is darker than captured green. PM disabled matched-white state is unobserved; archived matched capture shows green only. These are explicit PM targets with source deltas, not inferred current Duolingo behavior. Strict QUALITY_GATES acceptance must record correction or owner acceptance of these deliberate differences before feature commit.

## Resumed implementation receipt (2026-10-09)

Fresh four-test RED re-run before renderer wiring:0pass/4fail, all expected
styling/key assertions (not compiler failures). Receipt:
`/workspace/tools/coc-phase-a-i1-red.log`. The old `/tmp` receipt did not survive.
Implementation now uses isolated image_choice.dart and match_pairs.dart plus
ExerciseTile in learning_visuals.dart; existing other ten renderers remain.
Right/left orders shuffle independently using a deterministic exercise-ID seed.
Pair attempts are nonce-checked and input-locked until finite effect completion;
CHECK for the full pair set waits for decoration completion. Pause clears only
transient effects and preserves selected IDs/matched pairs. Animation rebuilds
only the pair columns, not the lesson screen. Dispose stops the controller.
Matched settle uses existing easeOutCubic (authored approximation); mismatch
uses sinusoidal three cycles over300ms (curve UNKNOWN in source).

11behavior/state/accessibility tests and16golden fixtures are now authored.
Initial resumed analyzer was terminated(-9) under concurrent Flutter memory
pressure; its only emitted diagnostics were2brace infos in the recovered
controller, both corrected. Serialized rerun and targeted GREEN are still pending;
no success/QA/fidelity claim and no worker commit. Root owns full gate/QA.

## Source-supported continuation measurements — 2026-10-10

Five original I1 references fetched again through Gummble MCP before edits.
G-COLOR supersedes PM invented palette targets; keep unknown source states explicit.
Modern prompt ink sc_b7f6add9(63,522)=RGB75/75/75, exact existing
ExerciseTileTokens.ink. Original image cards span510×664px; inter-card gap64px
at3x. Source grid geometry therefore uses card height/width664/510 and21.333dp
gutters, replacing PM16dp where the later owner requires source parity.
Original lesson03 girl's art pixels span x676..1079,y891..1298; current x705
crop clips29px of left hair. Boy spans x127..478,y893..1290; cat x113..494,
y1707..1953; woman x702..1051,y1627..2009. Measurements used PIL getpixel
on the original bundled PNG, no binary edits or recoloring.

Older text-match sc_5b3164cb is1180×2556px. PIL exact samples: surface(0,0)
RGB254/252/254, idle border(63,990)231/229/231, text(268,1063)77/75/78,
flash fill(83,726)219/255/187, flash border(84,720)169/238/115,
disabled label(524,2323)179/176/179. Lead must admit this own-screen palette
before named feature token usage; modern-image role substitutions do not
establish closer matching to this older reference.

Three additional meaningful widget regressions saved before implementation:
modern image prompt ink, image card ratio/gutters independent of viewport
height, and complete girl hair crop. Runner RED/GREEN pending serialized grant.
Wrong-boy state-background crop remains UNKNOWN: no established bundled wrong
image source was found. Do not manufacture/recolor an asset or claim its white
rectangle has been corrected. Motion timings remain the prior PM-authored
approximation; official animation URL above supplies no precise duration.

Five fresh RED regressions established before implementation: three source
image ink/proportion/hair failures in coc-phase-a-i1-correct-red.log; one old
match surface/flash failure in coc-phase-a-i1-match-palette-red.log; one old
match CHECK/track failure in coc-phase-a-i1-match-controls-red.log, all under
/workspace/tools/. Existing assertions retained and own-match same-state RGB
expectations made exact to its own sampled source. Final targeted command:
`flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false
 test/features/learning/exercises_i1_test.dart --reporter expanded` passed17/17,
receipt coc-phase-a-i1-correct-green.log. Source env.sh on its own line and
removed all HTTP/HTTPS/ALL proxy environment variables. No golden update yet.

Implementation saves source dimensions as ImageChoiceGeometry:510px card width,
664px extent,427px art box,64px source gutter at3x. Minimum height grows for
text2; proportions are independent of available viewport height. Own old-match
correct glyph sample(245,799)=RGB97/165/19 (#61A513), dominant1181pixels in
source box210,790,370,865. MatchTileTokens consumes the lead-admitted palette;
matching surface, prompt, progress track and disabled CHECK share that mapping.
The unseen enabled old-match action retains existing green as an explicit
adaptation. First match-row anchor adds25/3dp to the prior55dp inner offset,
consistent with239.33dp old-text source rather than257.33dp audio source.
Selected/mismatched match colors remain modern-role adaptations with source
state UNKNOWN. Wrong-boy white rectangle remains open. Final analyzer/capture
receipts pending; no independent QA, full-suite or ticket closure claimed.
