# Phase A team state

Updated 2026-10-09. Lead: root. Baseline: `28702b4`.
Owner decision dated 2026-10-10 accepts B01–B07 for mock UI work only.
No backend/contracts/Appwrite/dependency changes, push, or production actions.

## Ownership and sequence

Repo AGENTS.md and TASK_PROTOCOL cap native forks at one child. Run one isolated
worker alongside root review/research/QA; rotate workers rather than violating
the cap. Root exclusively owns main.dart, claims, plans, this file and commits.

1. W1 design: P2-DES-001 scoped tactile button audit/fix. Allowed implementation:
   core/design/reference_widgets.dart and lesson_motion.dart. Tests and goldens
   have their own exact paths in the worker brief below. Status: CLAIMED.
2. W2 lesson: P2-FE-001; execute PM briefs 11-exercises-I1, 12-exercises-I2,
   13-exercises-I3, then 14-exercises-Q (the fourth brief is QA, not I4).
   Do not guess a missing I4. Status: QUEUED behind shared tokens.
3. QA: P2-QA-001/UI-QA-014, compare worker goldens with live source images,
   record deltas, retain capability limits. Status: QUEUED after each slice.
4. W3 tabs: P2-FE-002 gap audit then bounded slices; completed families reused.
5. W4 extended: UI-EXTENDED-009 remaining evidence gaps in canonical plan order.
6. Final full analyzer/tests/goldens and required repository gates.

## Current evidence and blockers

- Gummble MCP available; live detail fetched for image-choice screen
  `sc_b7f6add9477e4c57ba0ed0bc101a37d9` (archived iOS, 1179×2556).
- Browser tools absent from the active tool catalog. UI-BROWSER-026 stays open.
- Prior full gate reports five Rive native loading failures: aarch64 host,
  x86-64 librive_native.so. Investigate without dropping/disabling tests.
- Full P1/P2/P3 production gates remain pending; Phase A UI authorization is
  separate. All requested scope IDs remain open until their actual acceptance.
- Pre-existing untracked repo `specs/` is preserved, not staged automatically.

## W1 brief

Task IDs: P2-DES-001, UI-FIDELITY-001; scoped SC17 CHECK/shared tactile controls.
Exact allowed files: apps/mobile/lib/core/design/reference_widgets.dart,
apps/mobile/lib/core/design/lesson_motion.dart,
apps/mobile/test/reference_button_test.dart,
apps/mobile/test/design_ui_master_golden_test.dart,
apps/mobile/test/goldens/ui_master/design_button_*.png.
No other files. Return evidence to root; do not edit shared logs/state or commit.

Gummble: fetch details before edits for
sc_b7f6add9477e4c57ba0ed0bc101a37d9 (selected CHECK) and
sc_ceb894f17ed14dd08762802759a22ced (disabled bottom action).
Reuse the already recorded research and bundled assets. If motion is unclear,
research official Duolingo motion and cite URL; stills do not establish timing.

Acceptance quoted from IMPLEMENTATION_PLAN: “preserve tokens/components/motion;
close semantics, CHECKdisabled/reducedmotion/text2 and golden gaps”.
Acceptance quoted from COMPONENT_STATES: “All components support default,
pressed, focused and disabled when actionable”; “CHECK disabled for invalid
shape or busy”; “No shared widget performs HTTP directly.”

Read required skills and nearest AGENTS. Write/run a meaningful failing test
first for any discovered defect (especially enabled→disabled during a held
press, cancellation, focus, no duplicate action). Fix minimally within existing
ReferenceButton geometry. Centralize the PM I1 tokens in LessonMotionTokens:
pressDuration100ms, matchFlash150ms, matchSettle200ms, mismatchShake300ms.
Use pressed 4px tactile depression; reduced motion immediate; text2 readable.
No broad redesign or invented artwork.

Run `. /workspace/tools/env.sh`; analyze --no-pub --fatal-infos and targeted
reference_button tests. Tests use env -u http_proxy -u https_proxy -u HTTP_PROXY
-u HTTPS_PROXY -u ALL_PROXY -u all_proxy NO_PROXY=127.0.0.1,localhost
no_proxy=127.0.0.1,localhost. Add UI master goldens for ready/pressed/disabled
and 360×800/430×932 at text1/text2, light/dark where supported. Open captures
and list source differences. Use --no-pub to avoid incidental lock changes.

Root reviews diff, repeats targeted checks and commits:
`UI: tactile controls — P2-DES-001 — Gummble sc_b7f6add9`.

## Resume

Read this file first; inspect git status and live agents. Recover unfinished
worker changes and tests before respawning. Update statuses/evidence after each
slice, commit early. Never report TICKET DONE while scope/gates remain open.

## UI sprint 2026-10-11 — baseline and claim

Root claims lesson-complete first on `int/phaseA`: learning summary domain/data/
provider/presentation, focused summary/completion tests and their goldens only.
Other screen families remain queued in the owner's requested order.
Gummble tools are unavailable in this session; saved manifests/screens are the
reference fallback. No source motion timing is inferred from a still image.

Baseline attempts before implementation: `flutter analyze --no-pub` terminated
with analysis-server exit -9; full `flutter test --no-pub --reporter expanded`
failed before any passing case with "The Dart compiler exited unexpectedly".
The stalled runner was stopped. Logs: `/workspace/tools/ui-sprint-baseline-analyze.log`
and `/workspace/tools/ui-sprint-baseline-tests.log`. Serial retries are pending;
no baseline pass count or clean analyzer result is established by these attempts.

This branch was missing the G-COLOR palette/checker. Restored byte-identical
copies from the shared `../../repo` checkout. `python3 tools/palette_check.py`
reports 74 pre-existing unmatched colors. No existing color was edited to hide
this baseline. Source-derived colors for each changed screen must be checked.

Continuation evidence: completion repository overrides, reference-copy/art
geometry, Wed→Tue streak/calendar, native metric graphics, text2 scrolling and
receipt/motion/lifecycle tests have passed29focused cases (including the shared
button's existing behavior). The 360dp minimum target was subsequently fixed
to48dp and included in every new golden assertion. Final type leading is being
matched to the measured source ink rows. Only completion/streak goldens changed.

`flutter analyze --no-pub --fatal-infos` was clean in
`/workspace/tools/ui-sprint-completion-verified-analyze.log` (95s), before the
last small alignment/minimum-height corrections. Repeat required for final code.
The palette report remains byte-identical to the74-color branch baseline after
new source-sampled feature colors; shared tokens have not changed.

Blocked full gate: initial canonical candidate reached358pass/8fail before
compiler loss; isolated c666beb baseline reached13pass then lost its compiler.
No completed baseline/candidate comparison yet. Two host OOM kills are recorded
in the shared execution cgroup. Flutter commands are now serialized. Known
observed failures:5Rive native loading failures (host aarch64, installed library
x86-64),2quest text2 overflows and1quest monthly-copy mismatch. Attribution
awaits completed baseline. Native build tools were installed outside the repo;
the pinned rive_native0.1.11 sources are compiling for ARM in
`/workspace/tools/rive-arm64-build`, no dependency/lock/test relaxation.

Status VERIFYING, not DONE. Ref|ours PNGs are at shared tickets/par/compare/
lesson-complete.png and lesson-streak.png. completion_qa has reviewed twice;
final narrow-target/gradient/alignment review and full-suite checks are pending.
No per-screen commit or DONE_SCREENS line yet. Next queued slice: top bar/nav.

Runtime continuation note: the execution environment restarted on subsequent
continuations: process IDs/execution cgroup changed and installed host build
tools disappeared, while worktree files and cached native objects survived.
The serial baseline was interrupted at71pass/5fail, not a completed full gate.
Build tooling is restored and the same pinned native build resumes from its
objects. Do not use orphaned session IDs or treat a partial log as full success.

Latest ticket40 owner rule (2026-10-11 03:04), SPEED FIRST, replaces the
earlier per-screen full-suite/pixel-delta loop: implement + motion, clean
analyzer, targeted tests, comparison, individual commit, DONE line, next screen.
Small visual differences are allowed. Full-suite/whole-sprint status is separate.
Final saved comparisons were opened by root and completion_qa: no obvious
copy/value/color/element/layout blockers; small glyph rasterization/numeral shape
and about1–2px alignments remain. Source OS indicators are outside app content.
Current golden run passed29cases in20s:
`/workspace/tools/ui-sprint-completion-current-goldens.log`. Final no-update
verification is running. The final analyzer attempt was terminated143 with no
result; earlier95s clean analysis is not presented as this final attempt.
The baseline shard0 was stopped after stalled compilation at2passes; no full
baseline count is claimed. Owned orphan Flutter runners were terminated. The
pinned ARM Rive build needed host libgl-dev at link time; no app dependencies
or test expectations changed.

Final per-screen receipt: no-update targeted run29/29pass (16s),
`/workspace/tools/ui-sprint-completion-current-targeted.log`; final analyzer
0issues (117.6s), `/workspace/tools/ui-sprint-completion-current-analyze-retry.log`.
Palette output is byte-identical to the74legacy-mismatch baseline; every new
feature token is sourced. QA accepts the small differences described above
under ticket40 SPEED FIRST. Scoped completion flow is DONE; full suite, entire
sprint and production/device gates remain open. ARM native library now links
and identifies as aarch64; runtime compatibility has not yet been tested.

Next claim UI-SPRINT-I-SHELL, after completion commit34c66b9. Shell feature
domain/data/providers/presentation, learning_path top row, learning_shell nav
and focused shell/path tests only. Existing five router branches stay frozen.
Current baseline: analyzer0issues (117.6s),29completion-focused passes; full
suite baseline remains unresolved. No other feature golden will be updated.
