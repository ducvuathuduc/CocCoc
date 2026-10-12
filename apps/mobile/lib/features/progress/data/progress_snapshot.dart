import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/cache/snapshot_cache.dart';

/// One cached read of the Progress service state that several synchronous
/// surfaces share: shell stats, league standings, league result, post-lesson
/// results. Fetched together so the shell, league tab and results chain agree.
final class ProgressSnapshot {
  const ProgressSnapshot({
    required this.profile,
    required this.rewards,
    required this.energy,
    required this.league,
    required this.leagueResult,
    required this.quests,
  });

  factory ProgressSnapshot.fromJson(Map<String, Object?> json) =>
      ProgressSnapshot(
        profile: wire.Profile.fromJson(json['profile']),
        rewards: wire.Rewards.fromJson(json['rewards']),
        energy: wire.Energy.fromJson(json['energy']),
        league: json['league'] == null
            ? null
            : wire.League.fromJson(json['league']),
        leagueResult: wire.LeagueResult.fromJson(json['leagueResult']),
        quests: wire.QuestPage.fromJson(json['quests']),
      );

  final wire.Profile profile;
  final wire.Rewards rewards;
  final wire.Energy energy;

  /// `null` until the learner has joined this week's cohort.
  final wire.League? league;
  final wire.LeagueResult leagueResult;
  final wire.QuestPage quests;

  wire.LeagueMember? get me =>
      league?.members.where((m) => m.userId == profile.userId).firstOrNull;

  Map<String, Object?> toJson() => {
    'profile': profile.toJson(),
    'rewards': rewards.toJson(),
    'energy': energy.toJson(),
    'league': league?.toJson(),
    'leagueResult': leagueResult.toJson(),
    'quests': quests.toJson(),
  };
}

/// Owner of the shared [ProgressSnapshot] cache (API mode only).
final class ProgressSnapshotSource {
  ProgressSnapshotSource(
    this.api, {
    SnapshotHost? host,
    DateTime Function()? clock,
  }) : cache = SnapshotCache<ProgressSnapshot>(
         key: 'progress',
         host: host ?? SnapshotHost.detached(),
         decode: ProgressSnapshot.fromJson,
         encode: (s) => s.toJson(),
         maxAge: const Duration(seconds: 30),
         clock: clock,
       );

  final ApiEndpoints api;
  final SnapshotCache<ProgressSnapshot> cache;

  ProgressSnapshot? get value {
    cache.ensureLoaded(_fetch);
    return cache.value;
  }

  Future<ProgressSnapshot?> refresh() => cache.refresh(_fetch);

  Future<ProgressSnapshot> _fetch() async {
    final results = await Future.wait<Object?>([
      api.getMe(),
      api.getRewards(),
      api.getEnergy(),
      _league(),
      api.getLeagueResult(),
      api.listQuests(limit: 50),
    ]);
    return ProgressSnapshot(
      profile: results[0]! as wire.Profile,
      rewards: results[1]! as wire.Rewards,
      energy: results[2]! as wire.Energy,
      league: results[3] as wire.League?,
      leagueResult: results[4]! as wire.LeagueResult,
      quests: results[5]! as wire.QuestPage,
    );
  }

  Future<wire.League?> _league() async {
    try {
      return await api.getLeague(limit: 30);
    } on ApiException catch (error) {
      // 404: not placed in a cohort yet this week.
      if (error.isNotFound) return null;
      rethrow;
    }
  }
}

const progressSnapshotFeature = 'progress';

final progressSnapshotSourceProvider = Provider<ProgressSnapshotSource>(
  (ref) => ProgressSnapshotSource(
    ref.watch(apiEndpointsProvider),
    host: SnapshotHost.of(ref, progressSnapshotFeature),
  ),
);
