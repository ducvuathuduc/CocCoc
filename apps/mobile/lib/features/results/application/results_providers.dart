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
