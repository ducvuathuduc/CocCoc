import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../progress/data/league_repository.dart';
import '../../progress/data/progress_snapshot.dart';
import '../data/api_results_repository.dart';
import '../data/results_repository.dart';
import '../domain/results_models.dart';

final resultsRepositoryProvider = Provider<ResultsRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return const MockResultsRepository();
  return ApiResultsRepository(ref.watch(progressSnapshotSourceProvider));
});

final streakExtendedResultProvider = Provider<StreakExtendedResult>(
  (ref) => _results(ref).streakExtended(),
);

final gemRewardResultProvider = Provider<GemRewardResult>(
  (ref) => _results(ref).gemReward(),
);

final questProgressResultProvider = Provider<QuestProgressResult>(
  (ref) => _results(ref).questProgress(),
);

final leagueRankResultProvider = Provider<LeagueRankResult>(
  (ref) => _results(ref).leagueRank(),
);

final streakGoalResultProvider = Provider<StreakGoalResult?>(
  (ref) => _results(ref).streakGoal(),
);

final widgetUnlockResultProvider = Provider<WidgetUnlockResult?>(
  (ref) => _results(ref).widgetUnlock(),
);

final friendStreakResultProvider = Provider<FriendStreakResult?>(
  (ref) => _results(ref).friendStreak(),
);

final friendsQuestResultProvider = Provider<FriendsQuestResult?>(
  (ref) => _results(ref).friendsQuest(),
);

final pathReturnResultProvider = Provider<PathReturnResult>(
  (ref) => _results(ref).pathReturn(),
);

ResultsRepository _results(Ref ref) {
  watchProgressSnapshot(ref);
  return ref.watch(resultsRepositoryProvider);
}
