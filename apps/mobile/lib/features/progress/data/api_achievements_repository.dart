import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../../../core/design/reference_art.dart';
import '../domain/achievement_models.dart';
import 'achievements_repository.dart';

/// Server state behind the achievements screen: earned track ids from
/// `GET /v1/me` and the live streak from `GET /v1/me/rewards`.
final class AchievementsSnapshot {
  const AchievementsSnapshot({required this.profile, required this.rewards});

  factory AchievementsSnapshot.fromJson(Map<String, Object?> json) =>
      AchievementsSnapshot(
        profile: wire.Profile.fromJson(json['profile']),
        rewards: wire.Rewards.fromJson(json['rewards']),
      );

  final wire.Profile profile;
  final wire.Rewards rewards;

  Map<String, Object?> toJson() => {
    'profile': profile.toJson(),
    'rewards': rewards.toJson(),
  };
}

/// [AchievementsRepository] for the Progress tracks (`lessons` 5/20/50,
/// `streak` 3/7/30 — services/progress catalog). The server exposes earned
/// track ids, not per-tier counts, so lesson progress is the first threshold
/// once earned; streak progress is the live current streak.
class ApiAchievementsRepository implements AchievementsRepository {
  ApiAchievementsRepository(this.api, {SnapshotHost? host})
    : cache = SnapshotCache<AchievementsSnapshot>(
        key: 'achievements',
        host: host ?? SnapshotHost.detached(),
        decode: AchievementsSnapshot.fromJson,
        encode: (s) => s.toJson(),
      );

  final ApiEndpoints api;
  final SnapshotCache<AchievementsSnapshot> cache;

  Future<AchievementsSnapshot> _fetch() async {
    final results = await Future.wait<Object>([api.getMe(), api.getRewards()]);
    return AchievementsSnapshot(
      profile: results[0] as wire.Profile,
      rewards: results[1] as wire.Rewards,
    );
  }

  Future<void> refresh() => cache.refresh(_fetch);

  static const _tracks = [
    (
      id: 'streak',
      title: 'Wildfire',
      art: AchievementArt.longestStreak,
      tiers: [3, 7, 30],
      unit: 'day streak',
    ),
    (
      id: 'lessons',
      title: 'Scholar',
      art: AchievementArt.perfectLessons,
      tiers: [5, 20, 50],
      unit: 'lessons',
    ),
  ];

  @override
  List<AchievementDefinition> loadAchievements() {
    cache.ensureLoaded(_fetch);
    final snapshot = cache.value;
    if (snapshot == null) return const [];
    final earned = snapshot.profile.achievementIds.toSet();
    final streak = snapshot.rewards.currentStreak;
    return [
      for (final track in _tracks)
        _definition(
          track.id,
          track.title,
          track.art,
          track.tiers,
          track.unit,
          value: track.id == 'streak'
              ? streak
              : (earned.contains(track.id) ? track.tiers.first : 0),
        ),
    ];
  }

  AchievementDefinition _definition(
    String id,
    String title,
    ArtRegion art,
    List<int> tiers,
    String unit, {
    required int value,
  }) {
    final goal = tiers.firstWhere((t) => t > value, orElse: () => tiers.last);
    return AchievementDefinition(
      id: id,
      title: title,
      art: art,
      progress: value.clamp(0, goal),
      goal: goal,
      description: 'Reach $goal $unit to unlock the next $title level.',
    );
  }

  /// Monthly badges have no read endpoint yet; API mode shows none rather than
  /// archived fixtures.
  @override
  List<MonthlyBadge> loadMonthlyBadges() => const [];
}
