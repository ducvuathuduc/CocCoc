# Profile and English Score continuation — 2026-10-08

Native Flutter implementation keeps the frozen feature-first manual Riverpod
MVVM architecture. Two isolated workers implemented Score and lower Profile;
the parent owns routing, integration, source analysis, assets and coverage.
Read-only review found score overflow, playback/clipboard lifecycle and selected
semantics issues; the implemented fixes have behavior tests.

## Implemented and reviewed

- Own Profile: original placeholder/saved avatar, pinned collapsing header,
  source Complete Profile/Score promotion, Courses/Following/Followers links,
  QR, local Overview, original paid badge and dismissible promotion.
- Courses/Friends lists: enrolled language projection, unchanged English learning
  state, source-style rows/tabs, profile identity, empty followers and correct
  tab selection when the query changes on a reused route.
- Populated Followers: immutable snapshot order, original orange initial/source
  portrait, tactile blue Follow back, blocked/duplicate guards, accessibility
  action and foreign Profile return. Following does not change the follower set.
- Foreign Profile: original Rive avatar catalog supplies nine immutable authored
  appearances, with source profile-display colors and matching QR identity.
  Source hero/name/counters, Follow/Share, compact Overview and Weekly progress
  use native text, controls and a font-aware chart. Foreign summary/weekly/award
  data cannot borrow learner XP, saved avatar or claimed achievements.
- Foreign lower Profile: original source Legend/Perfect Week/Flawless Finisher
  illustrations in three equal cells; source tier numerals excluded from crops.
  Owner-scoped award list/detail is read-only, keeps Back scroll position and
  omits invented record dates. Report/Block/Unblock reuse guarded confirmations.
- Monthly Badges: three columns with source-relative illustration sizes, native
  font-measured labels, four visible 2025 rows, twelve 2024 badges and only the
  three source-visible 2023 fixtures. The November crop excludes August's label.
- League ranking: source left header, original trophy/medal art, original public
  avatar portraits, green learner row and immutable deterministic XP ordering.
  Profile Back restores a nonzero list offset; ordinary phone layout keeps the
  header pinned. Text2/short windows scroll the full header and stack XP below
  the name, including a999999XP fixture. Saved avatar appears consistently in
  both the ranking row and status sheet. Existing Bronze membership remains local.
- League entry: source locked illustration/count and eligible podium Welcome.
  One local lesson exposes Welcome; Continue joins once without extra XP or
  rewards. Source-measured figure sizes, native typography,16logical action
  insets, white surface and narrow/text2 scrolling are captured and tested.
  Ranking reordering preserves mounted avatar state; spoken profile/status
  actions do not duplicate decorative rank/name/XP text.
- Lower Profile: five Friend Streak slots, typed active/pending state, conditional
  Family card/manager, latest four local monthly badges and achievement shortcuts.
  Source figure crops remain independent from native controls. Locked medals do
  not paint source month headings or faded colored illustrations.
- English Score: course popover, nine inclusive bands, selected semantics,
  current-band visibility, English/Vietnamese examples, source portraits/native
  speech bubbles, locked range, local playback and clipboard retry/share card.
  Playback stops on close/background/unmount. Duplicate/stale/post-disposal copy
  results cannot overwrite a new operation. The local Score producer caps at160.
- Product surface: no wrapper developer title/buttons/instructions/credentials;
  ordinary app screens do not expose simulation controls or engineering labels.
  Mock auth/data remain authorized test fixtures and do not connect cloud services.

Source analysis: [Profile/Courses/Friends](../flows/25_PROFILE_SOURCE_RECONCILIATION.md)
and [English Score](../flows/26_ENGLISH_SCORE_INFORMATION.md), plus
[League ranking/entry](../flows/27_LEAGUE_SOURCE_RECONCILIATION.md). Original avatar
asset/motion evidence remains in [avatar report](AVATAR_PRODUCT_SURFACE_REPORT.md).

## Evidence

- `node tools/scripts/mobile-check.mjs --with-blueprint`: structural blueprint,
  Dart format, fatal-info analyzer and363 Flutter tests pass in
  [canonical gate](profile-source-complete-gate.log). The preceding three stale
  profile/QR test expectations are retained in
  [regression receipt](profile-source-regression-red.log); updated tests target
  the unique Unblock semantic action and the foreign owner's original avatar.
- `flutter test --dart-define=ENABLE_MASCOT_MOTION=false
  --dart-define=CAPTURE_PROFILE_UI=true test/profile_surface_capture_test.dart
  test/league_entry_surface_test.dart`:4pass in
  [source-capture test receipt](profile-source-complete-captures.log).
  Windows host capture puts the prebuilt release Rive DLL directory on PATH.
  Required avatar scenes assert actual RiveWidget instances before capture.
  Cupertino's package-prefixed font family is explicitly loaded for test images.
- `flutter test --dart-define=ENABLE_MASCOT_MOTION=false
  test/league_ranking_test.dart test/league_entry_surface_test.dart
  test/league_source_route_test.dart test/status_feed_ui_test.dart`:20pass in
  [review regression pass](league-review-green.log). The
  [meaningful RED](league-review-red.log) reproduces avatar State replacement
  and duplicate spoken labels. The final6logical Welcome text gap and16logical
  bottom inset are additionally checked by the capture/entry rerun after the
  full gate. Browser/device motion timing is not inferred from static captures.
- Profile summary/Weekly/owner awards/Monthly/Followers/header integration:
  38pass in [focused receipt](profile-weekly-foreign-awards-final.log).
  Further RED receipts preserve [chart font](profile-weekly-font-red.log),
  [foreign record dates](profile-foreign-record-date-red.log),
  [safety action font](profile-safety-font-red.log),
  [hero/QR owner identity](profile-foreign-share-avatar-red.log).
- Score state/view tests:10pass in [clipboard/lifecycle receipt](score-controller-green.log).
  Meaningful RED receipts: [controller contracts](score-controller-red.log),
  [uncapped165 Score](score-cap-red.log),
  [missing lower Profile/header](profile-lower-integration-red.log).
- After visual review, the empty Family crop excludes a white strip outside the
  original card. Its targeted test/capture rerun is recorded in
  [final Family crop receipt](profile-family-crop-final.log):5pass. The resulting
  image was re-inspected and contains no white strip outside the figure.
- `node tools/scripts/avatar-asset-audit.mjs`:18 original files,8 categories,
  282 choices; hashes pass. `node tools/scripts/reference-asset-audit.mjs`:
  208 bundled PNGs match saved source bytes, including the Welcome source.
- `node tools/scripts/mobile-web-build.mjs`: release web build passes in
  [web receipt](profile-source-web-build.log). Both Material and
  Cupertino font assets are included. Local preview HTTP checks are recorded in
  [delivery receipt](profile-source-http.json).

The current web build completed in77.5seconds;12 HTTP HEAD asset checks return200
with Cache-Control:no-store. The local server was restarted after its previous
process stopped. The existing preview URL remains unchanged.

Persistent coverage now records28verified reusable families,11complete ordered
mock flows and71verified screen occurrences out of148flows/912occurrences.
Friends and Monthly Badges each gain a complete ordered mock flow. League gains
six verified source occurrences across its two journeys and Profile entry; its
settlement, promotion and event steps remain open. All61previous completion
marks are preserved. See [checklist](FLOW_CHECKLIST.md).

26 source-sized native captures use bundled fonts,1180×2556 pixels and59/34 logical
safe insets. Reviewed states: [empty Profile](profile-source/own-empty.png),
[locked League](profile-source/league-locked.png),
[eligible Welcome](profile-source/league-welcome.png),
[saved avatar](profile-source/own-saved.png), [Courses](profile-source/courses.png),
[Following](profile-source/following.png), [Followers](profile-source/followers.png),
[populated Followers](profile-source/followers-populated.png),
[followed Followers](profile-source/followers-followed.png),
[foreign hero](profile-source/foreign-james.png),
[foreign QR](profile-source/foreign-share.png),
[Weekly](profile-source/foreign-weekly.png),
[foreign lower](profile-source/foreign-lower.png),
[foreign awards](profile-source/foreign-awards.png),
[foreign award detail](profile-source/foreign-award-detail.png),
[lower Profile](profile-source/own-lower.png),
[empty Family](profile-source/family-empty.png),
[Family member](profile-source/family-member.png),
[Monthly2025](profile-source/monthly-2025.png),
[Monthly2024](profile-source/monthly-2024.png),
[early A1 Score](profile-source/score-early.png),
[locked Score](profile-source/score-locked.png),
[course popover](profile-source/course-score.png),
[League ranking](profile-source/league-ranking.png),
[learner row](profile-source/league-own-row.png),
[saved avatar status](profile-source/league-status.png).

Windows Rive tests report unsuccessful debug-DLL search attempts before using
the release runtime on PATH. Required scenes assert original RiveWidget instances;
the captured saved/foreign portraits visibly render. These diagnostics remain
in the raw receipts and are not evidence of physical-device performance.

Final Entry comparison: locked figure width differs by at most2source pixels and
its top by9–11pixels; Welcome figure width/height match, with its top4pixels high.
The Welcome body is13pixels narrower overall and2pixels high. Button-to-divider
gap matches48source pixels; the native five-tab shell moves the divider42pixels
above the archived six-tab shell. These measured differences remain documented;
no100%pixel-equivalence claim is made.

## Limits

These are verified local mock UI states. Historical names/counts/months/languages
are adapted to existing English fixtures. Source-era six-tab shells, every old
Profile League entry/entitlement/history/individual portraits and archived timing
remain separate coverage
items; this report does not certify all148 flows or100% pixel/motion fidelity.

The original public Rive avatar export and available authored mascot/world
character assets are integrated. Screenshots do not supply missing walking,
crying or Max conversation rigs, original audio or viseme timing. The cached
public app chunk confirms ten known in-lesson character Rive files; its six Math
files are outside scope and it contains no missing crying/walking Duo rig.
No substitute animation is labeled as the original.

Score audio is local playback state, sharing is a local clipboard card, and
Family/account changes stay mocked. Real audio, Appwrite, billing, notifications,
AI conversation, physical-device and production gates remain pending.

The browser tool's security policy blocked inspection of the existing localhost
tab. No alternate browser/CDP/CLI workaround was used; no fresh live browser
interaction is claimed. Web compilation and HTTP delivery are checked
independently. Existing GitHub Release/deployment remains historical.
