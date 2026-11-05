import 'dart:async';

import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/account/application/email_verification_controller.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/auth/domain/email_verification.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/real_profile.dart';

class _Identity extends AuthController {
  @override
  AuthState build() => const AuthState(
    user: AuthUser(id: 'a', email: 'a@example.test', name: 'A'),
  );

  void switchAccount() => state = const AuthState(
    user: AuthUser(id: 'b', email: 'b@example.test', name: 'B'),
  );
}

class _NoPreview extends PreviewController {
  @override
  PreviewState build() => throw StateError('Real verification read preview');
}

EmailVerificationStatus _status({String id = 'a', bool verified = false}) =>
    EmailVerificationStatus(
      userId: id,
      email: '$id@example.test',
      verified: verified,
    );

class _Repository implements EmailVerificationRepository {
  EmailVerificationStatus value = _status();
  int reads = 0, sends = 0, confirmations = 0;
  Future<EmailVerificationStatus> Function()? read;
  Future<void> Function()? send;
  Future<EmailVerificationStatus> Function()? confirm;

  @override
  Future<EmailVerificationStatus> readEmailVerification() async {
    reads++;
    return read == null ? value : await read!();
  }

  @override
  Future<void> sendEmailVerification() async {
    sends++;
    await send?.call();
  }

  @override
  Future<EmailVerificationStatus> completeEmailVerification(
    String userId,
    String secret,
  ) async {
    confirmations++;
    return confirm == null ? value : await confirm!();
  }
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Repository repository;
  late ProviderContainer container;
  setUp(() {
    repository = _Repository();
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(realTestConfig),
        authControllerProvider.overrideWith(_Identity.new),
        emailVerificationRepositoryProvider.overrideWithValue(repository),
        previewControllerProvider.overrideWith(_NoPreview.new),
      ],
    );
  });
  tearDown(() => container.dispose());

  testWidgets('real verification never reads or verifies the preview account', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(realTestConfig),
          authControllerProvider.overrideWith(_Identity.new),
          emailVerificationRepositoryProvider.overrideWithValue(repository),
          previewControllerProvider.overrideWith(_NoPreview.new),
        ],
        child: const MaterialApp(home: VerificationScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('a@example.test'), findsOneWidget);
    expect(find.text('Email verified!'), findsNothing);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Email verified!'), findsNothing);
  });

  test('continue reads the actual verification value', () async {
    container.read(emailVerificationProvider);
    await _settle();
    final vm = container.read(emailVerificationProvider.notifier);
    await vm.refresh();
    expect(container.read(emailVerificationProvider).verified, isFalse);
    repository.value = _status(verified: true);
    await vm.refresh();
    expect(container.read(emailVerificationProvider).verified, isTrue);
    expect(repository.reads, 3);
  });

  test('resend failure never reports link ready and can retry', () async {
    container.read(emailVerificationProvider);
    await _settle();
    repository.send = () async => throw StateError('private provider detail');
    final vm = container.read(emailVerificationProvider.notifier);
    await vm.resend();
    expect(container.read(emailVerificationProvider).sent, isFalse);
    expect(container.read(emailVerificationProvider).verified, isFalse);
    expect(
      container.read(emailVerificationProvider).error,
      EmailVerificationController.unavailable,
    );
    repository.send = null;
    await vm.resend();
    expect(repository.sends, 2);
    expect(container.read(emailVerificationProvider).sent, isTrue);
    expect(container.read(emailVerificationProvider).verified, isFalse);
  });

  test('duplicate resend dispatches only one provider command', () async {
    container.read(emailVerificationProvider);
    await _settle();
    final pending = Completer<void>();
    repository.send = () => pending.future;
    final vm = container.read(emailVerificationProvider.notifier);
    final first = vm.resend();
    await vm.resend();
    expect(repository.sends, 1);
    pending.complete();
    await first;
    expect(container.read(emailVerificationProvider).sent, isTrue);
  });

  test('wrong-account read is rejected without a verified badge', () async {
    repository.value = _status(id: 'b', verified: true);
    container.read(emailVerificationProvider);
    await _settle();
    expect(container.read(emailVerificationProvider).verified, isFalse);
    expect(container.read(emailVerificationProvider).error, isNotNull);
  });

  test('late account A read cannot populate account B', () async {
    final pending = Completer<EmailVerificationStatus>();
    repository.read = () =>
        repository.reads == 1 ? pending.future : Future.value(_status(id: 'b'));
    container.read(emailVerificationProvider);
    await _settle();
    (container.read(authControllerProvider.notifier) as _Identity)
        .switchAccount();
    container.read(emailVerificationProvider);
    await _settle();
    pending.complete(_status(verified: true));
    await _settle();
    expect(container.read(emailVerificationProvider).email, 'b@example.test');
    expect(container.read(emailVerificationProvider).verified, isFalse);
  });

  test('late resend receipt cannot mark the next account sent', () async {
    container.read(emailVerificationProvider);
    await _settle();
    final pending = Completer<void>();
    repository.send = () => pending.future;
    final sending = container.read(emailVerificationProvider.notifier).resend();
    repository.value = _status(id: 'b');
    (container.read(authControllerProvider.notifier) as _Identity)
        .switchAccount();
    container.read(emailVerificationProvider);
    await _settle();
    pending.complete();
    await sending;
    expect(container.read(emailVerificationProvider).email, 'b@example.test');
    expect(container.read(emailVerificationProvider).sent, isFalse);
  });

  test('wrong-account or empty callback never reaches the SDK', () async {
    container.read(emailVerificationProvider);
    await _settle();
    final vm = container.read(emailVerificationProvider.notifier);
    await vm.completeLink('b', 'fixture-code');
    await vm.completeLink('a', '');
    expect(repository.confirmations, 0);
    expect(container.read(emailVerificationProvider).verified, isFalse);
  });

  test(
    'expired callback stays unverified and redacts provider errors',
    () async {
      container.read(emailVerificationProvider);
      await _settle();
      repository.confirm = () async =>
          throw StateError('expired private detail');
      await container
          .read(emailVerificationProvider.notifier)
          .completeLink('a', 'fixture-code');
      expect(container.read(emailVerificationProvider).verified, isFalse);
      expect(
        container.read(emailVerificationProvider).error,
        EmailVerificationController.unavailable,
      );
    },
  );

  test('callback success requires verified server readback', () async {
    container.read(emailVerificationProvider);
    await _settle();
    final vm = container.read(emailVerificationProvider.notifier);
    await vm.completeLink('a', 'fixture-code');
    expect(container.read(emailVerificationProvider).verified, isFalse);
    repository.value = _status(verified: true);
    await vm.completeLink('a', 'fixture-code');
    expect(container.read(emailVerificationProvider).verified, isTrue);
  });

  test('callback supersedes the earlier unverified refresh', () async {
    final pending = Completer<EmailVerificationStatus>();
    repository.read = () => pending.future;
    repository.confirm = () async => _status(verified: true);
    container.read(emailVerificationProvider);
    await _settle();
    await container
        .read(emailVerificationProvider.notifier)
        .completeLink('a', 'fixture-code');
    pending.complete(_status());
    await _settle();
    expect(container.read(emailVerificationProvider).verified, isTrue);
  });

  testWidgets(
    'callback consumes the link without changing the approved screen',
    (tester) async {
      repository.confirm = () async => _status(verified: true);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VerificationScreen(userId: 'a', secret: 'fixture-code'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.confirmations, 1);
      expect(find.text('Email verified!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
