# English frontend continuation receipt

2026-10-05. User scope remains English/language UI with local mock data. This
receipt covers the new slices; the published GitHub release is historical.

## Added native UI

- [Course management](../flows/20_COURSE_MANAGEMENT.md): Settings entry, protected
  active English fixture, native confirmation, original crying Duo, disabled-row
  removing state, cancel and result. Math/Music/Chess excluded; learning preserved.
- [Profile actions](../flows/21_PROFILE_ACTIONS.md): report/block/unblock, native
  reason sheet, generated QR, actual clipboard failure/retry and floating receipt.
  League identities match profile actions; unknown IDs show unavailable profiles.
- [Password changes](../flows/22_CHANGE_PASSWORD.md): three independent visibility
  controls, disabled invalid SAVE with inline validation, preserved failures,
  duplicate/disposal guards and working subsequent mock login. Full source profile
  editor variant remains pending.
- [Saved-account management](../flows/23_SAVED_ACCOUNT_MANAGEMENT.md): full page,
  anchored Remove popover, cancel/Done, busy/error protection and Welcome return.
- [Avatar research](../flows/24_AVATAR_ASSET_RESEARCH.md): inspected12-step variant;
  original composable layers/rig and15-step deconstruction remain open.

## Verification

`node tools/scripts/mobile-check.mjs --with-blueprint` passed:278 tests, clean
analyzer and formatting, plus structural blueprint validation. Evidence:
[english-continuation-gate.log](english-continuation-gate.log). `node
tools/scripts/mobile-web-build.mjs` passed the refreshed release web build,
explicit mock auth and bundled Rive runtime: [build log](english-continuation-web-build.log).
The local server serves preview/new art with HTTP200 at
http://127.0.0.1:4173/preview.html. Codex browser opening was queued for this hidden
chat; live browser interaction in this slice remains unverified. Build reports an
unbundled CupertinoIcons font family warning; application source uses Material
icons and the captured action sheet contains readable native text.
Targeted course10, password/profile11,
unknown/profile4 and saved-account/login21 runs also passed; these groups overlap.

`flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false
--dart-define=CAPTURE_UI=true test/profile_course_capture_test.dart` passed.
Fifteen1180×2556 captures are in [english-continuation](english-continuation/).
Reviewed states include course confirmation/removing/result, QR/copy/reasons/block,
password empty/filled/error/mismatch and saved-account manager/popover/Welcome.
Independent OpenCV decoding of the avatar-overlaid QR returned exactly
`https://cocenglish.test/profile/me`, the tested clipboard URL.

`node tools/scripts/reference-asset-audit.mjs` passed:951 source occurrences across
18 source families;202 bundled PNGs match saved byte hashes. Existing Rive/Lottie
exports and local runtime are reused; no new proprietary animation rig is claimed.

## Completion register and limits

[FLOW_CHECKLIST.md](FLOW_CHECKLIST.md) and [FLOW_COVERAGE.json](FLOW_COVERAGE.json)
preserve148 ordered flows /912 screen occurrences:23 reusable families,6 fully
verified ordered mock flows and45 verified screen occurrences. The password
flow's full profile editor entry/result remain in progress. A verified mock mark means the
scoped native behavior and evidence exist; it does not certify pixel/motion or
production equivalence. Regeneration validates existing marks without resetting.

Original crying Duo remains a still. Source glass compositing, rounded QR-eye
geometry, full profile editor layout and exact route/mascot timing remain open.
Profile identities/URLs are local fixtures. No real moderation, cloud password
change, OS sharing, new Android/device/iOS build or deployment is claimed here.
