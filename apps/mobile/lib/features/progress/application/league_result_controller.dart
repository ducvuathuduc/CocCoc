import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/league_result.dart';

final leagueResultFixtureProvider = Provider<LeagueResultFixture?>(
  (ref) => LeagueResultFixture(
    previousTier: LeagueTier.bronze,
    currentTier: LeagueTier.silver,
    rewardGems: 40,
    entries: const <LeagueResultEntry>[
      LeagueResultEntry(name: 'Sam', xp: 867, rank: 1, isLearner: true),
    ],
  ),
);

enum LeagueResultStage { result, promotion, reward, complete }

class LeagueResultState {
  const LeagueResultState({required this.fixture, required this.stage});

  final LeagueResultFixture? fixture;
  final LeagueResultStage stage;

  LeagueResultState copyWith({LeagueResultStage? stage}) =>
      LeagueResultState(fixture: fixture, stage: stage ?? this.stage);
}

final leagueResultControllerProvider =
    NotifierProvider.autoDispose<LeagueResultController, LeagueResultState>(
      LeagueResultController.new,
    );

class LeagueResultController extends Notifier<LeagueResultState> {
  @override
  LeagueResultState build() {
    final fixture = ref.watch(leagueResultFixtureProvider);
    return LeagueResultState(
      fixture: fixture,
      stage: fixture == null
          ? LeagueResultStage.complete
          : LeagueResultStage.result,
    );
  }

  /// Advances the authored acknowledgement sequence. Returns true only for the
  /// single transition into completion, so repeated taps cannot finish twice.
  bool advance() {
    final fixture = state.fixture;
    if (fixture == null) return false;
    final next = switch (state.stage) {
      LeagueResultStage.result =>
        fixture.promoted
            ? LeagueResultStage.promotion
            : fixture.rewardGems > 0
            ? LeagueResultStage.reward
            : LeagueResultStage.complete,
      LeagueResultStage.promotion =>
        fixture.rewardGems > 0
            ? LeagueResultStage.reward
            : LeagueResultStage.complete,
      LeagueResultStage.reward => LeagueResultStage.complete,
      LeagueResultStage.complete => LeagueResultStage.complete,
    };
    if (next == state.stage) return false;
    state = state.copyWith(stage: next);
    return next == LeagueResultStage.complete;
  }
}
