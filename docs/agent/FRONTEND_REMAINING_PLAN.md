# Remaining English frontend implementation plan

> For agentic workers: implement each claimed slice with a failing behavior test,
> source analysis, native widgets, targeted verification and visual review.

**Goal:** Continue missing language-learning UI and preserve per-flow/per-screen
completion evidence so completed work is not repeated.

**Architecture:** Existing feature-first Riverpod MVVM. Controllers own local
mock commands; native views reuse the reference design system. Root routing stays
with the parent agent. No backend, dependency or architecture change.

**Tech stack:** Current pinned Flutter/Dart/Riverpod/Rive/Lottie stack from
[frontend plan](FRONTEND_FLOW_PLAN.md).

**Spec:** Ordered Gummble index and the existing flow analyses. English remains
the active learning course; Math/Music/Chess are outside implementation scope.

## Tasks

- [x] UI-TRACK-011: Create a persistent coverage ledger for all148 scoped flows
  and912 ordered screen occurrences. Record existing mock families with evidence,
  independently track source variants and motion gaps. Validate IDs/paths and
  never erase prior verified marks when regenerating the readable checklist.
- [x] UI-COURSE-012: Analyze live Gummble Removing a course5-step flow
  `02681cdc-5d55-4755-a529-9e6c7ecaf5c9`; implement native course management,
  cancel/confirm/removing/result states and original crying-Duo artwork. Preserve
  English learning state and protect the active English fixture. Parent owns
  `/settings/courses` routing and settings entry integration. Worker owns new
  course controller/view/tests, flow20 analysis and source asset preparation.
- [ ] UI-AVATAR-013: Inspect both12/15-step avatar variants and research original
  builder assets before claiming selectable avatar output. Record exact available
  categories and missing original rig/export; avoid fabricating proprietary motion.
- [ ] UI-QA-014: Test touched controllers/routes and360/430 widths at text1/2;
  capture source-sized states and compare originals. Run full mobile gate after
  integration; rebuild the local web preview and update coverage only from evidence.
- [x] UI-AUTH-015: Reuse remembered-account commands; replace the generic sheet
  with the source Manage accounts page and anchored Remove confirmation. Worker
  owns login presentation/tests/flow23; parent owns captures and coverage.
- [x] UI-PROFILE-016: Native profile report/block/unblock and QR/copy/share preview;
  real clipboard retry, readable local fonts, floating copied receipt and native
  modal return tests. Parent owns flow21 and profile presentation/controller.
- [x] UI-PASSWORD-017: Analyze all four Changing password source steps; add the
  three-field native screen and local mock old-password validation/update. Reuse
  the mock auth repository, preserve fields on errors and reject duplicate saves.
  Prepared Appwrite adapter stays disabled. Profile editor source variant remains
  separately tracked rather than claiming its full layout matches.

2026-10-05 evidence:278 tests pass in `english-continuation-gate.log`;
15 source-sized captures are reviewed. Coverage closes6 ordered native mock flows
and45 screen occurrences while retaining23 reusable families. Two password screen
states are verified; source profile-editor entry/result remain in progress.
UI-QA-014 awaits the final refreshed web/browser check. Avatar research remains
open; do not rebuild the completed families while resolving these gaps.

## Review focus

- Cancel/back retains enrollment and does not mutate learning XP, streak or path.
- Confirming twice/removing an already removed course is idempotent.
- English active-course protection has a visible reason and preserves input.
- Lower sheet controls scroll at text2 rather than clipping.
- Original illustration bounds and animation lifecycle are inspected separately
  from native text/controls; exact archived timing requires its own evidence.

Current user request continues implementation. The already published GitHub
snapshot remains historical; no automatic deployment or Release overwrite.
