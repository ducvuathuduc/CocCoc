# Missing-screen audit (Gummble Duolingo vs apps/mobile)

Audited 2026-10-12 on `origin/main` 87cdc25. Sources: the local Gummble cache (`docs/design/references/ORDERED_FLOW_INDEX.json`, 148 iOS flows / 779 cached screens in `references/catalog-cache/`), a live Gummble sweep (iOS + Android, 2026-10-12) for states missing from the cache, and the Flutter routes/screens under `apps/mobile/lib`. New reference crops for this audit are in [`refs/gap/`](refs/gap/).

Status: **Present** = a route/screen/sheet exists (pixel QA is tracked separately in `qa/FLOW_CHECKLIST.md`); **Partial** = surface exists but the referenced state/action is missing or is a placeholder; **Missing** = no UI; **Owned** = gap belongs to another agent's area (listed, not built here); **No ref** = Gummble has no capture, so nothing can be copied.

Priority: P0 = a Free user hits it in a normal session; P1 = common secondary state; P2 = rare/cosmetic.

## Gap table

| # | Screen / state | Gummble ref | Status | Priority | Notes |
|---|---|---|---|---|---|
| 1 | Out of hearts **in lesson** (Super trial vs Refill gems, "TRY 1 WEEK FOR FREE"/"NO THANKS") | sc_1ae5ddcf · `refs/gap/hearts_02_out_of_hearts_in_lesson.png` | **Present** (`a637228`, `0729755`, `462c136`, `886a9a1`) | P0 | Placeholder removed; lesson GOT IT at 0 hearts opens `showHeartsOfferSheet`. `886a9a1`: palette-snapped Super card gradient, white pill above the scrim. Goldens `gap/lesson_offer_360`, `ui_master/sprint_lesson_out_of_hearts_430` (owner-approved). Refill in-lesson ends the session (no lesson-hearts refill API yet). |
| 2 | "You need hearts to start new lessons!" (Next heart in, Super / +1 Heart Practice / Refill) | sc_fb07ca98 · `refs/gap/hearts_03_need_hearts_home.png` | **Present** (`7726217`, `a637228`, `462c136`, `886a9a1`) | P0 | `showNeedHeartsSheet`; home uses Energy, so no shared zero-heart start gate triggers it yet (Hearts-model learners reach it from the hearts dropdown, row 7). |
| 3 | Practice to earn a heart → "You gained a heart! Watch an ad to gain another" | 68cd5891 · `refs/gap/earn_heart_01..04,09` | **Present** (`a637228`, `462c136`, `886a9a1`, `ab84f07`) | P0 | Practice session reuses the existing lesson; `/hearts/earned` result screen. `ab84f07`: its ad now continues to the Super trial (row 5), as in flow 68cd5891. |
| 4 | Ad interstitial for Free users (house ad + skip) | sc_ad9c3299, sc_fad12a43 · `refs/gap/earn_heart_05,06` | **Present** (`7726217`, `a637228`, `886a9a1`) | P0 | Only Duolingo house-ad captures exist; no third-party ad. Mock ad provider; no ad SDK. `886a9a1`: final frame without close X, navy CONTINUE. |
| 5 | Super free-trial interstitial after ad ("Get a 7-day free trial of Super Duolingo") | sc_02a1e078, sc_e4a392e0 · `refs/gap/earn_heart_07,08` | **Present** (`ab84f07`) | P1 | `/super/trial` (`SuperTrialScreen`): cleaned capture `gap-super-trial.png` (text cleared, bubble kept) + native title/bubble/footnote/TRY FOR $0.00/NO THANKS from `SuperTrialRepository` (mock). `AdScreen(offerTrial)` pushes it; TRY → `/super`. Golden `gap/super_trial_360`. The earn_heart_07 "SUPER duolingo" splash before it is not built. |
| 6 | Energy refill actions (+5 energy WATCH AD, +2 FREE, Recharge 500) | sc_365781ef · `refs/gap/energy_refill_options.png` | **Present** (`c5599f7`) | P0 | Rows were static constants (G-DATA); layout unchanged, rows now act via repository. |
| 7 | Hearts dropdown from stats bar | sc_901080ed · `refs/gap/hearts_dropdown.png` | **Present** (`886a9a1`, `e05762b`) | P2 | `LivesModel` (energy default \| hearts) on HeartsRepository; Hearts-model learners' heart stat opens the dropdown (Super / Refill / Practice). Copy incl. full-hearts and close labels from `HeartsContent` (`e05762b`). Golden `gap/hearts_dropdown_360`. Energy remains the default model. |
| 8 | Offline banner "YOU ARE OFFLINE" + greyed path | sc_12b09a6c · `refs/gap/offline_banner.png` | **Present** (`50af76c`, `462c136`, `886a9a1`) | P0 | Connectivity repository (mock + API-failure signal); no new plugin. Golden `gap/offline_path_360`. `886a9a1`: current node washed, no START bubble (matches ref). |
| 9 | XP Boost activated (x2, 15 minutes) after claiming a chest | sc_269d6ffb, sc_b4ac42c6 · `refs/gap/xp_boost_activated*.png` | **Present** (`3497411`, `98d08ad`, `886a9a1`) | P1 | Friends Chest: gems sheet → `/xp-boost/activated`. `886a9a1`: open flask (cork clipped). |
| 10 | Report an issue: iOS action list + "Issue successfully reported" toast | sc_f2f569c1, sc_2082f9ab · `refs/gap/report_issue_*.png` | **Present** (`fb12ad7`) | P2 | `IssueReportRepository` (mock) supplies the nine categories and toast copy; frosted action list grows from the flag; toast 2.5 s above the feedback panel. Goldens `gap/report_issue_{menu,toast}_360`. |
| 11 | Streak Society locked card / app-icon sheet | `refs/gap/streak_society_locked_ios.png`, `streak_app_icon_sheet_ios.png`, `streak_society_android.png` | Present | — | `streak_screen.dart`, `app_icon_sheet.dart`. |
| 12 | Streak freeze / Streak Shield / Perfect streak / "less than 3 hours" | Personal streak 1bc25485 | Present | — | `streak_screen.dart`. |
| 13 | Streak repair / "streak saved" / earn back streak | none on Gummble (iOS + Android searched) | **Present** (`ab84f07`) — No ref – derived | P1 | `/streak/repair` in the streak-screen style: greyed flame, lost-day count, offer countdown, REPAIR FOR 350 gems (wallet-checked) or USE STREAK REPAIR when owned, restored state. `StreakRepairRepository` (mock; fields match `POST /v1/me/streak-repair`). Personal-streak banner only while an offer exists (default mock: none). No API repository yet. Goldens `gap/streak_repair_{offer,restored}_360`. |
| 14 | League promotion / demotion result | none beyond Leaderboard flows | Present (`/league/results`) | — | No promotion capture on Gummble. |
| 15 | Lesson end chain: XP, streak extended, streak goal, widget unlock, friend streak, gems, quests, friends quest, league, create profile | Completing a lesson 068dbdc0/238c4339 | Present | — | `results_chain.dart`. |
| 16 | Monthly quest intro / friends quest Nudge, Gift, High-five / chests | Quests 1af0050f | Present | — | `quests_screen.dart`. |
| 17 | Daily quest chest opening animation | Claiming a reward (Android, 7) | **Present** (`0b1561a`, `e05762b`) | P2 | Credited daily-quest claim opens a full-screen chest (pop, wiggles, lid burst + rays, gems rise, '+N' / CONTINUE). Copy from `ChestRewardCopy` via the quests repository (`e05762b`). Android capture not cached: timings authored, not measured. Goldens `gap/chest_opening_{burst,}_360`. |
| 18 | Choosing a streak goal ("Commit") | 7aa5ea5a | Present | — | results chain `streakGoal` stage + onboarding. |
| 19 | Onboarding / placement / login / signup / reset password | Onboarding, Logging in, Creating a profile, Resetting password | Present | — | `/welcome`, `/onboarding`, `/placement`, `/auth/*`, `/reset-password`. |
| 20 | Lesson types & states (all exercises, correct/wrong, combo) | Starting a lesson 55608180 et al. | Present | — | Audio/images/SFX gaps **Owned** by b-lesson-av / b-images. |
| 21 | Speaking exercise, mic permission denied | Completing a lesson | Owned (b-speech) | — | |
| 22 | Notifications opt-in prompt, reminders, Dynamic Island, Live Activities, OS widgets | Customizing reminders, Turning off notifications, Widgets, Dynamic Island, Live Activities | Owned (b-notify) | — | In-app settings + widget gallery present. |
| 23 | Super / Max upsell, plans, trial, manage/cancel, family, gift | Super, Max, Choose a plan, Canceling, Family, Gift | Present | — | `/super`, `/max`, `/subscription/*`, gift. |
| 24 | Max compare table (FREE vs MAX) | `refs/gap/max_upsell_compare_ios.png` | Present | — | `max_screen.dart`. |
| 25 | Legendary: intro, session, "Congrats! You earned Legendary" | cefa75a7, `refs/gap/legendary_earned_ios.png` | Present | — | `challenge_intro.dart` legendary-complete. |
| 26 | Practice hub, Mistakes review, Words, Listen/Speak | Practice hub, Mistakes, Words | Present | — | `/practice/:kind`. |
| 27 | Stories, Radio, Roleplay, Video call, Adventure, Clash | respective flows | Present | — | |
| 28 | Settings subpages (preferences, notifications, privacy, courses, profile, password, schools, social, legal, help, feedback) | Settings ×3, Profile (settings) | Present | — | |
| 29 | Profile edit, avatar builder, achievements + detail, share, badges, friends, follow, search, report/block, QR | profile/achievement flows | Present | — | |
| 30 | Delete account, log out, saved accounts, change password, verify phone | respective flows | Present | — | |
| 31 | Empty states (no friends, no mistakes, empty followers) | various | Present | — | |
| 32 | Redeem a promo code | Android flow "Redeem a promo code" (no screens captured) | **Present** (`ab84f07`) — No ref – derived | P2 | `/settings/promo` (from Manage subscription): P10-PROMO-001 code shape, NOT_FOUND / PROMO_ALREADY_REDEEMED / offline copy, one idempotency key per code. `MockPromoRepository` + `ApiPromoRepository` (`redeemPromoCode`). Goldens `gap/promo_code_{error,success}_360`. |
| 33 | Manage features (Android) | Android Home sub-flow (3), not cached | **Present** (`ab84f07`) — No ref – derived | P2 | `/settings/super-features` (from Manage subscription): Super perks as switches, optimistic with revert on failed save; Free learners see them locked + GET SUPER. `SuperFeaturesRepository` (mock; no preferences contract). Goldens `gap/super_features_{super,locked}_360`. |

## Counts

- Rows: 33. Updated 2026-10-13 (main `e05762b`).
- Present: 31 (rows 5, 7, 10, 13, 17, 32, 33 added on 2026-10-13; 13, 32, 33 are **No ref – derived**, built in the app's own style because Gummble has no capture) · Partial: 0 · Owned: 2 (21, 22) · No ref (unbuilt): 0 · Missing: 0.
- Side-by-side QA (ours vs Gummble) for rows 1–5, 7–10 and derived sheets for 13, 17, 32, 33: [GAP_HEARTS_ADS_RECEIPT](../archive/qa-receipts/GAP_HEARTS_ADS_RECEIPT.md), [GAP_SLICE_B_RECEIPT](../archive/qa-receipts/GAP_SLICE_B_RECEIPT.md), [GAP_POLISH_RECEIPT](../archive/qa-receipts/GAP_POLISH_RECEIPT.md).
