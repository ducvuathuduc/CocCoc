# Slice A — hearts, mock ads and energy (2026-10-12)

Scope: [gap audit](../../design/GAP_AUDIT.md) rows 1–4 and 6; [reference spec](../../design/specs/gap-hearts-ads.md).
All slice A work is on `main` (fast-forward pushes, no force):

| Commit | What |
|---|---|
| `7726217` | hearts, ads and refill data (Repository + Mock + Riverpod) |
| `a637228` | hearts offer / need-hearts sheets, earned-heart screen, house ad |
| `c5599f7` | energy refill actions via repository (row 6) |
| `0729755` | in-lesson out of hearts now opens `showHeartsOfferSheet` (row 1); owner-approved regeneration of `goldens/ui_master/sprint_lesson_out_of_hearts_430.png` only |
| `462c136` | visual-QA fixes: Refill price shows the gem (was a Material diamond), unaffordable gem washed grey, earned-heart page #FFFFFF (the heart crop showed a box on #FFFDFE) |

## Final validation (2026-10-13, rebased on `3261ed5`)

```sh
. /workspace/tools/env.sh; cd apps/mobile
flutter analyze --no-pub                       # No issues found
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false --concurrency=1 \
  test/features/gap test/unit_skip_test.dart test/lesson_exercises_sprint_test.dart \
  test/settings_shop_taps_test.dart test/features/shop test/app_shell_sprint_test.dart \
  test/path_ui_master_golden_test.dart
```

Result: **93 passed, 2 failed**. Both failures are the known baseline on clean
`origin/main` (re-run there 2026-10-13 with identical diffs):
`path_ui_master_golden_test` core_path 3.21% / core_lesson_intro 0.95%, and
`shop_screen_test` shop_360_scale1. `app_shell_sprint_test` passes alone; it
showed a 2.8% image-load timing flake once under parallel load (icons decoded
before capture), not a code difference. Palette: 85 legacy unmatched colors,
unchanged; no new literal outside `../../design/qa/palette_from_refs.json`.

Side-by-side evidence (ours left, Gummble right) was composed with ImageMagick
outside the repo (`work/qa/gap/*_vs_ref.png`, script `compose.sh`).

## Owner decision and behavior

The placeholder `showOutOfHeartsSheet` was removed (`0729755`): the in-lesson
GOT IT at zero hearts now opens `showHeartsOfferSheet` (Super trial vs Refill,
TRY 1 WEEK FOR FREE / NO THANKS), which also opens from the failed unit/section
check illustration. The owner approved (2026-10-13) regenerating exactly
`apps/mobile/test/goldens/ui_master/sprint_lesson_out_of_hearts_430.png`.
Known limit: in a lesson, a successful Refill closes the sheet and ends the
session (it reuses `onEnd`); continuing the same lesson with refilled hearts
needs a lesson-hearts refill API that does not exist yet.

`showNeedHeartsSheet` is exposed and tested standalone; the home path uses energy
and checks initialize five local hearts, so no shared zero-heart start gate exists.
Its default Practice action starts the existing lesson engine; claiming that
practice receipt routes to `/hearts/earned` and awards one heart once. Free users
can gain one more via `/ad`; Super/Max suppress ads. The optional post-ad trial
uses the existing `/super` route. Ads remain a local house creative, without SDKs.

Energy offers come from the repository. FREE adds two, a rewarded ad adds five,
and recharge spends 500 preview gems and fills to the existing capacity. Full or
unlimited energy and insufficient gems disable the relevant actions. Errors keep
balances and expose retry. A synchronous ad reservation spans navigation: the
new rapid-tap test first observed two interstitial pushes, then passed with one
push and exactly five additional energy; its assertions were retained.

## Visual review and limits

Viewed the four new 360px / text-scale-1 goldens against the supplied archived iOS
references. Existing fonts, tokens, ReferenceButton and ReferenceArt are reused.
Three bundled PNGs are byte-identical source copies, listed in
[asset provenance](../../../apps/mobile/assets/PROVENANCE.md). Source copy,
counts, CTA and OS chrome are excluded from painted illustration regions;
all live values are native provider/repository data.

These checks establish Linux widget rendering and mock interaction behavior.
They do not establish pixel identity, exact original motion, live ads, backend
reward delivery or device QA. The authored mock countdown is five seconds because
stills cannot establish ad duration. Super gradient/counter is rendered natively
using the bundled heart silhouette; illustration details and font rasterization
can differ from the archived captures. Safe-area/OS chrome and fixture balances
also differ. Text scale two expands/scrolls sheets instead of clipping.

The only new Color literal is `#1E1E1E`: RGB `(30,30,30)` sampled with PIL at
`(10,10)` in `earn_heart_06_fad12a43b27d4962841ed25aa2eabeac.png`, noted in code.
Palette checking reports **85 unmatched legacy colors**, unchanged from baseline
(the script exits 1 for those existing entries); no new unmatched color.

## Completed validation before the rebase

Every shell sources `/workspace/tools/env.sh`. Dependencies were restored with
`cd apps/mobile && flutter pub get --offline`, then the lockfile was restored;
no dependency/lock changes are included. Tests were run one or two files at a
time, with the common prefix below; no existing golden was regenerated.

```sh
cd apps/mobile
timeout 95s flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false --concurrency=1 <files>
```

| Files after `test/` | Passed |
|---|---:|
| `features/gap/energy_actions_test.dart`, `features/gap/hearts_check_entry_test.dart` | 5 |
| `features/gap/hearts_ads_test.dart`, `features/gap/ad_states_test.dart` | 13 |
| `features/gap/hearts_goldens_test.dart`, `features/gap/hearts_router_flow_test.dart` | 5 |
| `features/gap/reward_repository_test.dart`, `features/gap/api_ads_repository_test.dart` | 4 |
| `unit_skip_test.dart`, `features/gap/hearts_check_entry_test.dart` | 17 |
| `score_energy_sprint_test.dart`, `extended_flow_test.dart` | 10 |
| `completion_ui_master_golden_test.dart`, `completion_sprint_golden_test.dart` | 17 |
| `lesson_exercises_sprint_test.dart`, `lesson_summary_test.dart` | 25 |
| `learning_flow_test.dart`, `practice_flow_test.dart` | 7 |
| `session_finish_routing_test.dart`, `app_shell_sprint_test.dart` | 12 |
| `app_test.dart`, `bootstrap_test.dart` | 2 |
| `features/results/results_extra_screens_test.dart`, `extended_capture_test.dart` | 32 |

The relevant tests were located with `rg -l 'energy_screen|lesson_results|main.dart'
apps/mobile/test --glob '*test.dart'`, supplemented by completion and check symbol
searches. Router regression coverage includes welcome/bootstrap, shell branches,
completion routes, lesson and practice flows, plus the new real-router reward flow.

Totals: **27 new gap tests and 121 existing tests, 148 unique tests passed**.
The check-entry test was rerun after its tap target and analyzer braces were
corrected. The existing `extended_capture_test.dart` exits early with `CAPTURE_UI` unset; its
pass is not screenshot evidence. Existing energy, completion, results, shell and
lesson goldens passed byte comparisons without any baseline update.

## Added files

- [apps/mobile/assets/reference_art/gap-heart-earned.png](../../../apps/mobile/assets/reference_art/gap-heart-earned.png)
- [apps/mobile/assets/reference_art/gap-house-ad-opening.png](../../../apps/mobile/assets/reference_art/gap-house-ad-opening.png)
- [apps/mobile/assets/reference_art/gap-house-ad.png](../../../apps/mobile/assets/reference_art/gap-house-ad.png)
- [apps/mobile/lib/features/ads/application/ads_controller.dart](../../../apps/mobile/lib/features/ads/application/ads_controller.dart)
- [apps/mobile/lib/features/ads/data/ads_repository.dart](../../../apps/mobile/lib/features/ads/data/ads_repository.dart)
- [apps/mobile/lib/features/ads/data/api_ads_repository.dart](../../../apps/mobile/lib/features/ads/data/api_ads_repository.dart)
- [apps/mobile/lib/features/ads/domain/house_ad.dart](../../../apps/mobile/lib/features/ads/domain/house_ad.dart)
- [apps/mobile/lib/features/ads/presentation/ad_screen.dart](../../../apps/mobile/lib/features/ads/presentation/ad_screen.dart)
- [apps/mobile/lib/features/hearts/application/hearts_controller.dart](../../../apps/mobile/lib/features/hearts/application/hearts_controller.dart)
- [apps/mobile/lib/features/hearts/data/hearts_repository.dart](../../../apps/mobile/lib/features/hearts/data/hearts_repository.dart)
- [apps/mobile/lib/features/hearts/domain/hearts.dart](../../../apps/mobile/lib/features/hearts/domain/hearts.dart)
- [apps/mobile/lib/features/hearts/presentation/heart_earned_screen.dart](../../../apps/mobile/lib/features/hearts/presentation/heart_earned_screen.dart)
- [apps/mobile/lib/features/hearts/presentation/hearts_sheets.dart](../../../apps/mobile/lib/features/hearts/presentation/hearts_sheets.dart)
- [apps/mobile/lib/features/hearts/presentation/hearts_visuals.dart](../../../apps/mobile/lib/features/hearts/presentation/hearts_visuals.dart)
- [apps/mobile/lib/features/progress/application/energy_controller.dart](../../../apps/mobile/lib/features/progress/application/energy_controller.dart)
- [apps/mobile/lib/features/progress/data/energy_repository.dart](../../../apps/mobile/lib/features/progress/data/energy_repository.dart)
- [apps/mobile/lib/features/progress/domain/energy_offer.dart](../../../apps/mobile/lib/features/progress/domain/energy_offer.dart)
- [apps/mobile/test/features/gap/ad_states_test.dart](../../../apps/mobile/test/features/gap/ad_states_test.dart)
- [apps/mobile/test/features/gap/api_ads_repository_test.dart](../../../apps/mobile/test/features/gap/api_ads_repository_test.dart)
- [apps/mobile/test/features/gap/energy_actions_test.dart](../../../apps/mobile/test/features/gap/energy_actions_test.dart)
- [apps/mobile/test/features/gap/hearts_ads_test.dart](../../../apps/mobile/test/features/gap/hearts_ads_test.dart)
- [apps/mobile/test/features/gap/hearts_check_entry_test.dart](../../../apps/mobile/test/features/gap/hearts_check_entry_test.dart)
- [apps/mobile/test/features/gap/hearts_goldens_test.dart](../../../apps/mobile/test/features/gap/hearts_goldens_test.dart)
- [apps/mobile/test/features/gap/hearts_router_flow_test.dart](../../../apps/mobile/test/features/gap/hearts_router_flow_test.dart)
- [apps/mobile/test/features/gap/reward_repository_test.dart](../../../apps/mobile/test/features/gap/reward_repository_test.dart)
- [apps/mobile/test/goldens/gap/heart_earned_360.png](../../../apps/mobile/test/goldens/gap/heart_earned_360.png)
- [apps/mobile/test/goldens/gap/house_ad_360.png](../../../apps/mobile/test/goldens/gap/house_ad_360.png)
- [apps/mobile/test/goldens/gap/lesson_offer_360.png](../../../apps/mobile/test/goldens/gap/lesson_offer_360.png)
- [apps/mobile/test/goldens/gap/need_hearts_360.png](../../../apps/mobile/test/goldens/gap/need_hearts_360.png)
- [docs/archive/qa-receipts/GAP_HEARTS_ADS_RECEIPT.md](GAP_HEARTS_ADS_RECEIPT.md)
- [docs/design/specs/gap-hearts-ads.md](../../design/specs/gap-hearts-ads.md)
