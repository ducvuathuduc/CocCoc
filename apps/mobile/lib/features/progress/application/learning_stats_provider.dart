import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_providers.dart';
import '../../auth/application/auth_controller.dart';

/// Discarded on logout/account switch; never persists another user's history.
final learningStatsProvider = FutureProvider.autoDispose<wire.LearningStats>((
  ref,
) async {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) throw StateError('Sign in to view learning statistics.');
  return ref.watch(apiEndpointsProvider).getLearningStats();
});
