import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../data/api_boost_repository.dart';
import '../data/boost_repository.dart';
import '../domain/boost.dart';

final boostRepositoryProvider = Provider<BoostRepository>(
  (ref) => ref.watch(appConfigProvider).isApi
      ? ApiBoostRepository(ref.watch(apiEndpointsProvider))
      : MockBoostRepository(),
);

final boostCopyProvider = Provider(
  (ref) => ref.watch(boostRepositoryProvider).copy,
);

class BoostController extends Notifier<AsyncValue<Boost?>> {
  Future<bool>? _pending;
  @override
  AsyncValue<Boost?> build() =>
      AsyncData(ref.watch(boostRepositoryProvider).current);

  Future<bool> activate(BoostReward reward) =>
      _pending ??= _activate(reward).whenComplete(() => _pending = null);

  Future<bool> _activate(BoostReward reward) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(boostRepositoryProvider).activate(reward),
    );
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }
}

final boostControllerProvider =
    NotifierProvider<BoostController, AsyncValue<Boost?>>(BoostController.new);
