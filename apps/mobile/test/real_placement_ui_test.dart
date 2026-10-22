import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/session/application/enrollment_choice.dart';
import 'package:cocenglish/features/learning/application/course_navigation_controller.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/path_repository.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/domain/course_catalog.dart';
import 'package:cocenglish/features/placement/presentation/placement_screens.dart';
import 'package:cocenglish/features/session/application/real_learning_session.dart';
import 'package:cocenglish/features/session/data/real_learning_session_repository.dart';
import 'package:cocenglish/features/session/presentation/real_connection_screen.dart';

import 'support/fake_api_transport.dart';
import 'features/api_snapshot_repositories_test.dart' as fixtures;
import 'features/learning/api_learning_repository_test.dart' as f;

class TenWrong extends MockLearningRepository {
  int checks = 0;
  @override
  Future<List<Exercise>> loadLesson(String nodeId) async => List.generate(
    10,
    (i) => Exercise(
      id: 'q$i',
      kind: ExerciseKind.choice,
      title: 'Choose',
      prompt: 'Hello',
      choices: const [
        ExerciseChoice(id: 'a', text: 'A'),
        ExerciseChoice(id: 'b', text: 'B'),
      ],
      correctIds: const ['a'],
    ),
  );
  @override
  Future<bool> grade(Exercise exercise, LessonAnswer answer) async {
    checks++;
    return false;
  }
}

PreparedLearningSession pending() => PreparedLearningSession(
  profile: wire.Profile.fromJson(fixtures.profile()),
  paths: const [],
  rewards: wire.Rewards.fromJson(fixtures.rewards()),
);

class SignedIn extends AuthController {
  @override
  AuthState build() => const AuthState(
    stage: AuthStage.signedIn,
    user: AuthUser(id: 'me', email: 'test@example.com', name: 'Learner'),
  );
}

ProviderContainer choiceContainer(
  FakeApiTransport transport, {
  LessonJournal? journal,
}) {
  final api = ApiEndpoints(fakeClient(transport));
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(dataSource: DataSource.api),
      ),
      authControllerProvider.overrideWith(SignedIn.new),
      lessonJournalProvider.overrideWithValue(
        journal ?? InMemoryLessonJournal(),
      ),
      realLearningSessionRepositoryProvider.overrideWithValue(
        RealLearningSessionRepository(
          api,
          ActiveCourse(api, fixed: 'vi_en'),
          ids: SequenceIds(),
        ),
      ),
    ],
  );
}

void main() {
  test('bootstrap retains pending placement even after server enrollment committed', () async {
    final transport = FakeApiTransport()
      ..json('GET /base/v1/me', fixtures.profile())
      ..json('GET /base/v1/me/rewards', fixtures.rewards())
      ..json('GET /v1/courses/vi_en/path', f.path());
    final api = ApiEndpoints(fakeClient(transport));
    final journal = InMemoryLessonJournal();
    await journal.saveActive(
      const JournalSession(
        nodeId: 'placement',
        courseId: 'vi_en',
        lessonId: 'placement',
        lessonVersion: 'v2',
        bundleHash: '',
        enrollmentRevision: 0,
        bundle: {},
        startKey: 'start',
        completeKey: 'complete',
      ),
    );
    final prepared = await RealLearningSessionRepository(
      api,
      ActiveCourse(api, fixed: 'vi_en'),
      journal: journal,
    ).prepare('me', 'Learner');
    expect(prepared.needsEnrollment, false);
    expect(prepared.hasSavedPlacement, true);
    expect(
      realLearningRedirect(
        path: '/home',
        api: true,
        restoring: false,
        signedIn: true,
        ready: true,
        placementPending: true,
      ),
      '/placement',
    );
  });
  testWidgets('saved placement can resume when enrollment already exists', (
    tester,
  ) async {
    final prepared = PreparedLearningSession(
      profile: wire.Profile.fromJson(fixtures.profile()),
      paths: [wire.Path.fromJson(f.path())],
      rewards: wire.Rewards.fromJson(fixtures.rewards()),
      hasSavedPlacement: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          realLearningSessionProvider.overrideWith((ref) async => prepared),
        ],
        child: const MaterialApp(home: PlacementEntryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'START OR RESUME TEST'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  test('beginner choice is explicit and duplicate taps enroll once', () async {
    final transport = FakeApiTransport()
      ..json('POST /v1/enrollments', f.path()['enrollment']);
    final c = choiceContainer(transport);
    addTearDown(c.dispose);
    final vm = c.read(enrollmentChoiceProvider.notifier);
    final first = vm.beginner();
    await vm.beginner();
    await first;
    expect(
      bodyOf(transport.to('POST /v1/enrollments').single)['startPoint'],
      'beginner',
    );
    expect(c.read(enrollmentChoiceProvider).hasError, false);
  });
  test(
    'failed beginner enrollment retries the same command identity',
    () async {
      final transport = FakeApiTransport()
        ..json('POST /v1/enrollments', f.path()['enrollment']);
      transport.once(
        'POST /v1/enrollments',
        (_) =>
            jsonResponse(errorEnvelope('SERVICE_NOT_CONFIGURED'), status: 503),
      );
      final c = choiceContainer(transport);
      addTearDown(c.dispose);
      final vm = c.read(enrollmentChoiceProvider.notifier);
      await vm.beginner();
      expect(c.read(enrollmentChoiceProvider).hasError, true);
      await vm.beginner();
      expect(c.read(enrollmentChoiceProvider).hasError, false);
      final requests = transport.to('POST /v1/enrollments');
      expect(requests, hasLength(2));
      expect(
        requests.first.headers['Idempotency-Key'],
        requests.last.headers['Idempotency-Key'],
      );
    },
  );
  test(
    'beginner choice cannot bypass an unfinished placement journal',
    () async {
      final transport = FakeApiTransport();
      final journal = InMemoryLessonJournal();
      await journal.saveActive(
        const JournalSession(
          nodeId: 'placement',
          courseId: 'vi_en',
          lessonId: 'placement',
          lessonVersion: 'v2',
          bundleHash: '',
          enrollmentRevision: 0,
          bundle: {},
          startKey: 'start',
          completeKey: 'complete',
        ),
      );
      final c = choiceContainer(transport, journal: journal);
      addTearDown(c.dispose);
      await c.read(enrollmentChoiceProvider.notifier).beginner();
      expect(c.read(enrollmentChoiceProvider).hasError, true);
      expect(transport.requests, isEmpty);
      expect(await journal.active(), isNotNull);
    },
  );
  test(
    'placement ends after ten original answers without retry passes or XP',
    () async {
      final repo = TenWrong();
      final c = ProviderContainer(
        overrides: [learningRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final vm = c.read(lessonControllerProvider.notifier);
      await vm.start(nodeId: 'placement', placement: true);
      for (var i = 0; i < 10; i++) {
        expect(c.read(lessonControllerProvider).isRetry, false);
        vm.select('b');
        await vm.check();
        await vm.next();
      }
      final state = c.read(lessonControllerProvider);
      expect(repo.checks, 10);
      expect(state.stage, LessonStage.completed);
      expect(state.receipt!.xp, 0);
      expect(state.receipt!.placement, true);
    },
  );
  test(
    'cold path opens the server frontier unit and retains manual selection',
    () {
      final api = ApiEndpoints(fakeClient(FakeApiTransport()));
      final path = ApiPathRepository(api, ActiveCourse(api, fixed: 'vi_en'));
      final json = f.path();
      final node = (json['nodes'] as List).first as Map;
      json['nodes'] = [
        {...node, 'state': 'available'},
        {
          ...node,
          'unitId': 'u2',
          'nodeId': 'u2n1',
          'order': 8,
          'state': 'current',
        },
      ];
      path.cache.put([wire.Path.fromJson(json)]);
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          pathRepositoryProvider.overrideWithValue(path),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(courseNavigationProvider).active, const CourseTarget(1, 2));
      expect(
        c
            .read(courseNavigationProvider.notifier)
            .select(const CourseTarget(1, 1)),
        true,
      );
      expect(c.read(courseNavigationProvider).active, const CourseTarget(1, 1));
      expect(c.read(courseNavigationProvider.notifier).selectFrontier(), true);
      expect(c.read(courseNavigationProvider).active, const CourseTarget(1, 2));
    },
  );
  test('placement routes require identity but not prior enrollment', () {
    for (final path in [
      '/placement',
      '/lesson/placement',
      '/placement/result',
    ]) {
      expect(
        realLearningRedirect(
          path: path,
          api: true,
          restoring: false,
          signedIn: false,
          ready: false,
        ),
        '/login',
      );
      expect(
        realLearningRedirect(
          path: path,
          api: true,
          restoring: false,
          signedIn: true,
          ready: false,
        ),
        isNull,
      );
    }
  });
  testWidgets('starting point choice is readable at text scale two', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStartupProvider.overrideWith((ref) async {}),
          realLearningSessionProvider.overrideWith((ref) async => pending()),
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
    expect(find.text('CHECK MY LEVEL'), findsOneWidget);
    expect(find.text('START FROM THE BEGINNING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('placement entry explains no XP and resume at text scale two', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          realLearningSessionProvider.overrideWith((ref) async => pending()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const PlacementEntryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('START OR RESUME TEST'), findsOneWidget);
    expect(find.textContaining('does not award XP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
