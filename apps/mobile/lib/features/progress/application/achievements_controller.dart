import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../../../core/config/app_config.dart';
import '../data/achievements_repository.dart';
import '../data/api_achievements_repository.dart';
import '../domain/achievement_models.dart';

final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return MockAchievementsRepository();
  return ApiAchievementsRepository(
    ref.watch(apiEndpointsProvider),
    host: SnapshotHost.of(ref, 'achievements'),
  );
});

final achievementsControllerProvider =
    NotifierProvider<AchievementsController, AchievementState>(
      AchievementsController.new,
    );

final monthlyBadgesProvider = Provider<List<MonthlyBadge>>((ref) {
  watchSnapshot(ref, 'achievements');
  return ref.read(achievementsRepositoryProvider).loadMonthlyBadges();
});

class AchievementsController extends Notifier<AchievementState> {
  @override
  AchievementState build() {
    watchSnapshot(ref, 'achievements');
    return AchievementState(
      achievements: List.unmodifiable(
        ref.read(achievementsRepositoryProvider).loadAchievements(),
      ),
    );
  }

  AchievementDefinition? find(String id) {
    for (final achievement in state.achievements) {
      if (achievement.id == id) return achievement;
    }
    return null;
  }

  AchievementClaimResult claim(String id, {required int currentXp}) {
    final achievement = find(id);
    if (achievement == null) return AchievementClaimResult.notFound;
    if (state.claimedIds.contains(id)) {
      return AchievementClaimResult.alreadyClaimed;
    }
    if (!achievement.claimAvailable || !achievement.isEarned(currentXp)) {
      return AchievementClaimResult.locked;
    }
    state = state.copyWith(claimedIds: {...state.claimedIds, id});
    return AchievementClaimResult.claimed;
  }

  String? sharePreview(String id, {required int currentXp}) {
    final achievement = find(id);
    if (achievement == null || !achievement.isEarned(currentXp)) return null;
    return 'I earned the ${achievement.title} achievement in my English practice.';
  }
}
