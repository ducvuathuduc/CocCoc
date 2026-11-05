// Friend activity feed data source (Progress social).
//
// API mode reads `GET /v1/activity`; mock mode keeps the archived feed
// fixtures untouched. The feed screen itself is not in this task's file scope,
// so this provider is the data-layer seam it can consume next.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/social_repository.dart';

final socialActivityProvider = FutureProvider<List<SocialActivity>>((
  ref,
) async {
  if (!ref.watch(appConfigProvider).isApi) return const [];
  return ref.watch(socialRepositoryProvider).activity();
});
