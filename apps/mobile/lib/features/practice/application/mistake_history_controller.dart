import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../data/mistake_history_repository.dart';

class MistakePreferencesStore implements SnapshotStore, HistoryStorageStatus {
  MistakePreferencesStore(this.namespace);
  final String namespace;
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();
  final _temporary = MemorySnapshotStore();
  bool _unsupported = false;
  @override
  String? get warning => _unsupported
      ? 'History is temporary on this platform because local storage is unavailable.'
      : null;
  @override
  Future<String?> read(String key) async {
    if (_unsupported) return _temporary.read(key);
    try {
      return await _prefs.getString('mistakes.v1.$namespace.$key');
    } on MissingPluginException {
      _unsupported = true;
      return _temporary.read(key);
    } on StateError catch (error) {
      if (error.message !=
          'The SharedPreferencesAsyncPlatform instance must be set.') {
        rethrow;
      }
      _unsupported = true;
      return _temporary.read(key);
    }
  }

  @override
  Future<void> write(String key, String value) async {
    if (_unsupported) return _temporary.write(key, value);
    try {
      await _prefs.setString('mistakes.v1.$namespace.$key', value);
    } on MissingPluginException {
      _unsupported = true;
      await _temporary.write(key, value);
    } on StateError catch (error) {
      if (error.message !=
          'The SharedPreferencesAsyncPlatform instance must be set.') {
        rethrow;
      }
      _unsupported = true;
      await _temporary.write(key, value);
    }
  }
}

final mistakeStoreProvider = Provider.family<SnapshotStore, String>(
  (ref, key) => MistakePreferencesStore(key),
);
final localMistakeRepositoryProvider =
    Provider.family<MistakeHistoryRepository, String>(
      (ref, key) =>
          MistakeHistoryRepository(store: ref.watch(mistakeStoreProvider(key))),
    );
final mistakeRepositoryProvider = Provider<MistakeHistoryRepository>((ref) {
  final user = ref.watch(authControllerProvider.select((s) => s.user?.id));
  final api = ref.watch(appConfigProvider).isApi;
  final key = jsonEncode([api ? 'api' : 'demo', user, 'vi_en']);
  if (!api) return ref.watch(localMistakeRepositoryProvider(key));
  var active = true;
  ref.onDispose(() => active = false);
  return MistakeHistoryRepository(
    store: ref.watch(mistakeStoreProvider(key)),
    active: () => active,
    api: api ? ref.watch(apiEndpointsProvider) : null,
    course: api ? ref.watch(activeCourseProvider).id : null,
  );
});
final mistakeHistoryProvider =
    AsyncNotifierProvider<MistakeHistoryController, MistakeHistory>(
      MistakeHistoryController.new,
    );

class MistakeHistoryController extends AsyncNotifier<MistakeHistory> {
  @override
  Future<MistakeHistory> build() => ref.watch(mistakeRepositoryProvider).load();
  void refresh() => ref.invalidateSelf();
}
