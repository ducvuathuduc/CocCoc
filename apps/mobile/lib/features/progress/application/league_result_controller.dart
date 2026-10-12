import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/league_repository.dart';
import '../domain/league_result.dart';

final leagueResultFixtureProvider = Provider<LeagueResultFixture?>((ref) {
  watchProgressSnapshot(ref);
  return ref.watch(leagueRepositoryProvider).lastResult();
});

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
    if (next == LeagueResultStage.complete) {
      unawaited(
        ref
            .read(leagueRepositoryProvider)
            .markResultSeen()
            .catchError((Object _) {}),
      );
    }
    return next == LeagueResultStage.complete;
  }
}
