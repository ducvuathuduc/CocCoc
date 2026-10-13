import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/api_connectivity_repository.dart';
import '../data/connectivity_repository.dart';

final connectivityRepositoryProvider = Provider<ConnectivityRepository>((ref) {
  if (ref.watch(appConfigProvider).isApi) {
    final repository = ApiConnectivityRepository();
    ref.onDispose(repository.dispose);
    return repository;
  }
  final repository = MockConnectivityRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final onlineProvider = StreamProvider<bool>((ref) {
  final repository = ref.watch(connectivityRepositoryProvider);
  return repository.online;
});

final currentOnlineProvider = Provider<bool>(
  (ref) =>
      ref.watch(onlineProvider).value ??
      ref.watch(connectivityRepositoryProvider).currentOnline,
);

final connectivityCopyProvider = Provider(
  (ref) => ref.watch(connectivityRepositoryProvider).copy,
);
