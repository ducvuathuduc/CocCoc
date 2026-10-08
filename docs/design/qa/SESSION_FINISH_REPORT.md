# English frontend continuation — 2026-10-08

Scope: tasks UI-LEAGUE-036, UI-REVIEW-037, UI-WIDGETS-038 and UI-QA-039.
Two isolated workers and the parent implemented and reviewed the new native
Flutter surfaces; feature-first manual Riverpod MVVM remains unchanged.

Implemented: league result → promotion → reward acknowledgement, seven Year in
Review pages, seven original Duo widget looks in medium/small sizes, accessible
selection and OS guidance. Profile/Settings expose the new routes. Close, system
Back, completion and replay preserve learning XP, streak and wallet balances.
Historical review/league fixtures are read-only; widget selection owns no reward
or journal writes. Auto-disposal rejects stale asynchronous work.

Review corrections include clipped source text, source-art distortion, offscreen
buttons, intrinsic layout assertions, text/art overlap and fabricated weekday
rows. All seven widget weekday rows were checked directly against Gummble.

## Evidence

- Failing-first receipts: `session-league-result-red.log`,
  `session-year-review-red.log`, `session-widgets-red.log`, `session-routes-red.log`.
- Native captures: `session-finish/` contains 17 source-sized Flutter states;
  `session-finish-captures.log` records the capture command/result.
- Targeted behavior: `session-finish-targeted-final.log` and
  `session-widget-routes-final.log`; the full final gate supersedes intermediate
  repair runs.
- Reference asset audit: 951 ordered saved PNGs, 225 bundled PNGs, byte-identical
  source hashes. Avatar audit: 18 original assets, 8 categories, 282 choices.
- `node tools/scripts/mobile-check.mjs --with-blueprint` → PASS: blueprint,
  199 Dart files formatted, fatal-info analyzer clean, all 394 Flutter tests.
  Receipt: `session-finish-gate.log`.
- Source capture command: `flutter test --dart-define=ENABLE_MASCOT_MOTION=false
  --dart-define=CAPTURE_SESSION_UI=true test/session_finish_capture_test.dart`
  → PASS, 17 PNGs at 1180×2556 using original bundled font and source art.
- `node tools/scripts/mobile-web-build.mjs` → PASS, release compiled in 78.7s;
  local original Rive WASM is bundled. Receipt: `session-finish-web-build.log`.
- Persistent ledger: 30 reusable families, 13 complete scoped mock flows and
  89 verified ordered occurrences. Existing marks remain intact.
- Local preview: `http://127.0.0.1:4173/preview.html` serves the actual Flutter
  release app. 23 HTTP checks pass with `Cache-Control: no-store`; served
  `main.dart.js` SHA-256 exactly matches the new build.
  Receipt: `session-finish-http.json`. Preview server PID: 29748.

Source analysis: [Year/Widgets](../flows/28_YEAR_REVIEW_WIDGETS.md),
[League](../flows/27_LEAGUE_SOURCE_RECONCILIATION.md).
Original provenance remains in the asset register.

## Capability scope

This is the authorized mock Flutter frontend. Screenshots supply original still
art; native transition curves and small edge blending are documented adaptations.
Private archived mascot timelines, production backend/speech, physical-device
performance, OS widget extensions and browser-interaction certification are
separate capabilities. Completion marks refer to the tested native mock slice;
they do not certify every one of the 148 archived source flows.
