# Remaining English frontend implementation plan

> For agentic workers: implement each claimed slice with a failing behavior test,
> source analysis, native widgets, targeted verification and visual review.

**Goal:** Continue missing language-learning UI and preserve per-flow/per-screen
completion evidence so completed work is not repeated.

**Architecture:** Existing feature-first Riverpod MVVM. Controllers own local
mock commands; native views reuse the reference design system. Root routing stays
with the parent agent. Flutter SVG is pinned for original category icons; no
backend or architecture change.

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
- [x] UI-AVATAR-013: Inspect both12/15-step avatar variants and locate original
  public rig/config/icons. Both variants were inspected and actual native inputs
  verified. Reuse the obtained original assets; source-era variants and timing
  remain separate from the completed asset research.
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

Prior continuation evidence:278 tests pass in `english-continuation-gate.log`;
15 source-sized captures are reviewed. Coverage closes6 ordered native mock flows
and45 screen occurrences while retaining23 reusable families. Two password screen
states are verified; source profile-editor entry/result remain in progress.
UI-QA-014 awaits the final refreshed web/browser check. The avatar assets are now
obtained; the continuation below adds the native editor. Do not rebuild completed
families while reconciling source variants.

## Clean product surface and original avatar continuation (2026-10-05)

Owner: parent; one isolated child owns only web shell HTML. Frozen mock-data
authorization remains. Source: both Creating an avatar Gummble flows and
`docs/design/flows/24_AVATAR_ASSET_RESEARCH.md`.

- [x] UI-SURFACE-018: Remove wrapper developer title/buttons/instructions and use
  full viewport on phones. Release rebuild and HTTP delivery verified; live
  browser inspection is tracked separately in UI-BROWSER-026.
- [x] UI-AVATAR-019: Inspect all15 alternate source steps; verify the discovered
  public original Rive/config/icon bytes and actual input contract. Add native
  eight-category customization, isolated draft/cancel/save, shared original rig,
  lazy static option tiles and profile/avatar entry. Preserve a selected avatar
  under reduced motion and background/resume. No invented rig inputs.
- [x] UI-AVATAR-QA-020: Test invalid options, cancel/save/reopen, category scroll,
  narrow/text2 accessibility, animation lifecycle and original output captures.
  Run canonical mobile gate/build and update only proven coverage marks. Live
  browser inspection is UI-BROWSER-026; exact archived animation timings remain
  separate per-screen evidence items rather than blocking this verified slice.
- [x] UI-COPY-021: Remove remaining engineering copy and simulation controls from
  ordinary product screens. Keep mock commands and failure fixtures in providers
  and tests. Recheck speaking fallback/lifecycle, subscription cancel/confirm,
  source course guard, sharing and password validation.

Files: account/domain/avatar_configuration.dart; account/application/
avatar_controller.dart; account/data/avatar_assets.dart; account/presentation/
avatar_builder_screen.dart and avatar_motion.dart; existing Profile/Edit Profile
entry points; exclusive parent router/pubspec locks. Tests: avatar_controller,
avatar_builder and avatar_motion. Engineering capability notes stay in docs;
ordinary app copy must not expose development instructions.

UI-COPY-021 additionally touches existing account, practice, learning and progress
presentation copy; course/password user-facing errors; corresponding practice,
Max, achievement and course tests. Backend commands remain disabled/mocked.

## Source Profile and read-only lists (2026-10-06)

Claim UI-PROFILE-022: parent owns routing, source assets, coverage and the native
read-only Courses/Friends lists; one isolated worker owns Own Profile widgets,
its session controller and behavior tests. Source: Profile6/8-step variants,
Creating an avatar final Profile, Courses(profile)2-step flow and Friends4-step
flow. Analyze before implementation. English progress is the existing local
learning fixture; other enrolled languages show their local course state.
No Math/Music/Chess or backend commands are added. Complete Profile opens the
original avatar editor; QR retains existing identity and clipboard behavior.
LinkedIn source promotion opens the local Score information route and can be
dismissed; real LinkedIn publishing is not enabled.

- [x] UI-PROFILE-022: Match own-profile source hierarchy and compact Overview;
  complete/saved avatar states, independent Courses/Following/Followers links,
  persistent-in-session score-card dismissal, QR and settings routes.
- [x] UI-LISTS-023: Native source Courses table and Following/Followers tabs;
  empty states, existing follow identity/return and course removal consistency.
  Test320/text2 and capture original-sized native states before closing evidence.

- [x] UI-SCORE-024: Parent owns source analysis/assets and exclusive routing;
  reuse one isolated worker after Profile. Native English course/score popover,
  source score information header, scrolling bands, English/Vietnamese examples,
  locked130–160 state and local share/clipboard. Source Score information3-step
  `d70eeb1a-cca9-47f3-b55d-1817937a4c6f` and More about score4-step
  `0f480cf3-2057-412c-999a-fe9a54bed855`. No learning reward mutations, external
  sharing or live speech are enabled. Validate source states, cancel/return,
  local playback lifecycle and320/text2; retain range boundary variants separately.

- [x] UI-PROFILE-025: Separate worker owns reusable native lower Profile sections
  and targeted tests only: friend-streak empty/active/pending states, conditional
  family entry, monthly badge strip and original achievement shortcuts. Parent
  owns Own Profile integration, captures and coverage. Reuse existing typed
  controllers/artwork and navigation; no invented reward or animation timelines.

- [ ] UI-BROWSER-026: Inspect the rebuilt existing localhost tab once the browser
  tool permits it. Its security policy blocked localhost selection in this
  continuation; no alternate browser/CDP/CLI workaround is authorized by that
  result. Native captures, compilation and HTTP delivery are already verified.

- [x] UI-FRIENDS-027: Fresh live source `sc_980cf097f47b4178b649f6a0b8fdddf6`
  completes the Friends flow with populated Followers and a blue Follow back
  control. One worker owns typed immutable follower snapshots, list action and
  focused behavior tests; parent owns captures, coverage and release rebuild.
  Preserve selected tab/follower set/English XP and follow once. No contacts,
  external discovery, notifications or backend writes are enabled.

- [x] UI-PROFILE-028: Isolated worker removes unreachable own-profile branches
  from the foreign Profile view. Typed immutable foreign fixtures own their
  summary; header/Overview must agree and cannot display the learner's XP,
  streak, lessons or avatar. Preserve original Own Profile delegation and all
  existing foreign profile actions. Parent owns integration evidence and build.

- [x] UI-BADGES-029: Reconcile Monthly Badges with the live three-screen flow
  `df71c72f-2817-4042-ba06-5a8047534ecf`. Worker owns the existing monthly grid,
  original badge regions and focused tests. Keep three columns, native month
  labels and immutable earned fixtures; responsive width/text2 must not distort
  illustrations or expose unrelated clipped text. Parent owns source captures,
  routing checks, coverage and the final release preview.

- [x] UI-PROFILE-030: Source foreign Profile flow
  `14ea3a1f-8b70-41ec-ade1-d77617a3f149` contains Weekly progress. Worker owns a
  typed immutable local comparison provider, native responsive chart and tests;
  parent owns integration/captures. Preserve foreign identity and separate its
  authored weekly fixture from the learner comparison. No analytics, server
  rewards, clock-based XP or extra chart dependency is added.

- [x] UI-PROFILE-031: Foreign Profile achievement navigation previously opened
  the learner's records. Retain owner identity through list/detail
  routes, use immutable authored foreign award fixtures and read-only controls.
  Unknown owner/award fails safely; no foreign reward can mutate learner claims.
  Own achievements, Monthly Badges and existing reward behavior remain unchanged.

- [x] UI-PROFILE-032: Source lower foreign Profile has three achievement cells
  (Legend, Perfect Week, Flawless Finisher), followed by Report/Block actions.
  Worker owns that isolated block and a reusable native component; parent owns
  source analysis, capture integration and final evidence. Preserve owner detail
  queries and guarded existing confirmations. Illustration crops must exclude
  embedded tier numerals that disagree with authored foreign counters. Keep the
  archived individual identity/entitlement/history variants explicitly open.

- [x] UI-PROFILE-033: Parent owns source foreign Profile hero/name/counters,
  Follow/Share row and compact Overview. Use authored immutable per-person choices
  from the verified original Rive avatar catalog, independent of the learner's
  saved avatar. Source geometry and actions are checked at320/text2 and with
  native captures. The source person/date/award history is not invented; real
  social writes and exact archived portrait/motion equivalence remain separate.

- [x] UI-LEAGUE-035: One worker owns source locked/eligible Welcome entry and
  native typography/buttons, callbacks and320/text2 tests. Parent owns existing
  mock1lesson eligibility, Continue membership mutation, bundle/captures/routing.
  Original podium Duo is a source still; matching private motion remains open.

- [x] UI-LEAGUE-034: One isolated worker owns joined ranking domain/provider/view
  and tests. Parent owns existing League route integration and native capture.
  Fresh Gummble Leaderboard flows95cfcf38-001a-4432-b49e-b4282f9703a4 (11 steps)
  and30488f3a-22f6-4c25-a883-db83e851d5cd (6 steps) are inspected. Replace generic
  centered trophy/ListTile/sample copy with source left header, trophy strip,
  source-sized ranking rows and learner highlight. Immutable authored English
  entries sort deterministically; all profile/Back/status actions remain working.
  Preserve current Bronze membership and local lesson eligibility; no inferred
  promotion cutoff, source-era countdown clock or server reward writes. Weekly
  settlement, promotion/gems and Diamond/event variants remain open.

Final continuation evidence:363 Flutter tests pass, fatal-info analyzer is clean,
release web rebuild passes and26 source-sized native states were inspected.
The final League spacing polish has an additional4-test/capture pass after the
full gate. Twelve HTTP HEAD checks confirm the latest release assets are served
locally with Cache-Control:no-store. The ledger preserves all prior completion
marks and now records28families,11complete ordered mock flows and71verified
screen occurrences. This does not claim all148source flows are implemented.
The final Family crop has a separate5-test/capture pass after removing an outer
white strip. [Profile/Score report](../design/qa/PROFILE_SCORE_CONTINUATION_REPORT.md)
records commands, source adaptations and remaining capability limits. UI-QA-014
retains the outstanding live browser check; the completed slices above must be
reused. Exact archived motion and unresolved source variants remain in the
persistent coverage ledger; mock verification is not production certification.

## Review focus


- Cancel/back retains enrollment and does not mutate learning XP, streak or path.
- Confirming twice/removing an already removed course is idempotent.
- English active-course protection has a visible reason and preserves input.
- Lower sheet controls scroll at text2 rather than clipping.
- Original illustration bounds and animation lifecycle are inspected separately
  from native text/controls; exact archived timing requires its own evidence.

Current user request continues implementation. The already published GitHub
snapshot remains historical; no automatic deployment or Release overwrite.
