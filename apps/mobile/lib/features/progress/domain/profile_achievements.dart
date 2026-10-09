import 'achievement_models.dart';
import 'profile_summary.dart';

class ProfileAchievements {
  ProfileAchievements({
    required this.profile,
    required List<AchievementDefinition> awards,
  }) : awards = List.unmodifiable(awards);

  final ProfileSummary profile;
  final List<AchievementDefinition> awards;

  AchievementDefinition? find(String id) {
    for (final award in awards) {
      if (award.id == id) return award;
    }
    return null;
  }
}
