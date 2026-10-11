import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/results_repository.dart';
import '../domain/results_models.dart';

final resultsRepositoryProvider = Provider<ResultsRepository>(
  (ref) => const MockResultsRepository(),
);

final streakExtendedResultProvider = Provider<StreakExtendedResult>(
  (ref) => ref.watch(resultsRepositoryProvider).streakExtended(),
);

final gemRewardResultProvider = Provider<GemRewardResult>(
  (ref) => ref.watch(resultsRepositoryProvider).gemReward(),
);

final questProgressResultProvider = Provider<QuestProgressResult>(
  (ref) => ref.watch(resultsRepositoryProvider).questProgress(),
);

final leagueRankResultProvider = Provider<LeagueRankResult>(
  (ref) => ref.watch(resultsRepositoryProvider).leagueRank(),
);

final streakGoalResultProvider = Provider<StreakGoalResult?>(
  (ref) => ref.watch(resultsRepositoryProvider).streakGoal(),
);

final widgetUnlockResultProvider = Provider<WidgetUnlockResult?>(
  (ref) => ref.watch(resultsRepositoryProvider).widgetUnlock(),
);

final friendStreakResultProvider = Provider<FriendStreakResult?>(
  (ref) => ref.watch(resultsRepositoryProvider).friendStreak(),
);

final friendsQuestResultProvider = Provider<FriendsQuestResult?>(
  (ref) => ref.watch(resultsRepositoryProvider).friendsQuest(),
);

final pathReturnResultProvider = Provider<PathReturnResult>(
  (ref) => ref.watch(resultsRepositoryProvider).pathReturn(),
);
