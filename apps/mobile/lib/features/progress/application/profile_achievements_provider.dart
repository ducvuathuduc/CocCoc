import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/achievement_models.dart';
import '../domain/profile_achievements.dart';
import 'achievements_controller.dart';
import 'profile_summary_provider.dart';

// Authored local ownership fixtures, independent of learner claims/progress.
// Missing counters remain zero; these are not inferred service award rules.
const _fixtureCounters = <String, List<int>>{
  'Alex': [1, 4, 9],
  'Maria': [2, 6, 12],
  'Lucas': [0, 2, 5],
  'Anna': [3, 8, 18],
  'Samira': [1, 5, 10],
  'Sam Lee': [2, 5, 11],
  'Noah': [0, 1, 3],
  'Emma': [2, 7, 15],
  'James Smith': [1, 4, 8],
};

final profileAchievementsProvider =
    Provider.family<ProfileAchievements?, String>((ref, userId) {
      final profile = ref.watch(profileSummaryProvider(userId));
      if (profile == null) return null;
      final counters = _fixtureCounters[userId] ?? const [0, 0, 0];
      final catalog = ref
          .watch(achievementsRepositoryProvider)
          .loadAchievements();
      return ProfileAchievements(
        profile: profile,
        awards: [
          for (final award in catalog)
            AchievementDefinition(
              id: award.id,
              title: award.title,
              art: award.art,
              detailArt: award.detailArt,
              kind: award.kind,
              progress: (switch (award.id) {
                'perfect-week' => counters[0],
                'legend' => counters[1],
                'flawless-finisher' => counters[2],
                _ => 0,
              }).clamp(0, award.goal),
              goal: award.goal,
              description: '${profile.name}’s ${award.title} progress.',
            ),
        ],
      );
    });
