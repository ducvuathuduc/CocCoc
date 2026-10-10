# Phase A team state

Updated 2026-10-09. Lead: root. Baseline: `28702b4`.
Owner decision dated 2026-10-10 accepts B01–B07 for mock UI work only.
No backend/contracts/Appwrite/dependency changes, push, or production actions.

## Ownership and sequence

Repo AGENTS.md and TASK_PROTOCOL cap native forks at one child. Run one isolated
worker alongside root review/research/QA; rotate workers rather than violating
the cap. Root exclusively owns main.dart, shared design tokens, claims, plans, this file and commits.

1. W1 design: P2-DES-001 scoped tactile button audit/fix. Allowed implementation:
   core/design/reference_widgets.dart and lesson_motion.dart. Tests and goldens
   have their own exact paths in the worker brief below. Status: VERIFYING; code not committed pending full-suite and QA gates.
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

## Baseline and new quality gates (latest owner steering)

Read `/workspace/projects/25b10038-9b3c-4e9b-bbe5-2053de7f453d/tickets/QUALITY_GATES.md`.
Historical baseline at28702b4: analyzer0issues; full gate454pass/5native failures
per UI_MASTER_LOG (fresh baseline still required; do not present as a fresh run).
Current W1 change:4meaningful RED regressions,17worker checks pass; root
repeat analyzer0issues,19tests pass including path cancellation/reduced motion.
12new360/430×text1/2light component goldens; worker opened all12, root opened
ready360/text1 anddisabled430/text2. QA-agent side-by-side report and FULL
suite with count≥fresh baseline+new tests required BEFORE feature commit.
No feature commit made yet. Existing tests/features remain intact.

## Blocked / host investigation

Official Rive docs https://rive.app/docs/runtimes/flutter/rive-native confirm
Linux prebuilt libraries omit arm64; manual source build is required.
Installed host compiler prerequisites outside repo (no app dependency changes).
`dart run rive_native:setup --verbose --clean --build --platform linux` failed
at Premake Git checkout with HTTP409 (exit128). Same tagged Premake codeload
archive succeeded and compiled at /workspace/tools/rive-arm64-build/
premake-core-5.0.0-beta7; source build still requires other dependencies.
The setup command incidentally rewrote pubspec.lock; restored exact HEAD bytes
with git show (no reset). Restore prebuilt runtime via official setup before
recording the expected native-failure baseline, or complete the arm64 build.
Concurrent tests stalled in initial compilation; root stopped its runner;
serialized W1 tests then produced actual RED/GREEN. Raw native hook logs may
embed proxy credentials; only persist sanitized error summaries.

Required read-only gates this continuation: backend:verify, backend:smoke,
contracts:check, api:lint, audit:check PASS (logs in /tmp/coc-phase-a-*.log).
No full-suite or browser success claimed. Next: QA worker then lesson I1
under PHASE_A_WORKER_BRIEFS.md, root owns native-runtime/full baseline work.

Fresh baseline is running in `/workspace/tools/coc-phase-a-baseline/apps/mobile`,
a source archive of commit4db8cc1 (same app code as28702b4), with copied package
config and official restored runtime. Logs `/tmp/coc-phase-a-baseline-analyze.log`
and `/tmp/coc-phase-a-baseline-full.log`; session ID recorded in tool history.
The attempted separate project worktree checkout was interrupted(exit143) by
process teardown and no longer exists; archive avoids copying unrelated QA art.
QA rotation: existing w1_design child now owns docs/design/qa/design_controls.qa.md
only. No feature commit until full-count and source-delta gate.

## Blocked update — QUALITY_GATES same-failure rule

Native source build hit GitHTTP409 a second time, now at
rive-app/premake-export-compile-commands (branch more_cpp_support).
Stopped native build slice per gate5; no repeated attempts and no tests skipped.
Exact isolated build log `/tmp/coc-phase-a-rive-isolated-build.log`.
Official prebuilt runtime restored before baseline;5native failures observed
so far. Isolated source copy `/workspace/tools/rive-arm64-build/package`,
11exact tagged dependency archives fetched, arm64 Premake compiled. A future
admitted build can use codeload for that exact build extension; do not claim
current runtime succeeds. No app dependency/version changes.

QA report `docs/design/qa/design_controls.qa.md` compares all12component
goldens to source and holds commit: palette, bottom spacing, glyph widths,
pressed overlay and48dp effective touch target need correction/acceptance.
Child rotated to W2 I1 read-only prep until full baseline count recorded.
Identified exact path correction: learning_visuals.dart owns LearningCard/colors;
learning_widgets.dart does not exist. Fixture is data/learning_repository.dart.
Expand W2 allowlist explicitly before implementation; core tokens stay lead-only.

## Fresh baseline receipt — before next changes

App code at4db8cc1/28702b4, isolated source archive, proxy-free command:
`flutter analyze --no-pub --fatal-infos`:0issues (30.9s).
`flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false --reporter expanded`:
466passed/5failed in3m40s. Exact failures: avatar_motion_test3,
character_motion_test2, all native Rive loading. Logs in /tmp/coc-phase-a-baseline-*.log.
Fresh full suite total471. No tests dropped/weakened/skipped. This supersedes
historical454pass count as the current non-regression floor. W1 adds16tests,
so current full candidate must pass≥482 with no additional failure. DONE still
requires full suite green. Every later added test raises the floor accordingly.

Root authorizes W2 I1 implementation after this receipt. Exact allowlist
correction: replace nonexistent learning_widgets.dart with learning_visuals.dart;
add data/learning_repository.dart ONLY for authored isNewWord fixture metadata.
All other W2 paths unchanged; shared core/router/locks remain lead-only.

## Latest active work

Root control repair: new boundary test REDcalls0expected1 on lower4dpedge.
Opaque wrapper pointer handling now invokes once; native child still owns
semantics. Calibrated surface/green/border/disabled token values to measured
source; removed unsupported pressed overlay; tracking1.3matches label widths
within2dp; fixture safe/content padding nowtargets50dp sourcegap.18control
tests/goldens PASS. Root analyzer observed1info in pending I1golden harness;
worker fixed it before its RED. Finalanalyze0stillrequired afterworker finishes.
Core shared diff/not committed; legacy goldens may need deliberate source-
reviewed updates, not blind regeneration. QA recheck all12stillpending.

W2 I1: resumed samechildafterpending_init interruption;4actualREDcases
0pass/4fail at /tmp/coc-i1-red.log. TypedVM/image/match implementation active
within correctedallowlist;16newgolden fixtures authored. No existing test or
feature removed. PM/source color-state conflicts listed in external
specs/exercises-i1.md; resolve/recordunderstrictQA gate beforecommit.
Minimumexpectedcandidate pass count now483plus all new I1tests (20currently).
Root is not running Flutter while worker runs targetedchecks.

## Baseline and resumed team — 2026-10-09 20:55 UTC

Recorded baseline remains analyzer 0 issues; 466 passes / 5 native Rive failures
at app-code baseline 4db8cc1. Expected candidate floor is 503 passes with the
current 17 design and 20 I1 additions; additional tests raise that floor.
Prior /tmp logs were lost on container resume. New gate logs go under
/workspace/tools/coc-phase-a-*.log and exact outcomes are recorded here.

Active child: /root/w2_i1, exclusive I1 allowlist in PHASE_A_WORKER_BRIEFS.md.
Recovered typed VM changes, tests and harness; reruns the four RED acceptance
cases before renderer edits. Lead refreshed all five I1 references via MCP.
Lead owns shared control diff, docs, review, required gates and commits.
No native build retry: the repeated Git HTTP409 slice remains stopped under
QUALITY_GATES section 5. No feature commit until visual and full-suite gates.
Next: I1 targeted GREEN → independent design QA/full candidate gate → independent
I1 QA → verified slice commits → PM I2. Remaining scope tasks stay open.

Environment note: env.sh currently returns exit 1 after setting tool paths.
Source it as its own shell line, then execute commands; `source && command`
does not execute the command. No app environment or dependency file changed.

Lead full gate now runs in the existing isolated source archive with ONLY the
three shared design files, two design test files and twelve design goldens
copied over the baseline. I1 mutable code is excluded. Design-only expected
floor is 483 passes plus the five unchanged native failures; any new failure
holds the commit. Commands: proxy-free flutter test --no-pub
--dart-define=ENABLE_MASCOT_MOTION=false --reporter expanded; flutter analyze
--no-pub --fatal-infos. Persistent logs: coc-phase-a-design-{full,analyze}.log.
The candidate archive is now changed; reconstruct a fresh baseline from 4db8cc1
if another clean baseline is needed. Do not call this candidate a baseline.

W2 freshly reproduced four real I1 RED assertions: 0 pass / 4 fail. Persistent
receipt: /workspace/tools/coc-phase-a-i1-red.log. Renderer integration underway.
Next independent design QA brief is DESIGN_QA_WORKER_BRIEF.md (contains exact
owner quality rules); read-only QA may run alongside the lead's full gate.

## Resumption verification update — 2026-10-09 21:01 UTC

W2 now adds 11 behavior tests + 16 golden fixtures (27); whole candidate floor
rises to 510 passes. Four RED cases freshly reproduced; renderer integration
is complete. Worker analyzer was killed with code -9 while two isolated lead
Flutter runners were active; it emitted two brace-style infos, now being fixed.
Lead stopped its own isolated full/analyze processes and serializes all Flutter
verification. Root design-only analyzer subsequently completed: 0 issues, 60.6s. The full suite was stopped for serialization; no full-suite receipt exists.
Lead/worker may use independent read-only non-Flutter work concurrently.

Blocked tooling: worker analyzer was killed with -9 under concurrent resource pressure. Root full suite was deliberately stopped after 73 passes / 7 failures; existing golden deltas require review. Exact logs /workspace/tools/coc-phase-a-design-full.log and -design-analyze.log. Existing native source-build HTTP409 remains stopped.
Next: worker targeted GREEN, then goldens generation/comparison, then lead
serial analyzer/full-suite, independent design QA per DESIGN_QA_WORKER_BRIEF.md
and new independent I1 QA. No feature commit or task closure is authorized
from these interrupted receipts. Preserve every pending source/test/golden.

## Latest teardown handoff

Required read-only gates all PASS: backend verify (16 tests), smoke, contracts
(94 schemas/30 cases), API lint and audit (858 local links). Worker stopped its
own pending analyzer to prioritize behavior tests. Targeted session 85279
logs to /workspace/tools/coc-phase-a-i1-green.log; result pending. Goldens are
authored but not generated; mobile analyzer has not passed after I1 changes.
Root design-only analyzer passed; legacy completion golden differences remain.
No feature commit. WIP archive under /workspace/tools/coc-phase-a-wip/ preserves
tracked.patch and untracked artifacts. Resume TEAM_STATE first; one child only,
serial Flutter runners. Reuse receipts and unfinished code; do not repeat RED
when its persistent receipt is still available.

## Owner steering and active recovery — 2026-10-09 21:03 UTC

Latest owner: do not touch features league/quests/shop/profile. Root and child
allowlists exclude these areas. Active child /root/w2_i1_resume continues the
existing I1 allowlist. Last targeted result9pass/2fail: both new text2 tests
leaked SemanticsHandles at framework end checks; assertions did not report
product overflow. Fix cleanup via try/finally, preserve all assertions, rerun
alone. Initial4RED receipt remains valid. Independent QA/full gate still hold
feature commit. No native build retry or protected feature change.

W2 resumed behavior receipt:11/11 PASS after try/finally SemanticsHandle cleanup;
no assertion removed. Log /workspace/tools/coc-phase-a-i1-green-resume.log.
Sixteen goldens generating/comparing serially, then analyzer. Independent
I1/design QA brief prepared at I1_QA_WORKER_BRIEF.md (exact rules verbatim).

## Owner resumption — 2026-10-10

Claim: root owns I1 palette isolation, golden regression resolution and local
commit before I2/I3. Protected league/quests/shop/profile feature files,
build/ and pubspec.lock are excluded. One independent read-only QA child
compares the six freshly fetched Gummble I1 references. Flutter checks are
serialized. Fresh candidate analyzer: 0 issues, 17.6s; full baseline running
in /workspace/tools/coc-phase-a-resume-baseline-full.log. Earlier uncontaminated
baseline remains 466 passes / 5 host-native failures; do not claim full green.

MCP verifies white/#58CC02/#E5E5E5/#AFAFAF for current I1 controls, while
sc_5b3164cb's older matching capture retains #FEFCFE/#E7E5E7. Preserve legacy
shared defaults and apply the verified newer palette only to I1. Newly found
G-COLOR requires per-screen samples, coordinates and measured improvement
before golden updates. Its initial repository-wide checker fails with 70
unmatched colors, including unrelated protected features; no broad palette
rewrite or test weakening is authorized. Source-only I1 colors take precedence
over the older brief's approximate dark selected/correct/error roles.

## Active recovery — 2026-10-10 04:55 UTC

Lead recovered all pending files and respawned one independent QA worker,
`/root/phase_a_qa_resume`; exact writable paths are the two existing I1/design
QA reports. No descendants or concurrent Flutter runners. Protected
league/quests/shop/profile implementation and dependency locks remain intact.
WIP saved before further work at
`/workspace/tools/coc-phase-a-wip/2026-10-10-resume/` (binary tracked patch,
NUL-delimited untracked inventory and full untracked archive).

Baseline remains the uncontaminated 466 passes / 5 native failures at 4db8cc1;
the previous resume-baseline log is actually a mutable candidate and cannot
supersede that baseline. Fresh full candidate runs serially in the real app:
proxy-free `flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false
--reporter expanded`, log `/workspace/tools/coc-phase-a-current-full.log`.
No source mutations during that run. Required candidate floor remains 510.

Gummble MCP freshly resolves all six I1 references. Direct PIL getpixel on
catalog-cache confirms selected surface(5,1278)=#FFFFFF,
action(100,2310)=#58CC02, edge(580,2400)=#58A700,
selected fill(541,1252)=#DDF4FF, border(49,1158)=#84D7FF,
label(403,1398)=#1CB0F6; correct fill(66,1255)=#D6FFB8,
border(46,1109)=#A5ED6E, label(186,1399)=#58A700;
match disabled fill(129,2340)=#E5E5E5, text(578,2339)=#AFAFAF.
These values already exist in per_screen and the pending scoped I1 tokens.
Current I1 goldens predate those token/art corrections; QA must review actual
failure captures before any regeneration. Twelve control goldens still match
their source-role samples. Global defaults remain legacy, avoiding unreviewed
completion/other-feature golden updates.

Blocked G-COLOR: `python3 tool/palette_check.py` exits 1, with 68 unmatched
repository colors, predominantly legacy/unrelated and including protected
features. No checker weakening, fabricated palette entries, protected feature
rewrite or feature commit. Native source-build repeated HTTP409 remains stopped
under gate 5. Save artifacts while commits remain held by visual/full/palette
gates. I2/I3/Q and whole-ticket acceptance remain open.

Full recovered candidate completed all discovered tests in 3m58s:
469 passes /37 failures, terminal `Some tests failed`; runner receipt exits143
after that terminal summary. Breakdown:5 known native failures,16 stale new
I1 goldens,12 changed legacy I1/feedback goldens,3 shared-control semantics
regressions on existing profile route tests,1 I1 harness compilation failure
(`referenceTheme` missing import). Tests/fixtures/assertions are preserved.
Correction to prior floor: reference_button_test now has7 cases vs1 baseline,
so design adds18 (6behavior+12goldens), I1 adds27; expected floor is511 passes,
516total including the five unchanged native failures. The compilation error
replaced11 behavior cases with1 failed file-load, explaining506 executed.

Root added only the missing reference_theme import after the full run;
no behavior assertion or source color changed. Serial analyzer now runs at
`/workspace/tools/coc-phase-a-current-analyze.log`.
Independent QA rechecked16 actual renders plus12controls and saved both QA
reports. Actual selected/correct woman artwork is corrected; incorrect-boy
white rectangle, prompt ink, geometry/copy and unsupported matching state
mapping remain OPEN. Modern matching fill is farther from old matching source
(mean absolute channel delta2.333→2.667); no matching golden regeneration.
Worker rotated to read-only I2 preflight at external specs/exercises-i2-preflight.md;
four I2 references freshly resolved via MCP. No I2 implementation past held gate.

Fresh required backend:verify PASS(16tests), backend:smoke PASS,
contracts:check PASS(94schemas/30fixtures), api:lint PASS and audit:check
PASS(863local links). Logs use `/workspace/tools/coc-phase-a-resume-*.log`.
Protected feature files and pubspec.lock show no diff. Commit still held.

## Latest handoff — 2026-10-10 05:01 UTC

Missing test-theme import fixed, then fatal-info analyzer PASS:0issues in60.0s.
Added a caller-provided semantic-label toggle harness without touching protected
feature code. Its initial run failed only on SemanticsHandle cleanup (not a
product assertion); removed the unnecessary explicit handle, retaining every
assertion and the default widget-test semantics setup. Root has NOT changed
button implementation to guess at the three existing routed label failures.
This minimal caller-label harness passes; routed failures still need isolation.

Proxy-free `flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false
test/reference_button_test.dart test/features/learning/exercises_i1_test.dart
--reporter expanded`:20/20PASS (8control,12I1). Format exact2testfiles:
`dart format --output=none --set-exit-if-changed`:0changed/PASS.
Logs: `/workspace/tools/coc-phase-a-behavior-current.log` and
`coc-phase-a-current-format.log`. Newly recovered palette-isolation I1 case
was missing from earlier count: actual I1behavior12+goldens16=28additions.
With the new caller harness, design7newbehavior+12goldens=19additions.
Correct FINAL expected full pass floor513 (466+19+28),518total with native5.
The earlier full candidate before this new harness would discover517cases
after fixing compilation;12missing behaviorcases were replaced by1file error.
Final analyzer after the additional test runs serially at
`/workspace/tools/coc-phase-a-final-analyze.log` (result pending).

QA worker finished both reports, then saved read-only I2 preflight to external
`specs/exercises-i2-preflight.md` (205lines). No worker remains unfinished;
respawn a single isolated implementation/QA worker on next continuation only
after checking held dependencies. I2's apparent idle source is assembled,
all4per_screen palettes need real admission, audio/rate hook absent, dictation
must preserve text grading and no-token keyboard fallback. No I2code written.

Next: isolate existing three routed semantic-label failures without changing
protected features; fix source-supported I1 prompt/art/layout; admit the actual
older matching palette with pixel coordinates before correcting match goldens.
G-COLOR68legacy colors and native repeatedHTTP409 remain blocked slices under
gate5. Do not retry full/native setup without a material admitted correction.
`pnpm verify` remains pending because it invokes blocked native setup/full tests;
do not present standalone analyzer/targeted/backend gates as that receipt.
No commit while full/visual/palette gates hold; all pending artifacts preserved.

Final analyzer receipt: `flutter analyze --no-pub --fatal-infos` PASS,
0issues/5.4s after the added caller harness; log
`/workspace/tools/coc-phase-a-final-analyze.log`. `git diff --check` PASS.
No diff in protected feature files, backend/contracts or pubspec.lock.
WIP archive refreshed with all latest tracked/untracked artifacts before ending.


## Resume checkpoint — 2026-10-10 05:09 UTC

Baseline: retained466passes/5native failures at4db8cc1; analyzer0. No clean
baseline overwritten. Root recovered all pending files and saved tracked patch
and172untracked artifacts at /workspace/tools/coc-phase-a-wip. No feature commit
while strict full/QA/G-COLOR gates are open. Protected features untouched.
One child /root/w2_i1_correct owns six exact I1 paths in
I1_RESUME_WORKER_BRIEF.md (includes owner rules verbatim).3new source geometry/
prompt/art REDtests authored; runner now granted. No golden regeneration yet.

Root button isolation:8controlPASS/2existing routed failures reproduced; an
extra nonexistent preview_route_test.dart argument produced1load failure (tool
invocation mistake, no product defect). Exact receipt
/workspace/tools/coc-phase-a-semantics-isolation.log. New adjacent controls test
RED: Share learner semantics missing,0pass/1fail. Restoring original shared
Semantics(button:true,enabled:enabled) fixes all3existing routed failures:
reference_button+profile_actions_route+foreign_profile_header now17pass/1fail.
Exact receipt /workspace/tools/coc-phase-a-semantics-restored-green.log.

Blocked: new adjacent Share learner label expectation failed twice; stop that
semantics slice perQUALITY_GATES5. Preserve new assertions/test and source;
no deletion/weakening. No further semantics/full retry before material correction.
Native repeatedHTTP409 and globalG-COLOR68legacy failures remain stopped.

Old text-match source freshly fetched via MCP and downloaded as QA reference
catalog-cache/sc_5b3164cb9c6448c1838c229517cebe1b.png. Own-role palette admission
records actualPILgetpixel coordinates/sourceURL/size/hash under sampling_evidence:
surface#FEFCFE(0,0);fill#DBFFBB(83,726);edge#A9EE73(84,720);
stroke#E7E5E7(644,723);ink#4D4B4E(946,800);
disabled#B3B0B3(524,2323);correctink#61A513(245,799).
No fabricated palette entry or protected-feature rewrite. New reference
admission cannot establish globalpalettePASS or close visual/state-source gaps.


## Source correction checkpoint — 2026-10-10 continuation

I1 worker reproduced four new meaningful source RED assertions: 0/3 for
prompt ink, image card ratio/gutter and clipped girl art; 0/1 for own-match
surface/flash palette. After implementation and one border-constraint correction,
16/16 behavior tests PASS. A fifth source RED independently proves own-match
track/disabled action (0/1). Added scoped ReferenceButtonPalette.textMatch uses
actual surface #FEFCFE, stroke #E7E5E7, disabled label #B3B0B3. Enabled action
has no own-match reference and retains the existing green with explicit UNKNOWN.
Worker maps it only to matching; image tokens and legacy defaults stay separate.
One nullable Exercise? action access compile failure was identified and corrected
by the worker; final 17 behavior GREEN/analyzer/capture receipts pending.
Current full pass floor is 519: baseline 466 + design 20 + I1 33; total 524
including the five known native failures. Do not infer full success from this.

Lead independently prepared I2 references: freshly resolved all four IDs via
MCP, downloaded/opened originals and sampled every preflight coordinate with
PIL getpixel. Five newly admitted reference PNGs (old text match + four I2)
include per-screen colors, URL, dimensions, SHA256 and role coordinates in
palette_from_refs.json. No I2 code/golden changes past the held dependency.
Post-admission `python3 tool/palette_check.py` still FAILS with 68 unmatched
legacy colors. Exact log: /workspace/tools/coc-phase-a-palette-admitted.log.
Global palette slice remains stopped under gate 5; no protected feature change,
checker weakening, fabricated entry or feature commit.


## I1 committed-slice gate — 2026-10-10

Root claims the I1 local commit under the latest user-authorized targeted gate.
Analyzer zero;45/45 I1/golden and71/71 lesson regression tests PASS; palette
68 baseline/68 current/0 NEW. Shared button staging contains palette support
only; pending design interactions/tests are preserved outside the commit.
[Exact commands, source review and limits](I1_COMMIT_RECEIPT.md). Whole ticket
20-team-phaseA and P2-FE-001 remain IN_PROGRESS; visual/full/native and I2/I3/Q
gates remain open. Protected features and dependency locks untouched.


I1 implementation committed d438218a214570589b89da86e2505cf51d3b8562.
Preserved shared design WIP restored. Backend16tests/smoke/contracts/API/audit
PASS; blueprint PASS after fixing external spec links. Full pnpm verify passed
format230files/analyzer0 then reproduced5known native/runtime failures; stopped
that broad run without claiming full success. Auto-refreshed pubspec.lock was
saved externally and restored to HEAD. Protected paths unchanged. Local docs
follow-up commits portable links and the post-commit receipt only. Whole ticket
and unfinished slices stay open; see I1_COMMIT_RECEIPT.md.


## I2 resumed claim — 2026-10-10

Latest user continuation releases I2 after committed I1 d438218. Repo cap one
child: w2_i2 owns exact paths in [I2_WORKER_BRIEF](I2_WORKER_BRIEF.md); root owns
shared tokens/docs/reference checks/review/commits. Worker has serialized Flutter
runner. Root review/research runs concurrently. Baseline retained466pass/5native,
analyzer0; current full floor519 plus any I2 additions, no new full receipt.
Existing design WIP, failed semantics assertions and68legacy palette mismatches
are preserved. No repeated blocked native/global repair or protected-tab edits.
References freshly fetched4/4via MCP. Next: I2 RED→implementation→targeted
GREEN/analyzer/palette differential→independent child QA→local verified commit.
Whole ticket remains IN_PROGRESS.


## I2 RED runner and token checkpoint

Claim/docs checkpoint committed c2e752c. Child w2_i2 authored four public
behavior tests in exercises_i2_test.dart before implementation. First invocation
failed before discovery: FileSystemException readInto generated .dart_tool/
hooks_runner/objective_c/0c894306e9/input.json, errno5. Root authorized only
reversible generated-cache repair; child moved unreadable original outside repo,
then retry reached compilation/test loading. Actual assertion RED is pending;
no I2 renderer code or golden exists yet. Root added uncommitted named PM250ms
wordFlight token and isolated exercise_tiles.dart colors/geometry.

Root fresh palette differential using git archive c2e752c:68baseline/68current/
0NEW, logs /workspace/tools/coc-i2-palette-{baseline,current}.log. Global checker
exit1 remains explicit. pnpm audit:check PASS:83JSON/4YAML/876links/13Mermaid.
Opened original listening/assembled-translation references and contact sheets
of bundled lesson/practice and blue-heavy artwork; no exact turtle art found.
Worker may verify functional slow dispatch with explicit art delta; exact source
fidelity remains open. No Flutter concurrency, native retry, lock or protected
feature edits. Worker RED log /workspace/tools/coc-i2-red.log.
