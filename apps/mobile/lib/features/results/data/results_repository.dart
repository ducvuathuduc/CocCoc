import '../domain/results_models.dart';

/// Source of post-lesson outcomes. A cloud adapter replaces the mock by
/// overriding `resultsRepositoryProvider`; screens never read fixtures.
abstract class ResultsRepository {
  StreakExtendedResult streakExtended();
  GemRewardResult gemReward();
  QuestProgressResult questProgress();
  LeagueRankResult leagueRank();
}

/// Archived Gummble "Completing a lesson" flow values (results/04, 05, 11, 12).
class MockResultsRepository implements ResultsRepository {
  const MockResultsRepository();

  @override
  StreakExtendedResult streakExtended() => const StreakExtendedResult(
    days: 5,
    title: 'day streak',
    week: [
      ResultDay('Mo', ResultDayState.practiced),
      ResultDay('Tu', ResultDayState.practiced),
      ResultDay('We', ResultDayState.practiced),
      ResultDay('Th', ResultDayState.practiced),
      ResultDay('Fr', ResultDayState.today),
      ResultDay('Sa', ResultDayState.missed),
      ResultDay('Su', ResultDayState.missed),
    ],
    shareLabel: 'SHARE +20 GEMS',
    continueLabel: 'CONTINUE',
  );

  @override
  GemRewardResult gemReward() => const GemRewardResult(
    gems: 50,
    unit: 'gems',
    message: 'You earned 50 gems for unlocking\nyour English Score!',
    continueLabel: 'CONTINUE',
  );

  @override
  QuestProgressResult questProgress() => const QuestProgressResult(
    points: 1,
    gemBalance: 950,
    continueLabel: 'CONTINUE',
    quests: [
      QuestProgressItem(
        id: 'lesson',
        title: 'Complete 1 lesson',
        current: 1,
        target: 1,
        chest: QuestChestState.opened,
      ),
      QuestProgressItem(
        id: 'match-madness',
        title: 'Do 1 Match Madness challenge',
        current: 0,
        target: 1,
        chest: QuestChestState.locked,
      ),
      QuestProgressItem(
        id: 'minutes',
        title: 'Spend 10 minutes learning',
        current: 1,
        target: 10,
        chest: QuestChestState.gold,
      ),
    ],
  );

  @override
  LeagueRankResult leagueRank() => const LeagueRankResult(
    message: 'The top 8 move up to the next\nleague. Will you make it?',
    promotionCutoff: 8,
    promotionLabel: 'PROMOTION ZONE',
    continueLabel: 'I CAN DO IT',
    rows: [
      LeagueRankRow(
        rank: 8,
        name: 'Wendy',
        xp: 85,
        avatarKey: null,
        initial: 'W',
        flagKey: 'us',
        streak: 31,
      ),
      LeagueRankRow(
        rank: 9,
        name: 'Alex Smith',
        xp: 74,
        avatarKey: 'alex',
        flagKey: 'fr',
        streak: 19,
        isUser: true,
      ),
      LeagueRankRow(
        rank: 10,
        name: 'おおしろゆめか',
        xp: 71,
        avatarKey: 'yumeka',
        flagKey: 'us',
        streak: 6,
      ),
      LeagueRankRow(
        rank: 11,
        name: 'K k. Ng',
        xp: 68,
        avatarKey: 'kk',
        flagKey: 'fr',
        streak: 21,
      ),
      LeagueRankRow(
        rank: 12,
        name: 'Marcus Yeung',
        xp: 59,
        avatarKey: null,
        initial: 'M',
        flagKey: 'us',
        streak: 11,
      ),
    ],
  );
}
