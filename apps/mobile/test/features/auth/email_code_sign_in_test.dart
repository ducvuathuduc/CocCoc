import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/data/mock_auth_repository.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/auth/presentation/login_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Implements only the password surface: the email-code entry stays hidden.
class _PasswordOnlyAuth implements AuthRepository {
  @override
  Future<AuthUser> signIn(String email, String password) =>
      Future.error(const AuthFailure('nope'));
  @override
  Future<void> sendRecovery(String email) async {}
  @override
  Future<void> resetPassword(String id, String secret, String password) async {}
  @override
  Future<AuthUser> socialSignIn(AuthProvider provider) =>
      Future.error(const AuthFailure('nope'));
  @override
  Future<AuthUser?> restoreSession() async => null;
  @override
  Future<AuthUser?> rememberedAccount() async => null;
  @override
  Future<void> forgetAccount() async {}
}

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(delay: Duration.zero),
      ),
      authAvailableProvidersProvider.overrideWithValue(
        AuthProvider.values.toSet(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _fonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    await (FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await ReferenceArt.preload();
  });
}

void _size(WidgetTester tester, {double width = 430, double height = 932}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: referenceTheme(),
    builder: (context, child) =>
        RepaintBoundary(key: const ValueKey('golden'), child: child!),
    home: LoginFlow(initialize: false, onExit: () {}, onStart: () {}),
  ),
);

Future<void> _golden(String name) => expectLater(
  find.byKey(const ValueKey('golden')),
  matchesGoldenFile('../../goldens/ui_master/auth_email_code_${name}_430.png'),
);

Finder _button(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextButton),
);

void main() {
  group('controller', () {
    test('mock accepts 123456 and signs in with the emailed address', () async {
      final container = _container();
      final c = container.read(authControllerProvider.notifier);
      c.showEmailCode();
      c.updateEmail(' learner@example.test ');
      await c.sendEmailCode();
      var s = container.read(authControllerProvider);
      expect(s.stage, AuthStage.emailCodeVerify);
      expect(s.codeUserId, isNotEmpty);
      c.updateCode('12a34 56789');
      s = container.read(authControllerProvider);
      expect(s.code, '123456');
      await c.verifyEmailCode();
      s = container.read(authControllerProvider);
      expect(s.stage, AuthStage.signedIn);
      expect(s.user?.email, 'learner@example.test');
      expect(s.code, isEmpty);
    });

    test('wrong code stays on the code screen with a generic error', () async {
      final container = _container();
      final c = container.read(authControllerProvider.notifier);
      c.showEmailCode();
      c.updateEmail('learner@example.test');
      await c.sendEmailCode();
      c.updateCode('000000');
      await c.verifyEmailCode();
      final s = container.read(authControllerProvider);
      expect(s.stage, AuthStage.emailCodeVerify);
      expect(s.error, contains('code didn’t work'));
      expect(s.code, isEmpty);
      expect(s.user, isNull);
    });

    test('invalid email never sends; resend honours the UI cooldown', () async {
      final container = _container();
      final c = container.read(authControllerProvider.notifier);
      var now = DateTime(2026, 10, 13, 16);
      c.clock = () => now;
      c.showEmailCode();
      c.updateEmail('not-an-email');
      await c.sendEmailCode();
      expect(container.read(authControllerProvider).stage, AuthStage.emailCode);
      expect(
        container.read(authControllerProvider).error,
        'Enter a valid email address.',
      );
      c.updateEmail('learner@example.test');
      await c.sendEmailCode();
      await c.resendEmailCode();
      expect(
        container.read(authControllerProvider).error,
        contains('wait a moment'),
      );
      now = now.add(AuthController.codeResendCooldown);
      await c.resendEmailCode();
      final s = container.read(authControllerProvider);
      expect(s.error, isNull);
      expect(s.codeResent, isTrue);
      expect(s.stage, AuthStage.emailCodeVerify);
    });

    test('back walks code -> email -> details', () {
      final container = _container();
      final c = container.read(authControllerProvider.notifier);
      c.showEmailCode();
      expect(c.back(), isTrue);
      expect(container.read(authControllerProvider).stage, AuthStage.details);
    });

    test('repositories without email code expose no command', () {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_PasswordOnlyAuth()),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(authEmailCodeRepositoryProvider), isNull);
    });
  });

  group('screens', () {
    testWidgets('details offers email code only when the repository can', (
      tester,
    ) async {
      _size(tester);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_PasswordOnlyAuth()),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider.notifier).showDetails();
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-email-code-entry')), findsNothing);
    });

    testWidgets('email -> code -> signed in, with goldens', (tester) async {
      _size(tester);
      await _fonts(tester);
      final container = _container();
      container.read(authControllerProvider.notifier).showDetails();
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-email-code-entry')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with email code'), findsOneWidget);
      expect(
        tester.widget<TextButton>(_button('auth-email-code-send')).onPressed,
        isNull,
      );
      await _golden('email_empty');

      await tester.enterText(find.byType(TextField), 'samlee@example.test');
      await tester.pump();
      await tester.tap(_button('auth-email-code-send'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the 6-digit code'), findsOneWidget);
      expect(find.textContaining('samlee@example.test'), findsOneWidget);
      expect(
        tester.widget<TextButton>(_button('auth-email-code-verify')).onPressed,
        isNull,
      );
      await _golden('code_empty');

      final field = find.byKey(const ValueKey('auth-email-code-field'));
      await tester.enterText(field, '111111');
      await tester.pump();
      await tester.tap(_button('auth-email-code-verify'));
      await tester.pumpAndSettle();
      expect(find.textContaining('code didn’t work'), findsOneWidget);
      await _golden('code_error');

      await tester.enterText(field, MockAuthRepository.demoEmailCode);
      await tester.pump();
      await tester.tap(_button('auth-email-code-verify'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(
        container.read(authControllerProvider).user?.email,
        'samlee@example.test',
      );
    });

    for (final width in [360.0, 390.0]) {
      testWidgets('code screen fits width $width with text x2', (tester) async {
        _size(tester, width: width, height: 640);
        final container = _container();
        final c = container.read(authControllerProvider.notifier);
        c.showEmailCode();
        c.updateEmail('a.very.long.address+tag@example.test');
        await tester.runAsync(c.sendEmailCode);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(_app(container));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Enter the 6-digit code'), findsOneWidget);
      });
    }
  });
}
