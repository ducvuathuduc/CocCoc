import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/data/progress_snapshot.dart';
import '../data/profile_editor_repository.dart';

class ProfileDetails {
  const ProfileDetails({
    required this.first,
    required this.last,
    required this.username,
    required this.email,
    this.phone = '',
    this.accountId = '',
    this.revision,
    this.loading = false,
    this.loaded = true,
    this.busy = false,
    this.error,
    this.dataVersion = 0,
  });

  final String first, last, username, email, phone;
  final String accountId;
  final int? revision;
  final bool loading, loaded, busy;
  final String? error;
  final int dataVersion;

  ProfileDetails copyWith({
    bool? loading,
    bool? loaded,
    bool? busy,
    String? error,
    bool clearError = false,
  }) => ProfileDetails(
    first: first,
    last: last,
    username: username,
    email: email,
    phone: phone,
    accountId: accountId,
    revision: revision,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
    dataVersion: dataVersion,
  );
}

final profileEditorIdentityProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authControllerProvider.select((state) => state.user));
});

final profileEditorRepositoryProvider = Provider<ProfileEditorRepository>((
  ref,
) {
  return ApiProfileEditorRepository(ref.watch(apiEndpointsProvider));
});

final profileEditorProvider =
    NotifierProvider<ProfileEditorController, ProfileDetails>(
      ProfileEditorController.new,
    );

class ProfileEditorController extends Notifier<ProfileDetails> {
  int _generation = 0;
  int _dataVersion = 0;
  bool _apiMode = false;
  bool _saving = false;
  AuthUser? _identity;
  ProfileEditorRepository? _repository;
  ProfileDetails? _baseline;

  @override
  ProfileDetails build() {
    _apiMode = ref.watch(appConfigProvider).isApi;
    final generation = ++_generation;
    _saving = false;
    _baseline = null;
    if (!_apiMode) return _mockDetails();

    final identity = ref.watch(profileEditorIdentityProvider);
    _identity = identity;
    if (identity == null) {
      return ProfileDetails(
        first: '',
        last: '',
        username: '',
        email: '',
        loaded: false,
        error: 'Sign in to edit your profile.',
        dataVersion: ++_dataVersion,
      );
    }
    final repository = ref.watch(profileEditorRepositoryProvider);
    _repository = repository;
    final initial = _details(
      identity: identity,
      nickname: identity.name,
      revision: null,
      loading: true,
      loaded: false,
    );
    Future<void>(() => _load(repository, identity, generation));
    return initial;
  }

  ProfileDetails _mockDetails() {
    final preview = ref.read(previewControllerProvider);
    final names = _splitName(preview.name);
    final details = ProfileDetails(
      first: names.$1,
      last: names.$2,
      username: preview.email.split('@').first,
      email: preview.email,
      accountId: 'mock',
      dataVersion: ++_dataVersion,
    );
    _baseline = details;
    return details;
  }

  Future<void> _load(
    ProfileEditorRepository repository,
    AuthUser identity,
    int generation,
  ) async {
    try {
      final record = await repository.load(identity.id);
      if (!_current(repository, identity, generation)) return;
      if (record.userId != identity.id) {
        throw const _ProfileEditorFailure('Profile identity mismatch.');
      }
      final details = _details(
        identity: identity,
        nickname: record.nickname.isEmpty ? identity.name : record.nickname,
        revision: record.revision,
        loaded: true,
      );
      _baseline = details;
      state = details;
    } on Object catch (error) {
      if (!_current(repository, identity, generation)) return;
      state = state.copyWith(
        loading: false,
        loaded: false,
        busy: false,
        error: _message(error),
      );
    }
  }

  Future<void> retry() async {
    if (!_apiMode || state.loading || state.busy) return;
    final repository = _repository;
    final identity = _identity;
    if (repository == null || identity == null) return;
    state = state.copyWith(loading: true, clearError: true);
    await _load(repository, identity, _generation);
  }

  Future<String?> save(ProfileDetails draft) async {
    if (!_apiMode) return _saveMock(draft);
    if (_saving) return 'A save is already in progress.';
    if (!state.loaded || state.revision == null) {
      return state.error ?? 'Profile is still loading. Please try again.';
    }
    final baseline = _baseline!;
    final first = draft.first.trim();
    final last = draft.last.trim();
    final username = draft.username.trim();
    final email = draft.email.trim();
    final phone = draft.phone.trim();
    if (username != baseline.username) {
      return 'Username changes aren’t supported yet.';
    }
    if (email != baseline.email) {
      return 'Email changes aren’t supported here.';
    }
    if (phone != baseline.phone) {
      return 'Phone number changes aren’t supported here.';
    }
    final nickname = [first, last].where((part) => part.isNotEmpty).join(' ');
    if (first.isEmpty || nickname.length > 40) {
      return 'Use a name of up to 40 characters.';
    }
    if (nickname == [baseline.first, baseline.last].join(' ').trim()) {
      return null;
    }

    final repository = _repository!;
    final identity = _identity!;
    final generation = _generation;
    _saving = true;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final record = await repository.updateNickname(
        userId: identity.id,
        nickname: nickname,
        expectedRevision: state.revision!,
      );
      if (!_current(repository, identity, generation)) {
        return 'Profile changed. Please try again.';
      }
      if (record.userId != identity.id) {
        throw const _ProfileEditorFailure('Profile identity mismatch.');
      }
      final details = _details(
        identity: identity,
        nickname: record.nickname,
        revision: record.revision,
        loaded: true,
      );
      _baseline = details;
      state = details;
      ref.invalidate(progressSnapshotSourceProvider);
      return null;
    } on Object catch (error) {
      final message = _message(error);
      if (_current(repository, identity, generation)) {
        state = state.copyWith(busy: false, error: message);
      }
      return message;
    } finally {
      if (_current(repository, identity, generation)) _saving = false;
    }
  }

  String? _saveMock(ProfileDetails draft) {
    final first = draft.first.trim();
    final last = draft.last.trim();
    final username = draft.username.trim();
    final phone = draft.phone.trim();
    if (first.isEmpty || first.length > 60 || last.length > 60) {
      return 'Enter a first and last name of up to 60 characters.';
    }
    final fullName = [first, last].where((part) => part.isNotEmpty).join(' ');
    if (fullName.length > 60) return 'Use a full name of up to 60 characters.';
    if (!RegExp(r'^[A-Za-z0-9._]{3,30}$').hasMatch(username)) {
      return 'Use 3–30 letters, numbers, periods or underscores for your username.';
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (phone.isNotEmpty &&
        (digits < 6 ||
            digits > 15 ||
            !RegExp(r'^\+?[0-9 ()-]{6,25}$').hasMatch(phone))) {
      return 'Enter a valid phone number.';
    }
    final error = ref
        .read(previewControllerProvider.notifier)
        .saveProfile(fullName, draft.email);
    if (error != null) return error;
    final details = ProfileDetails(
      first: first,
      last: last,
      username: username,
      email: draft.email.trim(),
      phone: phone,
      accountId: 'mock',
      dataVersion: ++_dataVersion,
    );
    _baseline = details;
    state = details;
    return null;
  }

  ProfileDetails _details({
    required AuthUser identity,
    required String nickname,
    required int? revision,
    bool loading = false,
    bool loaded = false,
  }) {
    final names = _splitName(nickname);
    return ProfileDetails(
      first: names.$1,
      last: names.$2,
      username: '',
      email: identity.email,
      accountId: identity.id,
      revision: revision,
      loading: loading,
      loaded: loaded,
      dataVersion: ++_dataVersion,
    );
  }

  bool _current(
    ProfileEditorRepository repository,
    AuthUser identity,
    int generation,
  ) =>
      ref.mounted &&
      generation == _generation &&
      identical(repository, _repository) &&
      identity.id == _identity?.id;

  static (String, String) _splitName(String value) {
    final names = value.trim().split(RegExp(r'\s+'));
    if (names.length == 1 && names.single.isEmpty) return ('', '');
    return (names.first, names.skip(1).join(' '));
  }

  static String _message(Object error) => switch (error) {
    ApiException api => api.userMessage,
    _ProfileEditorFailure failure => failure.message,
    _ => 'We couldn’t load or save your profile. Please try again.',
  };
}

final class _ProfileEditorFailure implements Exception {
  const _ProfileEditorFailure(this.message);
  final String message;
}
