# Missing-screen audit (Gummble Duolingo vs apps/mobile)

Audited 2026-10-12 on `origin/main` 87cdc25. Sources: the local Gummble cache (`docs/design/references/ORDERED_FLOW_INDEX.json`, 148 iOS flows / 779 cached screens in `references/catalog-cache/`), a live Gummble sweep (iOS + Android, 2026-10-12) for states missing from the cache, and the Flutter routes/screens under `apps/mobile/lib`. New reference crops for this audit are in [`refs/gap/`](refs/gap/).

Status: **Present** = a route/screen/sheet exists (pixel QA is tracked separately in `qa/FLOW_CHECKLIST.md`); **Partial** = surface exists but the referenced state/action is missing or is a placeholder; **Missing** = no UI; **Owned** = gap belongs to another agent's area (listed, not built here); **No ref** = Gummble has no capture, so nothing can be copied.

Priority: P0 = a Free user hits it in a normal session; P1 = common secondary state; P2 = rare/cosmetic.

## Gap table

| # | Screen / state | Gummble ref | Status | Priority | Notes |
|---|---|---|---|---|---|
| 1 | Out of hearts **in lesson** (Super trial vs Refill gems, "TRY 1 WEEK FOR FREE"/"NO THANKS") | sc_1ae5ddcf · `refs/gap/hearts_02_out_of_hearts_in_lesson.png` | Partial → planned | P0 | `showOutOfHeartsSheet` was a self-declared UNKNOWN placeholder. |
| 2 | "You need hearts to start new lessons!" (Next heart in, Super / +1 Heart Practice / Refill) | sc_fb07ca98 · `refs/gap/hearts_03_need_hearts_home.png` | Missing → planned | P0 | |
| 3 | Practice to earn a heart → "You gained a heart! Watch an ad to gain another" | 68cd5891 · `refs/gap/earn_heart_01..04,09` | Missing → planned | P0 | Practice session reuses the existing lesson; result screen is new. |
| 4 | Ad interstitial for Free users (house ad + skip) | sc_ad9c3299, sc_fad12a43 · `refs/gap/earn_heart_05,06` | Missing → planned | P0 | Only Duolingo house-ad captures exist; no third-party ad. Mock ad provider; no ad SDK. |
| 5 | Super free-trial interstitial after ad ("Get started with a 7 day free trial") | sc_02a1e078, sc_e4a392e0 · `refs/gap/earn_heart_07,08` | Partial | P1 | `/super` paywall exists; post-ad entry routes there. |
| 6 | Energy refill actions (+5 energy WATCH AD, +2 FREE, Recharge 500) | sc_365781ef · `refs/gap/energy_refill_options.png` | Partial → planned (actions) | P0 | Rows were static constants (G-DATA); layout unchanged, rows now act via repository. |
| 7 | Hearts dropdown from stats bar | sc_901080ed · `refs/gap/hearts_dropdown.png` | Partial | P2 | Home uses the newer Energy model; energy popover exists. Hearts only in checks/legendary. |
| 8 | Offline banner "YOU ARE OFFLINE" + greyed path | sc_12b09a6c · `refs/gap/offline_banner.png` | Missing → planned | P0 | Connectivity repository (mock + API-failure signal); no new plugin. |
| 9 | XP Boost activated (x2, 15 minutes) after claiming a chest | sc_269d6ffb, sc_b4ac42c6 · `refs/gap/xp_boost_activated*.png` | Missing → planned | P1 | Shop claim showed a gems sheet only. |
| 10 | Report an issue: iOS action list + "Issue successfully reported" toast | sc_f2f569c1, sc_2082f9ab · `refs/gap/report_issue_*.png` | Partial | P2 | A report sheet exists in `lesson_screen.dart`; lesson screen is concurrently edited by b-lesson-av, so it is not touched. |
| 11 | Streak Society locked card / app-icon sheet | `refs/gap/streak_society_locked_ios.png`, `streak_app_icon_sheet_ios.png`, `streak_society_android.png` | Present | — | `streak_screen.dart`, `app_icon_sheet.dart`. |
| 12 | Streak freeze / Streak Shield / Perfect streak / "less than 3 hours" | Personal streak 1bc25485 | Present | — | `streak_screen.dart`. |
| 13 | Streak repair / "streak saved" / earn back streak | none on Gummble (iOS + Android searched) | No ref | P1 | API has repair endpoints; no capture to copy. |
| 14 | League promotion / demotion result | none beyond Leaderboard flows | Present (`/league/results`) | — | No promotion capture on Gummble. |
| 15 | Lesson end chain: XP, streak extended, streak goal, widget unlock, friend streak, gems, quests, friends quest, league, create profile | Completing a lesson 068dbdc0/238c4339 | Present | — | `results_chain.dart`. |
| 16 | Monthly quest intro / friends quest Nudge, Gift, High-five / chests | Quests 1af0050f | Present | — | `quests_screen.dart`. |
| 17 | Daily quest chest opening animation | Claiming a reward (Android, 7) | Partial | P2 | Gems sheet exists; Android capture not cached. |
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
| 32 | Redeem a promo code | Android flow "Redeem a promo code" (no screens captured) | No ref | P2 | Nothing to copy. |
| 33 | Manage features (Android) | Android Home sub-flow (3) | No ref cached | P2 | |

## Counts

- Rows: 33.
- Present: 19 · Partial: 5 (rows 5, 7, 10, 17, plus 6 before this task) · Missing: 5 (rows 2, 3, 4, 8, 9) · Owned: 2 · No ref: 3 (13, 32, 33).
- Planned in this task: rows 1, 2, 3, 4, 6, 8, 9.
