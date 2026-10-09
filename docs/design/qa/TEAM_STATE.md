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
