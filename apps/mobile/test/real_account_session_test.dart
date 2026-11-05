import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/api/client/api_providers.dart';
import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';

import 'support/fake_api_transport.dart';
import 'support/real_profile.dart';
import 'features/api_snapshot_repositories_test.dart' as fixtures;
import 'features/learning/api_learning_repository_test.dart' as learning;

import 'package:cocenglish/features/learning/presentation/learning_path.dart';
import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';

import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/data/mock_auth_repository.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/session/application/real_learning_session.dart';
import 'package:cocenglish/features/session/presentation/real_connection_screen.dart';
import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/onboarding/presentation/login_entry_screen.dart';

class SessionFake extends MockAuthRepository {
  SessionFake() : super(delay: Duration.zero);
  bool failLogout = false;
  @override
  Future<AuthUser?> restoreSession() async => currentUser;
  @override
  Future<void> signOut() async {
    if (failLogout) throw const AuthFailure('Please retry signing out.');
    return super.signOut();
  }

  @override
  Future<String?> accessToken() async => 'test-jwt';
}

void main() {
  testWidgets('restored account enters home only after server preparation', (
    tester,
  ) async {
    final repository = SessionFake();
    final user = (await tester.runAsync(
      () => repository.signUp(
        'learner@example.com',
        'a-long-test-password',
        'Learner',
      ),
    ))!;
    final transport = FakeApiTransport()
      ..json('GET /v1/me', {...fixtures.profile(), 'userId': user.id})
      ..json('GET /v1/me/rewards', fixtures.rewards())
      ..json('GET /v1/courses/vi_en/path', learning.path());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              dataSource: DataSource.api,
              serviceUrls: {
                ApiService.progress: 'https://progress.test',
                ApiService.learning: 'https://learning.test',
                ApiService.ai: 'https://ai.test',
              },
            ),
          ),
          authRepositoryProvider.overrideWithValue(repository),
          apiTransportProvider.overrideWithValue(transport),
          snapshotStoreProvider.overrideWithValue(MemorySnapshotStore()),
          lessonJournalProvider.overrideWithValue(InMemoryLessonJournal()),
          activeCourseProvider.overrideWith(
            (ref) =>
                ActiveCourse(ref.watch(apiEndpointsProvider), fixed: 'vi_en'),
          ),
        ],
        child: MainApp(
          initial: OnboardingState(step: OnboardingStep.lessonEntry),
        ),
      ),
    );
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(LearningPath), findsOneWidget);
    expect(find.byType(LoginEntryScreen), findsNothing);
    expect(transport.to('GET /v1/me'), isNotEmpty);
    expect(transport.to('GET /v1/courses/vi_en/path'), isNotEmpty);
    expect(tester.takeException(), isNull);
  });
  test('rejected refreshed JWT expires the authenticated UI session', () async {
    final transport = FakeApiTransport()
      ..json('GET /v1/me', errorEnvelope('UNAUTHENTICATED'), status: 401);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(realTestConfig),
        authRepositoryProvider.overrideWithValue(SessionFake()),
        apiTransportProvider.overrideWithValue(transport),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authControllerProvider.notifier)
        .registerAccount(
          'learner@example.com',
          'a-long-test-password',
          'Learner',
        );
    await expectLater(
      container.read(apiEndpointsProvider).getMe(),
      throwsA(isA<ApiException>()),
    );
    expect(transport.requests, hasLength(2));
    expect(container.read(authControllerProvider).user, isNull);
    expect(
      container.read(authControllerProvider).error,
      contains('session ended'),
    );
  });
  testWidgets(
    'real app restores session before admitting a protected home route',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(realTestConfig),
            authRepositoryProvider.overrideWithValue(SessionFake()),
          ],
          child: MainApp(
            initial: OnboardingState(step: OnboardingStep.lessonEntry),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginEntryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'signup publishes identity and invalidates the previous token provider',
    () async {
      final repository = SessionFake();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final oldTokens = container.read(accessTokenProvider);
      expect(await oldTokens.token(), 'test-jwt');
      await container
          .read(authControllerProvider.notifier)
          .registerAccount(
            'learner@example.com',
            'a-long-test-password',
            'Learner',
          );
      final currentTokens = container.read(accessTokenProvider);
      expect(identical(oldTokens, currentTokens), false);
      expect(await oldTokens.token(), isNull);
      expect(
        container.read(authControllerProvider).user?.email,
        'learner@example.com',
      );
      expect(container.read(authControllerProvider).password, isEmpty);
    },
  );
  test(
    'real logout failure keeps identity until the server accepts logout',
    () async {
      final repository = SessionFake();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(realTestConfig),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await controller.registerAccount(
        'learner@example.com',
        'a-long-test-password',
        'Learner',
      );
      final id = container.read(authControllerProvider).user!.id;
      repository.failLogout = true;
      await controller.signOut();
      expect(container.read(authControllerProvider).user?.id, id);
      expect(
        container.read(authControllerProvider).error,
        'Please retry signing out.',
      );
      expect(container.read(authControllerProvider).busy, false);
      repository.failLogout = false;
      await controller.signOut();
      expect(container.read(authControllerProvider).user, isNull);
    },
  );
  test('real receipt cannot mint local XP, streak or path progress', () {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(realTestConfig)],
    );
    addTearDown(container.dispose);
    container
        .read(learningStateProvider.notifier)
        .claim(
          const SessionReceipt(
            id: 'invented',
            nodeId: 'node-0',
            xp: 999,
            accuracy: 1,
            elapsed: Duration.zero,
            firstCompletion: true,
            guest: false,
            placement: false,
          ),
        );
    final state = container.read(learningStateProvider);
    expect(state.xp, 0);
    expect(state.streak, 0);
    expect(state.completedNodes, isEmpty);
    expect(state.currentNode, 0);
  });
  testWidgets('connection error supports retry at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStartupProvider.overrideWith((ref) async {}),
          realLearningSessionProvider.overrideWith(
            (ref) async => throw const AuthFailure('failed'),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const RealConnectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('SIGN OUT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
