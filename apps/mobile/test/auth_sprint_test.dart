import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/core/ui/duo_form.dart';
import 'package:cocenglish/features/account/application/delete_account_controller.dart';
import 'package:cocenglish/features/account/application/registration_controller.dart';
import 'package:cocenglish/features/account/data/account_repository.dart';
import 'package:cocenglish/features/account/presentation/delete_account_screen.dart';
import 'package:cocenglish/features/account/presentation/signup_flow.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/auth/presentation/login_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingAuth implements AuthRepository {
  @override
  Future<AuthUser> signIn(String email, String password) =>
      Future.error(const AuthFailure('Wrong password. Please try again.'));
  @override
  Future<void> sendRecovery(String email) async {}
  @override
  Future<void> resetPassword(String id, String secret, String password) async {}
  @override
  Future<AuthUser> socialSignIn(AuthProvider provider) async =>
      throw const AuthFailure('Provider unavailable.');
  @override
  Future<AuthUser?> restoreSession() async => null;
  @override
  Future<AuthUser?> rememberedAccount() async => null;
  @override
  Future<void> forgetAccount() async {}
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
    await ReferenceArt.preloadFiles([
      'login-03',
      'signup-01',
      'signup-15',
      'delete-06',
    ]);
  });
}

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  Widget home, {
  ProviderContainer? container,
  bool reduceMotion = false,
}) {
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: referenceTheme(),
    builder: (context, child) => RepaintBoundary(
      key: const ValueKey('golden'),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
    home: home,
  );
  return container == null
      ? ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(_FailingAuth())],
          child: app,
        )
      : UncontrolledProviderScope(container: container, child: app);
}

Future<void> _golden(String name) => expectLater(
  find.byKey(const ValueKey('golden')),
  matchesGoldenFile('goldens/ui_master/sprint_auth_${name}_430.png'),
);

void main() {
  group('login', () {
    testWidgets('details: sign in enables, wrong password shakes + errors', (
      tester,
    ) async {
      _size(tester);
      await _fonts(tester);
      await tester.pumpWidget(
        _app(LoginFlow(initialize: false, onExit: () {}, onStart: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your details'), findsOneWidget);
      expect(find.text('SIGN IN WITH GOOGLE'), findsOneWidget);
      await _golden('login_empty');
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'samlee@example.test');
      await tester.enterText(fields.at(1), 'wrong-password');
      await tester.pump();
      await tester.tap(find.text('SIGN IN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DuoShake), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Wrong password. Please try again.'), findsOneWidget);
      await _golden('login_error');
    });
  });

  group('signup', () {
    testWidgets('prompt shows create profile + later', (tester) async {
      _size(tester);
      await _fonts(tester);
      var created = false;
      await tester.pumpWidget(
        _app(
          CreateProfilePromptScreen(
            onCreate: () => created = true,
            onLater: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LATER'), findsOneWidget);
      await _golden('signup_prompt');
      await tester.tap(find.text('CREATE PROFILE'));
      expect(created, isTrue);
    });

    testWidgets('age → name → email error/suggestion → password → welcome', (
      tester,
    ) async {
      _size(tester);
      await _fonts(tester);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(const RegistrationScreen(), container: c));
      await tester.pumpAndSettle();
      expect(find.text('How old are you?'), findsOneWidget);
      await _golden('signup_age_empty');
      await tester.enterText(find.byKey(const ValueKey('register-age')), '25');
      await tester.pump();
      expect(find.byKey(const ValueKey('register-age-valid')), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('What is your name?'), findsOneWidget);
      expect(find.text('SIGN UP WITH APPLE'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('register-first')),
        'Sam',
      );
      await tester.enterText(
        find.byKey(const ValueKey('register-last')),
        'Lee',
      );
      await tester.pump();
      await _golden('signup_name');
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('What is your email address, Sam Lee?'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('register-email')),
        'samlee.mobbin+4@gmail.c',
      );
      await tester.pump();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid email address'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('register-email-invalid')),
        findsOneWidget,
      );
      expect(find.text('samlee.mobbin+4@gmail.com'), findsOneWidget);
      await _golden('signup_email_error');
      await tester.tap(find.byKey(const ValueKey('register-email-suggestion')));
      await tester.pump();
      expect(c.read(registrationControllerProvider).email, endsWith('.com'));
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Create a password'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('register-password')),
        'long-demo-password',
      );
      await tester.pump();
      await tester.tap(find.text('CREATE PROFILE'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Welcome, Sam Lee! Your profile has been successfully created.',
        ),
        findsOneWidget,
      );
      await _golden('signup_welcome');
    });

    testWidgets('reduced motion pumps through steps without exceptions', (
      tester,
    ) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _app(const RegistrationScreen(), container: c, reduceMotion: true),
      );
      await tester.enterText(find.byKey(const ValueKey('register-age')), '0');
      await tester.pump();
      await tester.tap(find.text('NEXT'));
      await tester.pump();
      expect(find.text('Enter an age between 1 and 120.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('register-age')), '30');
      await tester.pump();
      await tester.tap(find.text('NEXT'));
      await tester.pump();
      expect(find.text('What is your name?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('repository is swappable via provider override', () async {
      final c = ProviderContainer(
        overrides: [
          accountRepositoryProvider.overrideWithValue(
            MockAccountRepository(
              onRegister: (_, _) => 'Email taken',
              onDelete: () {},
              latency: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      final vm = c.read(registrationControllerProvider.notifier);
      vm.edit(age: '25');
      await vm.next();
      vm.edit(first: 'Sam');
      await vm.next();
      vm.edit(email: 'sam@example.test');
      await vm.next();
      vm.edit(password: 'long-demo-password');
      await vm.next();
      final s = c.read(registrationControllerProvider);
      expect(s.step, 3);
      expect(s.error, 'Email taken');
      expect(s.errorTick, 1);
    });
  });

  group('delete account', () {
    testWidgets('countdown locks action, sheet confirms, receipt shows', (
      tester,
    ) async {
      _size(tester);
      await _fonts(tester);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(const DeleteAccountScreen(), container: c));
      await tester.pump();
      expect(find.text('DELETE ACCOUNT (5)'), findsOneWidget);
      await _golden('delete_countdown');
      await tester.tap(find.byKey(const ValueKey('delete-action')));
      await tester.pump();
      expect(find.byKey(const ValueKey('delete-confirm-sheet')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('DELETE ACCOUNT (3)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('DELETE ACCOUNT'), findsOneWidget);
      expect(c.read(deleteAccountControllerProvider).canDelete, isTrue);
      await tester.tap(find.byKey(const ValueKey('delete-action')));
      await tester.pumpAndSettle();
      expect(find.text('Do you wish to delete your account?'), findsOneWidget);
      await _golden('delete_sheet');
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      await _golden('delete_done');
    });

    testWidgets('cancel keeps account; reduced motion sheet', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _app(const DeleteAccountScreen(), container: c, reduceMotion: true),
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.tap(find.byKey(const ValueKey('delete-action')));
      await tester.pump();
      await tester.pump();
      expect(find.text('CANCEL'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Check your email'), findsNothing);
      expect(c.read(deletionRequestedProvider), isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
