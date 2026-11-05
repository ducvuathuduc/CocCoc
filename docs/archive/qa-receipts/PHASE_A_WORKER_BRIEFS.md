# Phase A worker briefs

Lead owns router, phase/claim documents, this file, UI_MASTER_LOG and commits.
Only one child may run at a time under the root repo native-fork rule.
All workers read root/mobile AGENTS, both project skills, canonical design and
their assigned task acceptance. Use bundled assets, typed mock state and
Riverpod MVVM. No backend/contracts/Appwrite/lock changes or descendants.

## W2 lesson — PM I1

Task IDs: P2-FE-001 (SC17), UI-FIDELITY-001, UI-CATALOG-008,
UI-EXTENDED-QA-010. First execute the PM brief at
`/workspace/projects/25b10038-9b3c-4e9b-bbe5-2053de7f453d/tickets/briefs/11-exercises-I1.md`.
Then stop for root review/QA before I2. Later order is I2, I3, Q; the fourth
existing file is 14-exercises-Q.md, not an I4 implementation ticket.

Exact allowed files for I1:

- apps/mobile/lib/features/learning/domain/learning_models.dart
- apps/mobile/lib/features/learning/application/learning_controller.dart
- apps/mobile/lib/features/learning/presentation/lesson_screen.dart
- apps/mobile/lib/features/learning/presentation/learning_widgets.dart
- apps/mobile/lib/features/learning/presentation/image_choice.dart (new if useful)
- apps/mobile/lib/features/learning/presentation/match_pairs.dart (new if useful)
- apps/mobile/test/features/learning/exercises_i1_test.dart
- apps/mobile/test/exercises_i1_ui_master_golden_test.dart
- apps/mobile/test/goldens/ui_master/ex_image_*.png
- apps/mobile/test/goldens/ui_master/ex_match_*.png

Core tokens are owned by W1/root; consume LessonMotionTokens, request changes
through root. No shared tests/logs edited. Root may explicitly expand the
allowlist for a required meaningful regression, after inspecting its purpose.

Refs fetched via live MCP by root before this brief:
sc_f691b4fff7e747c6b5bb85cdaa49e2e0 (image idle),
sc_b7f6add9477e4c57ba0ed0bc101a37d9 (selected),
sc_5b3164cb9c6448c1838c229517cebe1b (matched pair).
Worker fetches these plus sc_925a41252ecb4262a3c24780ef20f885 (correct image)
and sc_ceb894f17ed14dd08762802759a22ced (match idle) before editing.
Images are archived iOS; French content maps to existing English fixtures.
PM timings are authored targets. Unclear motion requires official Duolingo web
research with a cited URL, not a claim that stills prove timing.

Acceptance quoted from IMPLEMENTATION_PLAN: “SC01–22 and12exercise typedfake
flows; close state/guard/exit/feedback gaps without screen rewrite”.
Quoted from SCREEN_INVENTORY SC17: “12 registered renderers, feedback, retry queue”.
Quoted from COMPONENT_STATES: “selected blue stroke+check”; “tap updates stable
choiceId locally, no network; CHECK validates selection; preserve on timeout”;
“one left/right selected, matched disabled; mismatch panel”; “select pair locally;
submit full pair set when done; matching correctness rendered from deterministic
rule in cached mode and authoritative result online”. The PM I1 local mismatch
flash provides the mismatch signal without a global graded-answer panel.

Required RED before implementation: right-first selected visual; mismatch red
then idle at300ms; matched pair disabled after flash/settle; image CHECK disabled
until selected. Test stable selected IDs, duplicate-match protection, cancellation,
feedback lock, reduced motion and text2. VM owns pair selection/outcome; view
owns finite decoration lifecycle. Match either selection order with independent
deterministic columns. Preserve lesson receipts/XP/hearts/retry semantics.

Apply all PM I1 geometry/keys/states. NEW WORD must depend on authored metadata
or an explicit fixture attribute; do not infer every image is a new word. If
metadata is required, keep it local and backward-compatible in Exercise.
Original/bundled artwork only, no drawing new mascots.

Commands after `. /workspace/tools/env.sh`, apps/mobile cwd:
`flutter analyze --no-pub --fatal-infos`;
proxy-free `flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false
test/features/learning/exercises_i1_test.dart test/exercises_i1_ui_master_golden_test.dart`.
Proxy-free means env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY
-u ALL_PROXY -u all_proxy NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost.
Goldens: PM 390×844 idle/selected/matched/wrong states in ui_master plus
360×800 and430×932 × text1/text2 for image selected and match idle. Run generation
then comparison; open captures and list differences from the source.

Return scoped diff, RED/green counts/commands, golden paths, reference deltas,
limitations and any required follow-up. No worker commits: root reviews and
commits `UI: exercises image and match — P2-FE-001 — Gummble sc_f691b4ff/sc_ceb894f1`.

## QA rotation after each slice

Tasks P2-QA-001/UI-QA-014; exact file scope is assigned from the returned
worker artifact list. Compare every golden with its matching freshly fetched
Gummble reference; list >2dp/color/state/type/motion gaps and severity. Do not
alter feature code during QA. Missing states/references remain explicit gaps.
PM 14-exercises-Q runs after I3 and writes exercises.qa.md in external specs
and docs/design/qa. Full goldens cannot establish browser/device success.

W3 tabs and W4 extended receive concrete allowlists after their gap audit;
reuse completed canonical families and plan order, no speculative rewrite.
