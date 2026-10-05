import 'dart:async';

import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer containerFor(FakeAuthRepository repository) =>
    ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );

void main() {
  test('Back after sign-in returns to the saved account chooser', () async {
    final repository = FakeAuthRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    controller.showDetails(email: 'learner@example.com');
    controller.updatePassword('twelve-character-password');
    await controller.signIn();

    expect(controller.back(), true);
    final state = container.read(authControllerProvider);
    expect(state.stage, AuthStage.choice);
    expect(state.remembered?.id, 'verified-id');
    expect(state.password, isEmpty);
  });

  test(
    'local validation blocks invalid sign-in, recovery, and reset calls',
    () async {
      final repository = FakeAuthRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);

      controller.showDetails();
      await controller.signIn();
      controller.showForgot();
      controller.updateEmail('not-an-email');
      await controller.recover();
      controller.showReset('', '');
      controller.updateNewPassword('short');
      controller.updateConfirmPassword('different');
      await controller.reset();

      expect(repository.signInCalls, 0);
      expect(repository.recoveryCalls, 0);
      expect(repository.resetCalls, 0);
      expect(container.read(authControllerProvider).error, isNotNull);
    },
  );

  test(
    'busy sign-in blocks duplicate commands and accepts only verified user',
    () async {
      final repository = FakeAuthRepository()
        ..signInCompleter = Completer<AuthUser>();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      controller.showDetails(email: 'learner@example.com');
      controller.updatePassword('twelve-character-password');

      final first = controller.signIn();
      final duplicate = controller.signIn();
      expect(container.read(authControllerProvider).stage, AuthStage.busy);
      expect(container.read(authControllerProvider).busy, true);
      expect(repository.signInCalls, 1);

      const user = AuthUser(
        id: 'verified-id',
        email: 'learner@example.com',
        name: 'Learner',
      );
      repository.signInCompleter!.complete(user);
      await Future.wait([first, duplicate]);
      final state = container.read(authControllerProvider);
      expect(state.stage, AuthStage.signedIn);
      expect(state.user, user);
      expect(state.remembered, user);
      expect(state.password, isEmpty);
    },
  );

  test(
    'sign-in failure restores details and preserves entered credentials',
    () async {
      final repository = FakeAuthRepository()
        ..signInError = const AuthFailure('Safe error');
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      controller.showDetails(email: 'learner@example.com');
      controller.updatePassword('kept-password');

      await controller.signIn();

      final state = container.read(authControllerProvider);
      expect(state.stage, AuthStage.details);
      expect(state.email, 'learner@example.com');
      expect(state.password, 'kept-password');
      expect(state.error, 'Safe error');
    },
  );

  test('failed recovery does not show the success sheet', () async {
    final repository = FakeAuthRepository()
      ..recoveryError = const AuthFailure('Try again');
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    controller.showForgot();
    controller.updateEmail('learner@example.com');

    await controller.recover();

    final state = container.read(authControllerProvider);
    expect(state.recoverySent, false);
    expect(state.email, 'learner@example.com');
    expect(state.error, 'Try again');
  });

  test(
    'reset requires link arguments and clears passwords only after success',
    () async {
      final repository = FakeAuthRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      controller.showReset('user-id', 'recovery-secret');
      controller.updateNewPassword('new-password-123');
      controller.updateConfirmPassword('new-password-123');

      await controller.reset();

      expect(repository.resetCalls, 1);
      expect(repository.lastResetUserId, 'user-id');
      expect(repository.lastResetSecret, 'recovery-secret');
      final state = container.read(authControllerProvider);
      expect(state.resetComplete, true);
      expect(state.newPassword, isEmpty);
      expect(state.confirmPassword, isEmpty);
      expect(state.stage, AuthStage.reset);
    },
  );

  test(
    'initialize loads remembered metadata and ignores callbacks after disposal',
    () async {
      const remembered = AuthUser(
        id: 'remembered-id',
        email: 'old@example.com',
        name: 'Old',
      );
      final repository = FakeAuthRepository()
        ..remembered = remembered
        ..restoreCompleter = Completer<AuthUser?>();
      final container = containerFor(repository);
      final controller = container.read(authControllerProvider.notifier);

      final initialize = controller.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider).remembered, remembered);
      container.dispose();
      repository.restoreCompleter!.complete(
        const AuthUser(
          id: 'session-id',
          email: 'session@example.com',
          name: 'Session',
        ),
      );

      await expectLater(initialize, completes);
    },
  );

  test(
    'a user command supersedes initialization without leaving it stuck',
    () async {
      final repository = FakeAuthRepository()
        ..restoreCompleter = Completer<AuthUser?>();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);

      final firstInitialize = controller.initialize();
      await Future<void>.delayed(Duration.zero);
      await controller.social(AuthProvider.google);
      repository.restoreCompleter!.complete(null);
      await firstInitialize;

      repository.restoreCompleter = Completer<AuthUser?>();
      final secondInitialize = controller.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(repository.restoreCalls, 2);
      repository.restoreCompleter!.complete(null);
      await secondInitialize;
    },
  );

  test('default debug repository exposes all mock providers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(authRepositoryProvider), returnsNormally);
    expect(
      container.read(authAvailableProvidersProvider),
      AuthProvider.values.toSet(),
    );
  });

  test('selecting any account clears the prior password', () async {
    final repository = FakeAuthRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    controller.showDetails(email: 'learner@example.com');
    controller.updatePassword('private-password');

    controller.showChoice();
    controller.showDetails(email: 'learner@example.com');
    expect(container.read(authControllerProvider).password, isEmpty);

    controller.updatePassword('second-private-password');
    await controller.forgetRemembered();
    expect(container.read(authControllerProvider).password, isEmpty);
  });

  test(
    'reset stays on its stage and blocks Back and edits while pending',
    () async {
      final repository = FakeAuthRepository()
        ..resetCompleter = Completer<void>();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      controller.showReset('user-id', 'secret');
      controller.updateNewPassword('new-password-123');
      controller.updateConfirmPassword('new-password-123');

      final reset = controller.reset();
      expect(container.read(authControllerProvider).stage, AuthStage.reset);
      expect(container.read(authControllerProvider).busy, true);
      expect(controller.back(), true);
      controller.updateNewPassword('changed-while-busy');
      expect(
        container.read(authControllerProvider).newPassword,
        'new-password-123',
      );
      expect(repository.resetCalls, 1);

      repository.resetCompleter!.complete();
      await reset;
      final state = container.read(authControllerProvider);
      expect(state.busy, false);
      expect(state.resetComplete, true);
      expect(state.newPassword, isEmpty);
    },
  );

  test('recovery failure clears busy and keeps entered email', () async {
    final repository = FakeAuthRepository()
      ..recoveryCompleter = Completer<void>();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    controller.showForgot();
    controller.updateEmail('learner@example.com');

    final recovery = controller.recover();
    expect(container.read(authControllerProvider).stage, AuthStage.forgot);
    expect(container.read(authControllerProvider).busy, true);
    repository.recoveryCompleter!.completeError(const AuthFailure('Try later'));
    await recovery;

    final state = container.read(authControllerProvider);
    expect(state.busy, false);
    expect(state.email, 'learner@example.com');
    expect(state.recoverySent, false);
    expect(state.error, 'Try later');
  });

  test(
    'remembered metadata failure does not block verified session restore',
    () async {
      const session = AuthUser(
        id: 'session-id',
        email: 'session@example.com',
        name: 'Session',
      );
      final repository = FakeAuthRepository()
        ..rememberedError = const AuthFailure('Storage unavailable')
        ..restored = session;
      final container = containerFor(repository);
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).initialize();

      final state = container.read(authControllerProvider);
      expect(repository.restoreCalls, 1);
      expect(state.stage, AuthStage.signedIn);
      expect(state.user, session);
      expect(state.error, isNull);
    },
  );
}

class FakeAuthRepository implements AuthRepository {
  int signInCalls = 0;
  int recoveryCalls = 0;
  int resetCalls = 0;
  int socialCalls = 0;
  int restoreCalls = 0;
  AuthFailure? signInError;
  AuthFailure? recoveryError;
  AuthFailure? resetError;
  AuthFailure? rememberedError;
  Completer<AuthUser>? signInCompleter;
  Completer<AuthUser?>? restoreCompleter;
  Completer<void>? recoveryCompleter;
  Completer<void>? resetCompleter;
  AuthUser? remembered;
  AuthUser? restored;
  String? lastResetUserId;
  String? lastResetSecret;

  @override
  Future<void> forgetAccount() async => remembered = null;

  @override
  Future<AuthUser?> rememberedAccount() async {
    if (rememberedError case final error?) throw error;
    return remembered;
  }

  @override
  Future<void> sendRecovery(String email) async {
    recoveryCalls++;
    if (recoveryError case final error?) throw error;
    if (recoveryCompleter case final completer?) return completer.future;
  }

  @override
  Future<AuthUser> signIn(String email, String password) async {
    signInCalls++;
    if (signInError case final error?) throw error;
    if (signInCompleter case final completer?) return completer.future;
    return AuthUser(id: 'verified-id', email: email, name: 'Learner');
  }

  @override
  Future<AuthUser> socialSignIn(AuthProvider provider) async {
    socialCalls++;
    return const AuthUser(
      id: 'social-id',
      email: 'social@example.com',
      name: 'Social',
    );
  }

  @override
  Future<AuthUser?> restoreSession() async {
    restoreCalls++;
    if (restoreCompleter case final completer?) return completer.future;
    return restored;
  }

  @override
  Future<void> resetPassword(
    String userId,
    String secret,
    String password,
  ) async {
    resetCalls++;
    lastResetUserId = userId;
    lastResetSecret = secret;
    if (resetError case final error?) throw error;
    if (resetCompleter case final completer?) return completer.future;
  }
}
