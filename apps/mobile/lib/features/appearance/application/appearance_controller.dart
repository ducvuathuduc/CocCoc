import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appearance_repository.dart';
import '../domain/appearance_preference.dart';

final appearanceRepositoryProvider = Provider<AppearanceRepository>(
  (ref) => PreferencesAppearanceRepository(),
);

final appearanceControllerProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
      AppearanceController.new,
    );

class AppearanceController extends Notifier<AppearanceState> {
  int _revision = 0;
  Future<void> _pendingSave = Future.value();

  @override
  AppearanceState build() {
    final revision = _revision;
    unawaited(_restore(revision));
    return const AppearanceState();
  }

  Future<void> _restore(int revision) async {
    AppearancePreference preference;
    try {
      preference = await ref.read(appearanceRepositoryProvider).load();
    } catch (_) {
      preference = AppearancePreference.system;
    }
    if (!ref.mounted || revision != _revision) return;
    state = state.copyWith(preference: preference, restoring: false);
  }

  Future<bool> select(AppearancePreference preference) async {
    final revision = ++_revision;
    final repository = ref.read(appearanceRepositoryProvider);
    state = state.copyWith(
      preference: preference,
      restoring: false,
      saving: true,
      saveFailed: false,
    );
    final result = Completer<bool>();
    _pendingSave = _pendingSave.then((_) async {
      try {
        await repository.save(preference);
        result.complete(true);
      } catch (_) {
        result.complete(false);
      }
    });
    final saved = await result.future;
    if (!ref.mounted) return false;
    if (revision == _revision) {
      state = state.copyWith(saving: false, saveFailed: !saved);
    }
    return saved;
  }
}
