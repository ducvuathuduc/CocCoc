import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../learning/domain/learning_models.dart';
import '../data/activity_progress_repository.dart';
import '../data/practice_content_repository.dart';

/// Verified account used for practice reads. Guest sessions keep mock content,
/// matching the courses screen.
final practiceAccountProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authControllerProvider.select((s) => s.user)),
);

final practiceContentRepositoryProvider = Provider<PracticeContentRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  final user = ref.watch(practiceAccountProvider);
  if (!config.isApi || user == null || user.guest) {
    return const MockPracticeContentRepository();
  }
  return ApiPracticeContentRepository(
    ref.watch(apiEndpointsProvider),
    ref.watch(activeCourseProvider),
  );
});

/// Listen/Speak typed exercises for [kind] from the server bundle when API
/// mode is on; mock mode and offline fall back to the local fixtures.
final practiceExercisesProvider =
    FutureProvider.family<List<Exercise>, ExerciseKind>(
      (ref, kind) =>
          ref.watch(practiceContentRepositoryProvider).practiceExercises(kind),
    );

/// Due/mistake review index (`GET /v1/review`); empty in mock mode.
final practiceReviewProvider = FutureProvider<List<PracticeReviewItem>>(
  (ref) => ref.watch(practiceContentRepositoryProvider).reviewItems(),
);

final activityProgressRepositoryProvider =
    Provider<ActivityProgressRepository>((ref) {
      final config = ref.watch(appConfigProvider);
      final user = ref.watch(practiceAccountProvider);
      if (!config.isApi || user == null || user.guest) {
        return const MockActivityProgressRepository();
      }
      return ApiActivityProgressRepository(
        ref.watch(apiEndpointsProvider),
        ref.watch(activeCourseProvider),
      );
    });

/// Library progress for one activity kind (`STORY`, `RADIO`, ...); null lists
/// every kind.
final activityProgressProvider =
    FutureProvider.family<List<ActivityProgressEntry>, String?>(
      (ref, kind) =>
          ref.watch(activityProgressRepositoryProvider).load(kind: kind),
    );
