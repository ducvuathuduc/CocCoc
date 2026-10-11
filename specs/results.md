# Results screens after lesson (sp/results)

Gummble flow "Completing a lesson" (docs/design/references/results/, captured 2026-10-04).
Already done elsewhere (not rewritten): 02 Flawless/stat tiles (`LessonSummary`), 03 score, 06 streak commit (`LessonResults`).

New in `lib/features/results/` (domain → data `ResultsRepository` + `MockResultsRepository` → `results_providers.dart` → presentation):

| Ref | Screen | Data |
|---|---|---|
| 04 | `GemRewardScreen` | `GemRewardResult` (gems, unit, message) |
| 05 | `StreakExtendedScreen` | `StreakExtendedResult` (days, week states, share label) |
| 11 | `QuestProgressResultScreen` | `QuestProgressResult` (points, gem balance, quests current/target/chest) |
| 12 | `LeagueRankResultScreen` | `LeagueRankResult` (rows, promotion cutoff, user row) |

Layout measured at 430×932 (ref scaled 430/1180), top inset 59: CTA bottom 877 (league 868), card 18pt side margins, radius 18, stroke 1.5 `#E7E5E7`.
Colors: `ResultsColors` in results_theme.dart, each sampled with PIL getpixel (coords in comments), all present in palette_from_refs.json.

Motion (all via `DelayedMotion`, final frame immediately when `MediaQuery.disableAnimations`):
- stagger slide/fade 320ms easeOutCubic, 90ms step (quest tiles, rank rows, streak days, message)
- count-up `RewardCount` 500ms (gems, streak numeral, XP per rank row)
- progress bar fill 650ms from 0 (quest bars, delayed 250ms + stagger)
- chest/hero bounce 900ms elasticOut (gem chest, quest chests after fill, trophy, flame Duo, headline)
- learner rank row slides in from the left (-60 px)
- confetti once (`LessonCelebration`) on gem reward and streak extended

Known deltas: test font lacks CJK so `おおしろゆめか` renders as boxes in the golden only; quest bar label 1–2pt smaller; ±2pt vertical offsets.
Not wired into the router (router is lead-only): screens accept `onContinue`/`onShare`.
