import 'dart:async';

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/auth/presentation/login_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class UiAuthRepository implements AuthRepository {
  Completer<AuthUser>? pending;
  int requests = 0;
  bool failRecovery = false;
  @override
  Future<AuthUser> signIn(String email, String password) {
    requests++;
    return pending?.future ??
        Future.error(const AuthFailure('Please try again.'));
  }

  @override
  Future<void> sendRecovery(String email) async {
    if (failRecovery) throw const AuthFailure('Please try again.');
  }

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

Future<void> open(WidgetTester tester, UiAuthRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: referenceTheme(),
        home: LoginFlow(initialize: false, onExit: () {}, onStart: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
  await tester.tap(find.text('SIGN IN'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('visibility, retry and internal Back preserve form input', (
    tester,
  ) async {
    await open(tester, UiAuthRepository());
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'SIGN IN'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).first, 'learner@example.com');
    await tester.enterText(find.byType(TextField).last, 'example-password');
    await tester.tap(find.byTooltip('Show Password'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    expect(find.text('Please try again.'), findsOneWidget);
    expect(find.text('learner@example.com'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    expect(find.text('learner@example.com'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'example-password',
    );
  });
  testWidgets('busy screen blocks duplicate and stale taps', (tester) async {
    final repository = UiAuthRepository()..pending = Completer<AuthUser>();
    await open(tester, repository);
    await tester.enterText(find.byType(TextField).first, 'learner@example.com');
    await tester.enterText(find.byType(TextField).last, 'example-password');
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();
    expect(find.text('SIGNING YOU IN…'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(repository.requests, 1);
    repository.pending!.completeError(const AuthFailure('Please try again.'));
    await tester.pumpAndSettle();
    expect(find.text('learner@example.com'), findsOneWidget);
  });
  testWidgets('recovery failure retains email and never shows sent sheet', (
    tester,
  ) async {
    await open(tester, UiAuthRepository()..failRecovery = true);
    await tester.enterText(find.byType(TextField).first, 'learner@example.com');
    await tester.tap(find.text('FORGOT PASSWORD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email!'), findsNothing);
    expect(find.text('Please try again.'), findsOneWidget);
    expect(find.text('learner@example.com'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Enter your details'), findsOneWidget);
  });
  testWidgets('recovery success opens dismissible sheet', (tester) async {
    await open(tester, UiAuthRepository());
    await tester.enterText(find.byType(TextField).first, 'learner@example.com');
    await tester.tap(find.text('FORGOT PASSWORD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email!'), findsOneWidget);
    await tester.tap(find.text('OKAY'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email!'), findsNothing);
    if (useMockAuth) {
      expect(find.text('Reset your password'), findsOneWidget);
    } else {
      expect(find.text('learner@example.com'), findsOneWidget);
    }
  });
  for (final width in [360.0, 390.0, 430.0]) {
    for (final stage in [
      AuthStage.choice,
      AuthStage.details,
      AuthStage.forgot,
      AuthStage.reset,
    ]) {
      testWidgets('login ${stage.name} fits width $width text2 and keyboard', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                () => FixtureAuthController(AuthState(stage: stage)),
              ),
            ],
            child: MaterialApp(
              theme: referenceTheme(),
              home: LoginFlow(initialize: false, onExit: () {}, onStart: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (stage == AuthStage.details) {
          await tester.ensureVisible(find.text('SIGN IN WITH APPLE'));
          await tester.pumpAndSettle();
          expect(find.text('SIGN IN WITH APPLE').hitTestable(), findsOneWidget);
        }
      });
    }
  }
}

class FixtureAuthController extends AuthController {
  FixtureAuthController(this.initial);
  final AuthState initial;
  @override
  AuthState build() => initial;
}
