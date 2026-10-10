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

- apps/mobile/lib/features/learning/data/learning_repository.dart (authored isNewWord metadata only)
- apps/mobile/lib/features/learning/domain/learning_models.dart
- apps/mobile/lib/features/learning/application/learning_controller.dart
- apps/mobile/lib/features/learning/presentation/lesson_screen.dart
- apps/mobile/lib/features/learning/presentation/learning_visuals.dart
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

Fresh baseline before I1:466passed/5existing native loading failures; analyzer0.
Root recorded exact receipt in TEAM_STATE. Per latest QUALITY_GATES, shared
core/design tokens and router are lead-only; each new test increases required
full pass count. No removal/skip/weakening; no commit before QA delta/full gate.

## Mandatory owner rules, verbatim for each worker above

# QUALITY GATES — Phase A (owner order 2026-10-10: "fast AND correct, break NOTHING")

These gates are law for the lead and every worker. Speed comes from parallel workers, never from skipping a gate.

## 0. Never break what works
- Before any change, record baseline: `flutter analyze` result + full `flutter test` pass count (write it in TEAM_STATE.md "Baseline").
- No commit may lower the pass count, add an analyzer warning/error, or delete/skip/weaken an existing test or golden to make it pass.
- Never delete a screen, route, widget, provider or feature that exists. Refactors only when a test proves behaviour is kept.
- Never touch services/, appwrite/, packages/api_contracts/, CI secrets, pubspec dependency versions (adding a dep needs a written reason in TEAM_STATE.md and must be pure-Dart/Flutter, no native setup).
- Router/main.dart and shared design tokens: lead only. Workers stay inside their EXCLUSIVE_CHANGE_AREA; a worker needing a file outside it asks the lead.
- No `git push`, `reset --hard`, `rebase`, force, `clean -fd`, branch deletion. Commit locally only.

## 1. Per slice loop (each worker)
1. Read the Gummble reference(s) via gummble MCP; write the exact spec (sizes, colors as tokens, spacing, radius, shadow/3D offset, copy, states, motion timings/curves) in specs/<slice>.md. Unknown = mark UNKNOWN + web research Duolingo with URL; never invent.
2. Write failing widget test(s) first: layout/state/interaction (tap, disabled, correct, wrong, retry, empty, loading, error, reduced-motion).
3. Implement with existing design tokens/components; no hard-coded hex/magic numbers if a token exists.
4. Motion: use the documented durations/curves; every animation respects reduced motion (MediaQuery.disableAnimations) and has a test that pumps through it without exceptions; no jank: no rebuilding whole screens per frame, dispose controllers.
5. Goldens 360 and 430 width × text scale 1.0 and 2.0 (light theme) in test/goldens/ui_master/. Check text overflow, clipping, RTL-safe paddings, tap targets ≥ 48dp, semantics labels.
6. `flutter analyze` (0 issues) + targeted tests + goldens green.

## 2. Lead review gate (before every commit)
- Read the full diff. Reject: invented UI, TODO stubs on user paths, dead buttons, print/debug code, unrelated edits, copied Duolingo binary assets.
- Run FULL `flutter test` (not only targeted). Pass count ≥ baseline + new tests.
- QA agent compares each new golden with its Gummble screenshot side by side and lists deltas in docs/design/qa/UI_MASTER_LOG.md; any visible delta in layout/color/spacing/copy = fix before commit.
- Commit message: `UI: <slice> — <task id> — Gummble <id>`; update docs/agent/task-status.json + plan docs per TASK_PROTOCOL; update TEAM_STATE.md.

## 3. End-to-end flow gate (A→Z, mock data)
Integration/widget flow tests that run the real router with mock repositories:
onboarding → placement/path → lesson (every exercise type, correct + wrong + hearts loss) → completion/celebration → back to path with progress → Practice, Stories, League, Quests, Profile/Friends, Shop/Super → settings. Every button on these screens must navigate or act; no crash, no red screen, no overflow warnings in logs.

## 4. Done definition
All scope task IDs closed by their repo acceptance text; analyze 0 issues; full suite green; goldens committed; flow tests green; UI_MASTER_LOG lists remaining known deltas (must be empty or explicitly accepted by the owner). Never write "pixel-perfect"/"production-ready" without this evidence.

## 5. If stuck
Same failure twice → stop that slice, write the exact error + what was tried in TEAM_STATE.md "Blocked", move to the next slice. Never "fix" by deleting tests.

## W2 lesson — PM I2 resumed

Execute [I2 exact brief](I2_WORKER_BRIEF.md), which includes current owner rules
verbatim including G-COLOR and G-DATA. I1 committed d438218; I2 is released by
latest continuation. Preserve all older WIP and whole-ticket gates.
