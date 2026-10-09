import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/mock_auth_repository.dart';
import '../domain/auth_state.dart';
import '../services/appwrite_auth_service.dart';

final appwriteAuthServiceProvider = Provider<AppwriteAuthService>(
  (ref) => AppwriteAuthService.fromEnvironment(),
);

const useMockAuth = bool.fromEnvironment(
  'USE_MOCK_AUTH',
  defaultValue: kDebugMode,
);

final authAvailableProvidersProvider = Provider<Set<AuthProvider>>((ref) {
  if (useMockAuth) return Set.unmodifiable(AuthProvider.values);
  return ref
      .watch(appwriteAuthServiceProvider)
      .availableProviders(defaultTargetPlatform);
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => useMockAuth
      ? MockAuthRepository()
      : AppwriteAuthRepository(ref.watch(appwriteAuthServiceProvider)),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  bool _disposed = false;
  bool _commandInFlight = false;
  bool _initializing = false;
  int _revision = 0;
  AuthStage _busyReturnStage = AuthStage.details;

  @override
  AuthState build() {
    ref.onDispose(() {
      _disposed = true;
      _revision++;
    });
    return const AuthState();
  }

  Future<void> initialize() async {
    if (_initializing) return;
    _initializing = true;
    final revision = ++_revision;
    final repository = ref.read(authRepositoryProvider);
    try {
      final remembered = await repository.rememberedAccount();
      if (!_current(revision)) return;
      state = state.copyWith(
        remembered: remembered,
        clearRemembered: remembered == null,
      );
    } on Object catch (error) {
      if (!_current(revision)) return;
      state = state.copyWith(error: _message(error));
    }
    try {
      final user = await repository.restoreSession();
      if (!_current(revision)) return;
      if (user != null) {
        state = state.copyWith(
          stage: AuthStage.signedIn,
          user: user,
          remembered: user,
          busy: false,
          clearError: true,
        );
      }
    } on Object catch (error) {
      if (_current(revision)) {
        state = state.copyWith(error: _message(error));
      }
    } finally {
      if (_current(revision)) _initializing = false;
    }
  }

  void showDetails({String? email}) {
    if (state.busy) return;
    _leavePendingCommand();
    state = state.copyWith(
      stage: AuthStage.details,
      email: email ?? state.email,
      password: email == null ? state.password : '',
      busy: false,
      recoverySent: false,
      resetComplete: false,
      clearError: true,
    );
  }

  void showChoice() {
    if (state.busy) return;
    _leavePendingCommand();
    state = state.copyWith(
      stage: AuthStage.choice,
      busy: false,
      recoverySent: false,
      resetComplete: false,
      clearError: true,
    );
  }

  void showForgot() {
    if (state.busy) return;
    _leavePendingCommand();
    state = state.copyWith(
      stage: AuthStage.forgot,
      busy: false,
      recoverySent: false,
      clearError: true,
    );
  }

  void showReset(String userId, String secret) {
    if (state.busy) return;
    _leavePendingCommand();
    state = state.copyWith(
      stage: AuthStage.reset,
      recoveryUserId: userId.trim(),
      recoverySecret: secret.trim(),
      busy: false,
      resetComplete: false,
      clearError: true,
    );
  }

  bool back() {
    if (state.busy) return true;
    if (state.stage == AuthStage.choice) {
      return false;
    }
    final destination = switch (state.stage) {
      AuthStage.details => AuthStage.choice,
      AuthStage.forgot || AuthStage.reset => AuthStage.details,
      AuthStage.busy => _busyReturnStage,
      AuthStage.choice || AuthStage.signedIn => AuthStage.choice,
    };
    _leavePendingCommand();
    state = state.copyWith(stage: destination, busy: false, clearError: true);
    return true;
  }

  void updateEmail(String value) {
    if (state.busy) return;
    state = state.copyWith(email: value, clearError: true);
  }

  void updatePassword(String value) {
    if (state.busy) return;
    state = state.copyWith(password: value, clearError: true);
  }

  void updateNewPassword(String value) {
    if (state.busy) return;
    state = state.copyWith(newPassword: value, clearError: true);
  }

  void updateConfirmPassword(String value) {
    if (state.busy) return;
    state = state.copyWith(confirmPassword: value, clearError: true);
  }

  void toggleHidden() {
    if (state.busy) return;
    state = state.copyWith(hidden: !state.hidden);
  }

  void toggleConfirmHidden() {
    if (state.busy) return;
    state = state.copyWith(confirmHidden: !state.confirmHidden);
  }

  Future<void> signIn() async {
    if (_commandInFlight) return;
    if (!state.canSignIn) {
      state = state.copyWith(
        error: 'Enter your email and password to continue.',
      );
      return;
    }
    final revision = _beginCommand(AuthStage.details, showBusy: true);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(state.email.trim(), state.password);
      if (!_finishCommand(revision)) return;
      state = state.copyWith(
        stage: AuthStage.signedIn,
        user: user,
        remembered: user,
        password: '',
        busy: false,
        clearError: true,
      );
    } on Object catch (error) {
      if (!_finishCommand(revision)) return;
      state = state.copyWith(
        stage: AuthStage.details,
        busy: false,
        error: _message(error),
      );
    }
  }

  Future<void> recover() async {
    if (_commandInFlight) return;
    if (!state.canRecover) {
      state = state.copyWith(error: 'Enter a valid email address.');
      return;
    }
    final revision = _beginCommand(AuthStage.forgot);
    try {
      await ref.read(authRepositoryProvider).sendRecovery(state.email.trim());
      if (!_finishCommand(revision)) return;
      state = state.copyWith(busy: false, recoverySent: true, clearError: true);
    } on Object catch (error) {
      if (!_finishCommand(revision)) return;
      state = state.copyWith(
        busy: false,
        recoverySent: false,
        error: _message(error),
      );
    }
  }

  Future<void> reset() async {
    if (_commandInFlight) return;
    if (!state.canReset) {
      state = state.copyWith(
        error: 'Use at least 12 characters and make sure both passwords match.',
      );
      return;
    }
    final revision = _beginCommand(AuthStage.reset);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            state.recoveryUserId,
            state.recoverySecret,
            state.newPassword,
          );
      if (!_finishCommand(revision)) return;
      state = state.copyWith(
        password: '',
        newPassword: '',
        confirmPassword: '',
        busy: false,
        resetComplete: true,
        clearError: true,
      );
    } on Object catch (error) {
      if (!_finishCommand(revision)) return;
      state = state.copyWith(
        busy: false,
        resetComplete: false,
        error: _message(error),
      );
    }
  }

  Future<void> social(AuthProvider provider) async {
    if (_commandInFlight) return;
    final returnStage = state.stage == AuthStage.details
        ? AuthStage.details
        : AuthStage.choice;
    final revision = _beginCommand(returnStage, showBusy: true);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .socialSignIn(provider);
      if (!_finishCommand(revision)) return;
      state = state.copyWith(
        stage: AuthStage.signedIn,
        user: user,
        remembered: user,
        password: '',
        busy: false,
        clearError: true,
      );
    } on Object catch (error) {
      if (!_finishCommand(revision)) return;
      state = state.copyWith(
        stage: returnStage,
        busy: false,
        error: _message(error),
      );
    }
  }

  Future<void> forgetRemembered() async {
    if (_commandInFlight) return;
    final revision = _beginCommand(state.stage);
    try {
      await ref.read(authRepositoryProvider).forgetAccount();
      if (!_finishCommand(revision)) return;
      state = state.copyWith(
        password: '',
        busy: false,
        clearRemembered: true,
        clearError: true,
      );
    } on Object catch (error) {
      if (!_finishCommand(revision)) return;
      state = state.copyWith(busy: false, error: _message(error));
    }
  }

  void dismissRecovery() {
    _leavePendingCommand();
    state = state.copyWith(
      stage: AuthStage.details,
      recoverySent: false,
      clearError: true,
    );
  }

  void dismissReset() {
    _leavePendingCommand();
    state = state.copyWith(
      stage: AuthStage.details,
      recoveryUserId: '',
      recoverySecret: '',
      resetComplete: false,
      clearError: true,
    );
  }

  int _beginCommand(AuthStage returnStage, {bool showBusy = false}) {
    _initializing = false;
    _commandInFlight = true;
    _busyReturnStage = returnStage;
    final revision = ++_revision;
    if (showBusy) {
      state = state.copyWith(
        stage: AuthStage.busy,
        busy: true,
        clearError: true,
      );
    } else {
      state = state.copyWith(busy: true, clearError: true);
    }
    return revision;
  }

  bool _finishCommand(int revision) {
    if (!_current(revision)) return false;
    _commandInFlight = false;
    return true;
  }

  void _leavePendingCommand() {
    _revision++;
    _commandInFlight = false;
    _initializing = false;
  }

  bool _current(int revision) => !_disposed && revision == _revision;

  String _message(Object error) => error is AuthFailure
      ? error.message
      : 'We couldn’t complete that request. Please try again.';
}
