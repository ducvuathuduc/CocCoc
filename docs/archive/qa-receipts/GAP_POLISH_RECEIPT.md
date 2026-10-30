# Gap polish receipt — 2026-10-13

Scope: [audit](../../design/GAP_AUDIT.md) rows 5, 7, 10, 13, 17, 32, 33 (status updates
for 1–4, 8, 9). All commits are on `main`.

| Commit | Rows | What |
|---|---|---|
| `886a9a1` | 1–4, 7, 8, 9 | Visual QA fixes; row 7 hearts dropdown + `LivesModel` |
| `fb12ad7` | 10 | Report an issue: iOS action list + toast |
| `0b1561a` | 17 | Daily-quest chest opening animation |
| `ab84f07` | 5, 13, 32, 33 | `/super/trial` after the ad; `/streak/repair`, `/settings/promo`, `/settings/super-features` |
| `e05762b` | 7, 17 | Chest and hearts-dropdown copy moved into repositories (no visual change) |

## Row 5 — Super trial (sc_e4a392e0)

`assets/reference_art/gap-super-trial.png` = `earn_heart_08` with all text,
both actions and the home indicator cleared; speech bubble kept, only its two
lines erased (x 249–930, y 828–1199). Provenance: `apps/mobile/assets/PROVENANCE.md`.
Every string comes from `SuperTrialRepository` (mock). Geometry is measured from
the capture and cover-mapped with the art; footnote and actions keep their
distance from the bottom on short viewports. Side-by-side:
`work/qa/gap/super_trial_360_vs_ref.png` (workspace QA folder).

Remaining differences: app font (DuolingoSans) renders slightly narrower than
the capture's; no OS home indicator; the earn_heart_07 "SUPER duolingo" splash
before the trial is not built.

## Rows 13, 32, 33 — No ref, derived

Gummble has no capture for these, so they follow the app's own streak and
settings pages, with colours only from `../../design/qa/palette_from_refs.json`
(`python3 tools/palette_check.py`: 85 legacy colours, none new). Each has a
repository + mock + Riverpod provider; promo also has `ApiPromoRepository`
(`redeemPromoCode`, P10-PROMO-001). Streak repair has no API repository yet
(contract `POST /v1/me/streak-repair` exists). Its banner on the personal
streak tab shows only while the repository has an offer; the default mock has
none, so no existing streak golden changed. Promo and Manage features are
reached from rows at the bottom of Manage subscription (below the fold).

## Goldens

New: `gap/super_trial_360`, `gap/streak_repair_{offer,restored}_360`,
`gap/promo_code_{error,success}_360`, `gap/super_features_{super,locked}_360`.
No existing golden was regenerated.

## Tests

- `test/features/gap/{super_trial,streak_repair,promo_code,super_features}_test.dart`:
  all pass, including 2× text at 320×568 and 430×932.
- Regression set (all other `test/features/gap`, `test/features/quests`, quests,
  streak, Super/Max/family, extended, social, iconcgift, widget app icon):
  177 pass, 0 fail.
- `test/core` + `test/features` after rebasing on main 1a5e836: 316 pass, 1 fail,
  the known baseline `ui_master/shop_360_scale1`. The top-level `test/*.dart`
  chunks were not run (skipped at the owner's request).
- `flutter analyze`: no issues.
