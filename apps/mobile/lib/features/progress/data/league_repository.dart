import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/idempotency.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../../../core/config/app_config.dart';
import '../domain/league_ranking.dart';
import '../domain/league_result.dart';
import 'progress_snapshot.dart';

/// A league-only cohort member (no browsable profile) in the mock league.
class LeagueRosterMember {
  const LeagueRosterMember({
    required this.userId,
    required this.name,
    required this.xp,
  });

  final String userId, name;
  final int xp;
}

/// Demo cohort filling the mock league to 30 learners alongside the seven
/// profile previews and the learner (Duolingo cohorts hold 30).
const demoLeagueRoster = <LeagueRosterMember>[
  LeagueRosterMember(userId: 'league-linh', name: 'Linh Nguyen', xp: 1385),
  LeagueRosterMember(userId: 'league-kenji', name: 'Kenji Sato', xp: 1210),
  LeagueRosterMember(userId: 'league-sofia', name: 'Sofia Rossi', xp: 1102),
  LeagueRosterMember(userId: 'league-minh', name: 'Minh Tran', xp: 987),
  LeagueRosterMember(userId: 'league-chloe', name: 'Chloé Dubois', xp: 915),
  LeagueRosterMember(userId: 'league-hoa', name: 'Hoa Pham', xp: 842),
  LeagueRosterMember(userId: 'league-david', name: 'David Lee', xp: 776),
  LeagueRosterMember(userId: 'league-ana', name: 'Ana Souza', xp: 703),
  LeagueRosterMember(userId: 'league-bao', name: 'Bao Hoang', xp: 655),
  LeagueRosterMember(userId: 'league-priya', name: 'Priya Patel', xp: 598),
  LeagueRosterMember(userId: 'league-tuan', name: 'Tuan Vo', xp: 541),
  LeagueRosterMember(userId: 'league-mia', name: 'Mia Schmidt', xp: 487),
  LeagueRosterMember(userId: 'league-thao', name: 'Thao Dang', xp: 432),
  LeagueRosterMember(userId: 'league-omar', name: 'Omar Haddad', xp: 376),
  LeagueRosterMember(userId: 'league-yuna', name: 'Yuna Choi', xp: 318),
  LeagueRosterMember(userId: 'league-khanh', name: 'Khanh Bui', xp: 264),
  LeagueRosterMember(userId: 'league-jack', name: 'Jack Taylor', xp: 219),
  LeagueRosterMember(userId: 'league-lan', name: 'Lan Ho', xp: 171),
  LeagueRosterMember(userId: 'league-ivan', name: 'Ivan Petrov', xp: 128),
  LeagueRosterMember(userId: 'league-ngoc', name: 'Ngoc Ly', xp: 86),
  LeagueRosterMember(userId: 'league-sam', name: 'Sam Carter', xp: 44),
  LeagueRosterMember(userId: 'league-vy', name: 'Vy Truong', xp: 12),
];

/// Widget tests pin the 8-learner reference league (the source of the
/// goldens and route tests) by setting this in `flutter_test_config.dart`.
/// Tests that exercise the enriched mock cohort reset it.
bool debugPinReferenceLeague = false;

/// Extra mock cohort members; tests pin the 8-learner reference league by
/// overriding this with an empty list. Ignored in API mode.
final mockLeagueRosterProvider = Provider<List<LeagueRosterMember>>(
  (ref) => debugPinReferenceLeague ? const [] : demoLeagueRoster,
);

/// League standings and the weekly result acknowledgement.
abstract interface class LeagueRepository {
  /// Server standings; `null` means "use the local preview ranking" (mock).
  LeagueRanking? ranking();

  /// Whether the server has already placed this learner in a cohort.
  bool get joined;

  /// Opts in for the current week; returns the server standings when placed.
  Future<LeagueRanking?> join();

  /// Unseen weekly result to celebrate, or `null` when there is none.
  LeagueResultFixture? lastResult();

  Future<void> markResultSeen();
}

/// Mock: the league tab derives its ranking from local profile previews and
/// the result screen shows the reference Bronze → Silver promotion.
class MockLeagueRepository implements LeagueRepository {
  const MockLeagueRepository();

  @override
  LeagueRanking? ranking() => null;

  @override
  bool get joined => false;

  @override
  Future<LeagueRanking?> join() async => null;

  @override
  LeagueResultFixture? lastResult() => LeagueResultFixture(
    previousTier: LeagueTier.bronze,
    currentTier: LeagueTier.silver,
    rewardGems: 40,
    entries: const <LeagueResultEntry>[
      LeagueResultEntry(name: 'Sam', xp: 867, rank: 1, isLearner: true),
    ],
  );

  @override
  Future<void> markResultSeen() async {}
}

/// [LeagueRepository] over `GET /v1/league`, `GET /v1/league/result` and
/// `POST /v1/league/result/seen`, read from the shared progress snapshot.
class ApiLeagueRepository implements LeagueRepository {
  ApiLeagueRepository(this.source);

  final ProgressSnapshotSource source;
  String? _joinKey;

  @override
  bool get joined => source.cache.value?.league != null;

  @override
  LeagueRanking? ranking() {
    final snapshot = source.value;
    final league = snapshot?.league;
    if (league == null || snapshot == null) return _rankingOf(null, null);
    return _rankingOf(league, snapshot.profile.userId);
  }

  /// At most one cohort per week: the server replays the same membership for a
  /// repeated key and returns the authoritative tier and standings.
  @override
  Future<LeagueRanking?> join() async {
    final league = await source.api.joinLeague(
      idempotencyKey: _joinKey ??= UuidV4Generator().next(),
    );
    _joinKey = null;
    final current = source.cache.value;
    if (current != null) {
      source.cache.put(
        ProgressSnapshot(
          profile: current.profile,
          rewards: current.rewards,
          energy: current.energy,
          league: league,
          leagueResult: current.leagueResult,
          quests: current.quests,
        ),
      );
    }
    return _rankingOf(league, current?.profile.userId);
  }

  LeagueRanking _rankingOf(wire.League? league, String? ownUserId) {
    final members = [...?league?.members]
      ..sort((a, b) => a.rank.compareTo(b.rank));
    return LeagueRanking(
      tier: league == null ? null : tierOf(league.tier),
      entries: [
        for (final m in members)
          LeagueRankingEntry(
            userId: m.userId,
            name: m.nickname.isEmpty ? 'Learner' : m.nickname,
            xp: m.eligibleXp,
            rank: m.rank,
            isOwn: m.userId == ownUserId,
          ),
      ],
    );
  }

  @override
  LeagueResultFixture? lastResult() {
    final snapshot = source.value;
    final result = snapshot?.leagueResult;
    final week = result?.lastResult;
    if (snapshot == null || result == null || week == null || !result.unseen) {
      return null;
    }
    return LeagueResultFixture(
      previousTier: tierOf(week.previousTier),
      currentTier: tierOf(week.tier),
      rewardGems: week.gemsAwarded,
      entries: [
        LeagueResultEntry(
          name: snapshot.profile.nickname.isEmpty
              ? 'You'
              : snapshot.profile.nickname,
          xp: snapshot.me?.eligibleXp ?? 0,
          rank: week.rank ?? 1,
          isLearner: true,
        ),
      ],
    );
  }

  @override
  Future<void> markResultSeen() async {
    final week = source.cache.value?.leagueResult.lastResult;
    if (week == null) return;
    await source.api.markLeagueResultSeen(
      wire.LeagueResultSeenRequest(weekId: week.weekId),
    );
    unawaited(source.refresh());
  }

  /// Server tiers run 0..9; the app art has seven leagues.
  static LeagueTier tierOf(int tier) =>
      LeagueTier.values[tier.clamp(0, LeagueTier.values.length - 1)];
}

final leagueRepositoryProvider = Provider<LeagueRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return const MockLeagueRepository();
  return ApiLeagueRepository(ref.watch(progressSnapshotSourceProvider));
});

/// Rebuild trigger for anything derived from the progress snapshot.
int watchProgressSnapshot(Ref ref) =>
    watchSnapshot(ref, progressSnapshotFeature);
