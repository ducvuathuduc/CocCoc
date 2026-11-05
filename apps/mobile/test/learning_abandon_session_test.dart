import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/learning/api_learning_repository_test.dart' as fixtures;
import 'support/fake_api_transport.dart';

Map<String, Object?> receipt() => {
  'operationId': 'op-abandon',
  'status': 'accepted',
  'requestId': 'req-1',
};

final class _AbandonFake implements LearningRepository, AbandonableSession {
  int abandonCalls = 0;
  bool failAbandon = false;

  @override
  Future<void> abandonSession() async {
    abandonCalls += 1;
    if (failAbandon) {
      throw const LearningFailure('Please retry ending this lesson.');
    }
  }

  @override
  Future<SessionReceipt> complete({
    required String nodeId,
    required int originalCorrect,
    required int originalTotal,
    required Duration elapsed,
    required bool guest,
    required bool placement,
  }) async => throw UnimplementedError();

  @override
  void clearDraft() {}

  @override
  bool get enforcesHearts => false;

  @override
  Future<bool> grade(Exercise exercise, LessonAnswer answer) async => true;

  @override
  Future<List<Exercise>> loadLesson(String nodeId) async =>
      mockEnglishExercises;

  @override
  LessonState? loadDraft() => null;

  @override
  void saveDraft(LessonState state) {}
}

void main() {
  late FakeApiTransport transport;
  late InMemoryLessonJournal journal;
  late ApiLearningRepository repo;

  setUp(() {
    transport = FakeApiTransport()
      ..json('GET /v1/courses', {
        'items': [
          {
            'courseId': 'vi_en',
            'title': 'English',
            'sourceLocale': 'vi',
            'targetLocale': 'en',
            'publishedVersion': 'v1',
            'available': true,
          },
        ],
        'nextCursor': null,
        'asOf': isoNow,
      })
      ..json('GET /v1/courses/vi_en/path', fixtures.path())
      ..json('POST /v1/sessions', fixtures.session())
      ..json('POST /v1/sessions/sess-1/abandon', receipt());
    journal = InMemoryLessonJournal();
    repo = ApiLearningRepository(
      learning: LearningApi(fakeClient(transport)),
      journal: journal,
      courseId: 'vi_en',
      ids: SequenceIds(),
    );
  });

  test(
    'abandon releases the active server slot and clears the journal',
    () async {
      await repo.loadLesson('node-0');

      await repo.abandonSession();

      final request = transport.to('POST /v1/sessions/sess-1/abandon').single;
      expect(bodyOf(request), {'expectedRevision': 0});
      expect(request.headers['Idempotency-Key'], isNotEmpty);
      expect(await journal.active(), isNull);
    },
  );

  test('offline abandon keeps the journal so the lesson can resume', () async {
    await repo.loadLesson('node-0');
    transport.offline = true;

    await expectLater(repo.abandonSession(), throwsA(isA<LearningFailure>()));

    expect(await journal.active(), isNotNull);
  });

  test('an uncertain abandon retries the same key and body after reopening the repository', () async {
    await repo.loadLesson('node-0');
    transport.offline = true;
    await expectLater(repo.abandonSession(), throwsA(isA<LearningFailure>()));
    final failed = transport.to('POST /v1/sessions/sess-1/abandon').first;
    final stored = await journal.active();
    expect(stored!.toJson()['abandonKey'], failed.headers['Idempotency-Key']);
    transport.offline = false;
    final reopened = ApiLearningRepository(
      learning: LearningApi(fakeClient(transport)),
      journal: journal,
      ids: SequenceIds(),
    );
    await reopened.abandonSession();
    final retried = transport.to('POST /v1/sessions/sess-1/abandon').last;
    expect(
      retried.headers['Idempotency-Key'],
      failed.headers['Idempotency-Key'],
    );
    expect(bodyOf(retried), bodyOf(failed));
    expect(await journal.active(), isNull);
  });

  test('a server-side completed session clears the local journal', () async {
    await repo.loadLesson('node-0');
    transport.on(
      'POST /v1/sessions/sess-1/abandon',
      (_) => jsonResponse(errorEnvelope('SESSION_CONFLICT'), status: 409),
    );

    await repo.abandonSession();

    expect(await journal.active(), isNull);
  });

  test('a stale revision refetches the session and retries once', () async {
    await repo.loadLesson('node-0');
    transport
      ..once(
        'POST /v1/sessions/sess-1/abandon',
        (_) => jsonResponse(errorEnvelope('REVISION_CONFLICT'), status: 409),
      )
      ..json('GET /v1/sessions/sess-1', fixtures.session(revision: 3));

    await repo.abandonSession();

    final requests = transport.to('POST /v1/sessions/sess-1/abandon');
    expect(requests, hasLength(2));
    expect(bodyOf(requests.last), {'expectedRevision': 3});
    expect(await journal.active(), isNull);
  });

  test('leaving an API lesson asks the repository to abandon it', () async {
    final fake = _AbandonFake();
    final container = ProviderContainer(
      overrides: [learningRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final controller = container.read(lessonControllerProvider.notifier);

    await controller.start(
      nodeId: 'node-0',
      exercises: [mockEnglishExercises.first],
    );
    expect(
      container.read(lessonControllerProvider).stage,
      LessonStage.answering,
    );

    controller.abandon();
    await Future<void>.delayed(Duration.zero);

    expect(fake.abandonCalls, 1);
    expect(container.read(lessonControllerProvider).stage, LessonStage.idle);
  });

  test(
    'failed abandon keeps the lesson open and exposes a retryable error',
    () async {
      final fake = _AbandonFake()..failAbandon = true;
      final container = ProviderContainer(
        overrides: [learningRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final controller = container.read(lessonControllerProvider.notifier);
      await controller.start(exercises: [mockEnglishExercises.first]);
      controller.abandon();
      await Future<void>.delayed(Duration.zero);
      final failed = container.read(lessonControllerProvider);
      expect(failed.stage, LessonStage.answering);
      expect(failed.error, contains('retry'));
      expect(failed.busy, isFalse);
      fake.failAbandon = false;
      controller.abandon();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(lessonControllerProvider).stage, LessonStage.idle);
    },
  );

  test('mock lessons abandon locally without an API call', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repository = container.read(learningRepositoryProvider);

    expect(repository, isA<MockLearningRepository>());
    expect(repository, isA<AbandonableSession>());
  });

  test(
    'ApiEndpoints expose the abandon command for the practice owner',
    () async {
      final api = ApiEndpoints(fakeClient(transport));
      await api.abandonSession(
        'sess-1',
        const wire.CompleteRequest(expectedRevision: 0),
        idempotencyKey: 'key-1',
      );
      expect(transport.to('POST /v1/sessions/sess-1/abandon'), hasLength(1));
    },
  );
}
