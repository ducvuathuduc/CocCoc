import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/data/progress_snapshot.dart';

class AccountPreferencesState {
  const AccountPreferencesState({
    this.preferences,
    this.profile,
    this.loading = false,
    this.busy = false,
    this.error,
  });

  final wire.Preferences? preferences;
  final wire.Profile? profile;
  final bool loading, busy;
  final String? error;
  bool get ready => preferences != null && profile != null && !loading;

  AccountPreferencesState copyWith({
    wire.Preferences? preferences,
    wire.Profile? profile,
    bool? loading,
    bool? busy,
    String? error,
  }) => AccountPreferencesState(
    preferences: preferences ?? this.preferences,
    profile: profile ?? this.profile,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    error: error,
  );
}

enum _Setting { sound, privateProfile }

class _PendingSetting {
  const _PendingSetting(this.setting, this.value, this.key, this.revision);
  final _Setting setting;
  final bool value;
  final String key;
  final int revision;
}

final accountPreferencesProvider =
    NotifierProvider<AccountPreferencesController, AccountPreferencesState>(
      AccountPreferencesController.new,
    );

/// Default-preview sound remains local. Real effects use the accepted server
/// preference; unavailable configuration never enables them using a fixture.
final soundEffectsEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(appConfigProvider).isApi) {
    return ref.watch(previewControllerProvider.select((state) => state.sound));
  }
  return ref.watch(accountPreferencesProvider).preferences?.soundEffects ==
      true;
});

class AccountPreferencesController extends Notifier<AccountPreferencesState> {
  int _generation = 0;
  String? _userId;
  ApiEndpoints? _api;
  _PendingSetting? _pending;

  @override
  AccountPreferencesState build() {
    final generation = ++_generation;
    _pending = null;
    _api = null;
    _userId = null;
    if (!ref.watch(appConfigProvider).isApi) {
      return const AccountPreferencesState();
    }
    final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    _userId = userId;
    if (userId == null) {
      return const AccountPreferencesState(error: 'Please sign in again.');
    }
    final api = ref.watch(apiEndpointsProvider);
    _api = api;
    Future<void>(() => _load(api, userId, generation));
    return const AccountPreferencesState(loading: true);
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  Future<void> _load(ApiEndpoints api, String userId, int generation) async {
    try {
      final result = await Future.wait<Object>([
        api.getPreferences(),
        api.getMe(),
      ]);
      if (!_current(generation)) return;
      final profile = result[1] as wire.Profile;
      if (profile.userId != userId) {
        throw const ApiException(
          code: 'FORBIDDEN',
          message: 'Identity mismatch.',
        );
      }
      state = AccountPreferencesState(
        preferences: result[0] as wire.Preferences,
        profile: profile,
      );
    } on Object catch (error) {
      if (_current(generation)) {
        state = state.copyWith(
          loading: false,
          busy: false,
          error: _message(error),
        );
      }
    }
  }

  Future<void> retry() async {
    if (state.busy || state.loading || _api == null || _userId == null) return;
    final pending = _pending;
    if (pending != null) {
      await _perform(pending);
    } else {
      state = state.copyWith(loading: true);
      await _load(_api!, _userId!, _generation);
    }
  }

  Future<bool> setSoundEffects(bool value) => _change(_Setting.sound, value);
  Future<bool> setPrivate(bool value) =>
      _change(_Setting.privateProfile, value);

  Future<bool> _change(_Setting setting, bool value) async {
    if (!state.ready || state.busy || _api == null) return false;
    final pending = _pending;
    if (pending != null &&
        (pending.setting != setting || pending.value != value)) {
      return false;
    }
    final command = _pending ??= _PendingSetting(
      setting,
      value,
      _api!.client.ids.next(),
      setting == _Setting.sound
          ? state.preferences!.revision
          : state.profile!.revision,
    );
    return _perform(command);
  }

  Future<bool> _perform(_PendingSetting command) async {
    final api = _api!;
    final generation = _generation;
    final userId = _userId;
    state = state.copyWith(busy: true);
    try {
      switch (command.setting) {
        case _Setting.sound:
          final accepted = await api.updatePreferences(
            wire.PreferencesPatch(
              soundEffects: command.value,
              expectedRevision: command.revision,
            ),
            idempotencyKey: command.key,
          );
          if (!_current(generation)) return false;
          state = state.copyWith(preferences: accepted, busy: false);
        case _Setting.privateProfile:
          final accepted = await api.updateMe(
            wire.ProfilePatch(
              publicOptIn: !command.value,
              expectedRevision: command.revision,
            ),
            idempotencyKey: command.key,
          );
          if (!_current(generation)) return false;
          if (accepted.userId != userId) {
            throw const ApiException(
              code: 'FORBIDDEN',
              message: 'Identity mismatch.',
            );
          }
          state = state.copyWith(profile: accepted, busy: false);
          ref.invalidate(progressSnapshotSourceProvider);
      }
      _pending = null;
      return true;
    } on Object catch (error) {
      if (_current(generation)) {
        if (error is ApiException &&
            !error.isOffline &&
            !error.retryable &&
            error.statusCode != 503) {
          _pending = null;
        }
        state = state.copyWith(busy: false, error: _message(error));
      }
      return false;
    }
  }

  String _message(Object error) => error is ApiException
      ? error.userMessage
      : 'We couldn’t complete that request. Please try again.';
}
