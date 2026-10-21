import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/api/client/active_course.dart';
import '../../../core/config/app_config.dart';
import '../../../core/api/api_contracts.dart' as wire;
import '../../auth/application/auth_controller.dart';
import '../../learning/data/path_repository.dart';
import '../data/real_learning_session_repository.dart';

final authStartupProvider = FutureProvider<void>((ref) async {
  if (ref.watch(appConfigProvider).isApi) {
    await ref.read(authControllerProvider.notifier).initialize();
  }
});
final realLearningSessionRepositoryProvider =
    Provider<RealLearningSessionRepository>(
      (ref) => RealLearningSessionRepository(
        ref.watch(apiEndpointsProvider),
        ref.watch(activeCourseProvider),
      ),
    );
final realLearningSessionProvider = FutureProvider<PreparedLearningSession?>((
  ref,
) async {
  if (!ref.watch(appConfigProvider).isApi) return null;
  final user = ref.watch(authControllerProvider.select((s) => s.user));
  if (user == null) return null;
  final result = await ref
      .watch(realLearningSessionRepositoryProvider)
      .prepare(user.id, user.name);
  if (!ref.mounted) return null;
  final path = ref.read(pathRepositoryProvider);
  if (path is ApiPathRepository) path.cache.put(result.paths);
  return result;
});

final realRewardsProvider = FutureProvider.family<wire.Rewards?, String?>((
  ref,
  userId,
) async {
  if (!ref.watch(appConfigProvider).isApi ||
      userId == null ||
      ref.watch(authControllerProvider.select((s) => s.user?.id)) != userId) {
    return null;
  }
  return ref.watch(apiEndpointsProvider).getRewards();
});

/// Pure route policy. The root router applies it to all protected routes.
String? realLearningRedirect({
  required String path,
  required bool api,
  required bool restoring,
  required bool signedIn,
  required bool ready,
}) {
  if (!api) return null;
  if (path == '/onboarding') return signedIn ? '/home' : '/auth/register';
  final public = {
    '/welcome',
    '/login',
    '/auth/login',
    '/reset-password',
    '/auth/register',
  };
  if (public.contains(path)) return null;
  if (restoring) return path == '/connecting' ? null : '/connecting';
  if (!signedIn) return '/login';
  if (!ready) return path == '/connecting' ? null : '/connecting';
  if (path == '/onboarding/demo' ||
      path == '/placement' ||
      path == '/auth/verify') {
    return '/home';
  }
  return path == '/connecting' ? '/home' : null;
}
