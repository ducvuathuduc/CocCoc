import 'dart:async';

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/auth/presentation/login_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const savedUser = AuthUser(
  id: 'saved-id',
  email: 'samlee@example.test',
  name: 'Sam Lee',
);

class SavedAccountRepository implements AuthRepository {
  bool failForget = false;
  int forgetRequests = 0;
  Completer<void>? pendingForget;

  @override
  Future<void> forgetAccount() async {
    forgetRequests++;
    if (failForget) throw const AuthFailure('Storage unavailable.');
    await pendingForget?.future;
  }

  @override
  Future<AuthUser?> rememberedAccount() async => savedUser;

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<void> resetPassword(String id, String secret, String password) async {}

  @override
  Future<void> sendRecovery(String email) async {}

  @override
  Future<AuthUser> signIn(String email, String password) async => savedUser;

  @override
  Future<AuthUser> socialSignIn(AuthProvider provider) async => savedUser;
}

class SavedAccountController extends AuthController {
  @override
  AuthState build() => const AuthState(remembered: savedUser);
}

Future<ProviderContainer> pumpSavedAccount(
  WidgetTester tester,
  SavedAccountRepository repository, {
  double width = 390,
  double textScale = 1,
  VoidCallback? onExit,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(SavedAccountController.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: LoginFlow(
          initialize: false,
          onExit: onExit ?? () {},
          onStart: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> openManager(WidgetTester tester) async {
  await tester.ensureVisible(find.text('MANAGE ACCOUNTS'));
  await tester.tap(find.text('MANAGE ACCOUNTS'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Manage accounts opens full screen and Done preserves account', (
    tester,
  ) async {
    final repository = SavedAccountRepository();
    var exits = 0;
    final container = await pumpSavedAccount(
      tester,
      repository,
      onExit: () => exits++,
    );

    await openManager(tester);
    expect(find.text('Manage Accounts'), findsOneWidget);
    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.text('samlee@example.test'), findsOneWidget);
    expect(find.text('DONE EDITING'), findsOneWidget);

    await tester.tap(find.text('DONE EDITING'));
    await tester.pumpAndSettle();
    expect(find.text('Sign back in'), findsOneWidget);
    expect(container.read(authControllerProvider).remembered, savedUser);
    expect(repository.forgetRequests, 0);
    expect(exits, 0);
  });

  testWidgets('minus opens Remove popover and dismissal preserves account', (
    tester,
  ) async {
    final repository = SavedAccountRepository();
    var exits = 0;
    final container = await pumpSavedAccount(
      tester,
      repository,
      onExit: () => exits++,
    );
    await openManager(tester);

    await tester.tap(find.bySemanticsLabel('Remove saved account'));
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Remove')).dy,
      lessThan(
        tester.getTopLeft(find.bySemanticsLabel('Remove saved account')).dy,
      ),
    );
    await tester.tapAt(const Offset(380, 700));
    await tester.pumpAndSettle();

    expect(find.text('Remove'), findsNothing);
    expect(find.text('Manage Accounts'), findsOneWidget);
    expect(container.read(authControllerProvider).remembered, savedUser);
    expect(repository.forgetRequests, 0);
    expect(exits, 0);
  });

  testWidgets('Remove forgets saved account once and returns to welcome', (
    tester,
  ) async {
    final repository = SavedAccountRepository();
    var exits = 0;
    final container = await pumpSavedAccount(
      tester,
      repository,
      onExit: () => exits++,
    );
    await openManager(tester);

    await tester.tap(find.bySemanticsLabel('Remove saved account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(repository.forgetRequests, 1);
    expect(container.read(authControllerProvider).remembered, isNull);
    expect(exits, 1);
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('Manage Accounts'), findsNothing);
  });

  testWidgets('pending Remove disables duplicate account removal', (
    tester,
  ) async {
    final repository = SavedAccountRepository()
      ..pendingForget = Completer<void>();
    await pumpSavedAccount(tester, repository);
    await openManager(tester);

    await tester.tap(find.bySemanticsLabel('Remove saved account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pump();

    expect(repository.forgetRequests, 1);
    final remove = tester.widget<Semantics>(
      find.bySemanticsLabel('Remove saved account'),
    );
    expect(remove.properties.enabled, isFalse);
    repository.pendingForget!.complete();
    await tester.pumpAndSettle();
    expect(repository.forgetRequests, 1);
  });

  testWidgets('failed Remove stays visible with account at width 360 text2', (
    tester,
  ) async {
    final repository = SavedAccountRepository()..failForget = true;
    var exits = 0;
    final container = await pumpSavedAccount(
      tester,
      repository,
      width: 360,
      textScale: 2,
      onExit: () => exits++,
    );
    await openManager(tester);

    await tester.tap(find.bySemanticsLabel('Remove saved account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Manage Accounts'), findsOneWidget);
    expect(find.text('Storage unavailable.'), findsOneWidget);
    expect(container.read(authControllerProvider).remembered, savedUser);
    expect(exits, 0);
    expect(tester.takeException(), isNull);
  });
}
