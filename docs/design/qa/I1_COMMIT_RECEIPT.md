# I1 local commit receipt — 20-team-phaseA

2026-10-10. Scope: P2-FE-001 / SC17 imageChoice and matchPairs; whole ticket
remains IN_PROGRESS. The latest user instruction explicitly authorizes a local
I1 commit after fatal-info analysis, targeted tests and zero NEW palette colors;
it supersedes the earlier requirement to hold this commit for whole-suite,
global-palette and visual closure. It does not close those gates or authorize
protected feature edits, deployment or publishing.

## Reviewed change

Image choices use stable IDs, explicit new-word metadata, source card proportions
(664/510), source gutters (64/3dp), complete girl/woman crops and state-specific
existing woman art. Matching accepts either selection order, shuffles columns
independently and deterministically, locks input during finite decoration,
rejects duplicate/unknown IDs, and ignores stale completion events. Reduced
motion resolves immediately; pause retains selected/matched pairs. Grading,
receipt rewards and all other exercise renderers retain existing ownership.

Shared support is limited to I1 motion constants, an optional progress-track
color and opt-in button palettes. Legacy defaults and existing shared button
interaction/semantics are preserved. Pending shared tactile/semantics work and
its tests/goldens stay outside this commit; original source is preserved at
/workspace/tools/coc-i1-reference-widgets-wip.dart and restored after committing.

## Commands and evidence

From apps/mobile, source /workspace/tools/env.sh on a separate line. Flutter
tests run with HTTP_PROXY, HTTPS_PROXY, ALL_PROXY and lowercase variants unset.

- `flutter analyze --no-pub --fatal-infos`: PASS, zero issues (11.1s),
  /workspace/tools/coc-i1-commit-scoped-analyze.log.
- `flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false --reporter expanded test/features/learning/exercises_i1_test.dart test/exercises_i1_ui_master_golden_test.dart test/lesson_ui_master_golden_test.dart`:
  PASS 45/45, /workspace/tools/coc-i1-commit-targeted-green.log.
- The same command with test/learning_controller_test.dart,
  test/learning_flow_test.dart, test/lesson_fidelity_test.dart and
  test/lesson_summary_test.dart added: PASS 71/71,
  /workspace/tools/coc-i1-commit-green.log.
- Golden generation with `--update-goldens` on the two golden harnesses:
  PASS 28/28; subsequent comparison above PASS without updating. Committed
  images: 16 ex_image/ex_match fixtures at390x844 and360/430 x text1/text2,
  plus12 existing core_lesson_image/core_feedback fixtures changed by I1.
- `dart format --output=none --set-exit-if-changed` on the13 scoped Dart files:
  PASS, zero changed files. `git diff --check`: PASS.
- `python3 tool/palette_check.py`: exit1,68 legacy unmatched colors. Running the
  identical checker and palette against HEAD4db8cc1 lib via a temporary
  `git archive` baseline also reports68; set difference is empty: **0 NEW**.
  Logs: /workspace/tools/coc-i1-commit-palette.log and
  /workspace/tools/coc-i1-commit-palette-baseline.log. No checker changes,
  fabricated admission or unrelated palette rewrite.

Meaningful pre-implementation RED receipts remain
/workspace/tools/coc-phase-a-i1-red.log,
/workspace/tools/coc-phase-a-i1-correct-red.log,
/workspace/tools/coc-phase-a-i1-match-palette-red.log and
/workspace/tools/coc-phase-a-i1-match-controls-red.log. All assertions retained.

## Source review and remaining gaps

References and coordinates are recorded in [I1 spec](../../../specs/exercises-i1.md)
and [prior independent review](exercises_i1.qa.md). Current renders were opened
in /workspace/tools/coc-i1-commit-contact-sheet.png and compared with original
selected-image sc_b7f6add9 and text-match sc_5b3164cb PNGs. Modern images use
#FFFFFF/#E5E5E5, selected #DDF4FF/#84D7FF/#1CB0F6 and correct
#D6FFB8/#A5ED6E/#58A700. Text pairs retain their own #FEFCFE/#E7E5E7,
flash #DBFFBB/#A9EE73/#61A513 and disabled #B3B0B3 roles. No PNG artwork is
recolored or replaced. Original sampled old-match reference is included.

The wrong-boy white rectangle remains visible and no wrong-image source is
established. Wrong/selected pair and settled-disabled states are authored
adaptations, not source-certified captures. Enabled text-match action source is
UNKNOWN. Fixtures retain authored English content/order/heart counts and
CHECK/HINT behavior. Larger cards can extend below the initial viewport; text2
remains scroll-reachable and labels/actions readable. Source stills do not
certify100/150/200/300ms timings or text2. Exact full-screen fidelity is open.

An extra check of pending design tests reproduced the existing adjacent
“Share learner” semantics failure (25pass/1fail including17 I1 behavior tests);
that unfinished design slice was isolated before the scoped GREEN run. No
assertion was removed, weakened or skipped. Full-suite/native/browser/device,
whole global-palette and production gates remain open. League/quests/shop/
profile, build/ and pubspec.lock are excluded. I2/I3/Q and other ticket scope
remain unfinished; no TICKET DONE claim.
