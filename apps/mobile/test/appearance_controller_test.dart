import 'dart:async';

import 'package:cocenglish/features/appearance/application/appearance_controller.dart';
import 'package:cocenglish/features/appearance/data/appearance_repository.dart';
import 'package:cocenglish/features/appearance/domain/appearance_preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AppearanceStore implements AppearanceRepository {
  _AppearanceStore({this.value = AppearancePreference.system});
  AppearancePreference value;
  Completer<AppearancePreference>? pendingLoad;

  @override
  Future<AppearancePreference> load() =>
      pendingLoad?.future ?? Future.value(value);

  @override
  Future<void> save(AppearancePreference preference) async {
    value = preference;
  }
}

class _SerialStore implements AppearanceRepository {
  final calls = <AppearancePreference>[];
  final writes = <Completer<void>>[];
  AppearancePreference? persisted;

  @override
  Future<AppearancePreference> load() async => AppearancePreference.system;

  @override
  Future<void> save(AppearancePreference preference) {
    calls.add(preference);
    final write = Completer<void>();
    writes.add(write);
    return write.future.then((_) => persisted = preference);
  }
}

class _FailingStore implements AppearanceRepository {
  @override
  Future<AppearancePreference> load() async => AppearancePreference.system;

  @override
  Future<void> save(AppearancePreference preference) =>
      Future.error(StateError('disk full'));
}

void main() {
  test('restores persisted preference and exposes its ThemeMode', () async {
    final store = _AppearanceStore(value: AppearancePreference.dark);
    final container = ProviderContainer(
      overrides: [appearanceRepositoryProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(appearanceControllerProvider).themeMode,
      ThemeMode.system,
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(appearanceControllerProvider).themeMode,
      ThemeMode.dark,
    );
    await container
        .read(appearanceControllerProvider.notifier)
        .select(AppearancePreference.light);

    expect(
      container.read(appearanceControllerProvider).themeMode,
      ThemeMode.light,
    );
    expect(store.value, AppearancePreference.light);
  });

  test('late restore cannot overwrite a user selection', () async {
    final store = _AppearanceStore()..pendingLoad = Completer();
    final container = ProviderContainer(
      overrides: [appearanceRepositoryProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container.read(appearanceControllerProvider);

    await container
        .read(appearanceControllerProvider.notifier)
        .select(AppearancePreference.dark);
    store.pendingLoad!.complete(AppearancePreference.light);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(appearanceControllerProvider).preference,
      AppearancePreference.dark,
    );
  });

  test('late restore after disposal does not write controller state', () async {
    final store = _AppearanceStore()..pendingLoad = Completer();
    final container = ProviderContainer(
      overrides: [appearanceRepositoryProvider.overrideWithValue(store)],
    );
    container.read(appearanceControllerProvider);
    container.dispose();

    store.pendingLoad!.complete(AppearancePreference.dark);
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'overlapping selections serialize writes so last intent persists',
    () async {
      final store = _SerialStore();
      final container = ProviderContainer(
        overrides: [appearanceRepositoryProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      container.read(appearanceControllerProvider);
      await Future<void>.delayed(Duration.zero);

      final dark = container
          .read(appearanceControllerProvider.notifier)
          .select(AppearancePreference.dark);
      final light = container
          .read(appearanceControllerProvider.notifier)
          .select(AppearancePreference.light);
      await Future<void>.delayed(Duration.zero);
      expect(store.calls, [AppearancePreference.dark]);

      store.writes.first.complete();
      await dark;
      await Future<void>.delayed(Duration.zero);
      expect(store.calls, [
        AppearancePreference.dark,
        AppearancePreference.light,
      ]);
      store.writes.last.complete();
      expect(await light, isTrue);
      expect(store.persisted, AppearancePreference.light);
      expect(container.read(appearanceControllerProvider).saving, isFalse);
    },
  );

  test('save failure preserves selection and reports it as unsaved', () async {
    final container = ProviderContainer(
      overrides: [
        appearanceRepositoryProvider.overrideWithValue(_FailingStore()),
      ],
    );
    addTearDown(container.dispose);
    container.read(appearanceControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final saved = await container
        .read(appearanceControllerProvider.notifier)
        .select(AppearancePreference.dark);

    expect(saved, isFalse);
    expect(
      container.read(appearanceControllerProvider).preference,
      AppearancePreference.dark,
    );
    expect(container.read(appearanceControllerProvider).saving, isFalse);
    expect(container.read(appearanceControllerProvider).saveFailed, isTrue);
  });
}
