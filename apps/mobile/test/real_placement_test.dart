import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';

import 'support/fake_api_transport.dart';
import 'features/learning/api_learning_repository_test.dart' as f;

final manifest = jsonDecode(
  File('../../content/vi_en/dist/v2/manifest.json').readAsStringSync(),
) as Map<String, dynamic>;
final placementId = (manifest['placementBundle'] as Map)['lessonId'] as String;
Map<String, Object?> placementSession({String status = 'ACTIVE'}) => {
  ...f.session(status: status),
  'lessonId': placementId,
  'mode': 'PLACEMENT',
};
void main() {
  late FakeApiTransport transport;
  late InMemoryLessonJournal journal;
  ApiLearningRepository build() => ApiLearningRepository(
    learning: LearningApi(fakeClient(transport)),
    journal: journal,
    courseId: 'vi_en',
    ids: SequenceIds(),
  );
  setUp(() {
    transport = FakeApiTransport()
      ..json('GET /v1/courses/vi_en/manifest', manifest)
      ..json('POST /v1/sessions', placementSession());
    transport.json('GET /v1/sessions/sess-1', placementSession());
    journal = InMemoryLessonJournal();
  });
  test(
    'existing enrollment cannot be retested through placement entry',
    () async {
      transport.json('GET /v1/courses/vi_en/path', f.path());
      await expectLater(
        build().loadLesson('placement'),
        throwsA(isA<LearningFailure>()),
      );
      expect(transport.to('POST /v1/sessions'), isEmpty);
    },
  );
  test(
    'lost placement start response replays the durable original request',
    () async {
      var disconnected = true;
      transport.on('POST /v1/sessions', (_) {
        if (disconnected) throw const ApiTransportException('offline');
        return jsonResponse(placementSession());
      });
      await expectLater(
        build().loadLesson('placement'),
        throwsA(isA<LearningFailure>()),
      );
      expect((await journal.active())!.sessionId, isNull);
      disconnected = false;
      await build().loadLesson('placement');
      final requests = transport.to('POST /v1/sessions');
      expect(
        requests.map((r) => r.headers['Idempotency-Key']).toSet(),
        hasLength(1),
      );
      expect(bodyOf(requests.first), bodyOf(requests.last));
      expect((await journal.active())!.sessionId, 'sess-1');
    },
  );
  test('expired placement attempts get a new start identity', () async {
    final repo = build();
    await repo.loadLesson('placement');
    transport.json(
      'GET /v1/sessions/sess-1',
      placementSession(status: 'EXPIRED'),
    );
    await repo.loadLesson('placement');
    final requests = transport.to('POST /v1/sessions');
    expect(requests, hasLength(2));
    expect(
      requests.first.headers['Idempotency-Key'],
      isNot(requests.last.headers['Idempotency-Key']),
    );
  });
  test(
    'offline placement answer stays pending and retries with the exact key',
    () async {
      final repo = build();
      final exercises = await repo.loadLesson('placement');
      transport.offline = true;
      await expectLater(
        repo.grade(
          exercises.first,
          LessonAnswer(selectedId: exercises.first.correctIds.single),
        ),
        throwsA(isA<LearningFailure>()),
      );
      expect((await journal.active())!.answers.single.synced, false);
      transport.offline = false;
      transport.json(
        'POST /v1/sessions/sess-1/answers',
        f.answerResult(exercises.first.id, true, 1),
      );
      expect(
        await repo.grade(
          exercises.first,
          LessonAnswer(selectedId: exercises.first.correctIds.single),
        ),
        true,
      );
      expect(
        transport
            .to('POST /v1/sessions/sess-1/answers')
            .map((r) => r.headers['Idempotency-Key'])
            .toSet(),
        hasLength(1),
      );
      expect((await journal.active())!.answers, hasLength(1));
    },
  );
  test(
    'failed enrollment preserves completed placement and replays both keys',
    () async {
      transport.json('POST /v1/sessions/sess-1/complete', {
        ...f.completion(),
        'mode': 'PLACEMENT',
        'rewardStatus': 'notEligible',
      });
      transport.once(
        'POST /v1/enrollments',
        (_) =>
            jsonResponse(errorEnvelope('SERVICE_NOT_CONFIGURED'), status: 503),
      );
      transport.json('POST /v1/enrollments', f.path()['enrollment']);
      transport.json(
        'GET /v1/sessions/sess-1',
        placementSession(status: 'COMPLETED'),
      );
      Future<SessionReceipt> finish(ApiLearningRepository repo) =>
          repo.complete(
            nodeId: 'placement',
            originalCorrect: 10,
            originalTotal: 10,
            elapsed: Duration.zero,
            guest: false,
            placement: true,
          );
      final first = build();
      await first.loadLesson('placement');
      await expectLater(finish(first), throwsA(isA<LearningFailure>()));
      expect(await journal.active(), isNotNull);
      expect(await journal.pendingCompletions(), isEmpty);
      final second = build();
      await second.loadLesson('placement');
      await finish(second);
      for (final route in [
        'POST /v1/enrollments',
        'POST /v1/sessions/sess-1/complete',
      ]) {
        final requests = transport.to(route);
        expect(requests, hasLength(2));
        expect(
          requests.first.headers['Idempotency-Key'],
          requests.last.headers['Idempotency-Key'],
        );
        expect(bodyOf(requests.first), bodyOf(requests.last));
      }
      expect(await journal.active(), isNull);
    },
  );
  test(
    'offline placement completion never queues an ordinary lesson',
    () async {
      final repo = build();
      await repo.loadLesson('placement');
      transport.offline = true;
      await expectLater(
        repo.complete(
          nodeId: 'placement',
          originalCorrect: 10,
          originalTotal: 10,
          elapsed: Duration.zero,
          guest: false,
          placement: true,
        ),
        throwsA(isA<LearningFailure>()),
      );
      expect(await journal.active(), isNotNull);
      expect(await journal.pendingCompletions(), isEmpty);
    },
  );
  test(
    'placement starts the published server bundle before enrollment',
    () async {
      final repo = build();
      final exercises = await repo.loadLesson('placement');
      expect(exercises, hasLength(10));
      expect(bodyOf(transport.to('POST /v1/sessions').single), {
        'courseId': 'vi_en',
        'lessonId': placementId,
        'mode': 'PLACEMENT',
        'expectedEnrollmentRevision': 0,
      });
      expect(transport.to('POST /v1/enrollments'), isEmpty);
    },
  );
  test('placement cannot overwrite a different saved lesson', () async {
    final ordinary = JournalSession(
      nodeId: 'node-0',
      courseId: 'vi_en',
      lessonId: 'u1n1l1',
      lessonVersion: 'v1',
      bundleHash: 'hash',
      enrollmentRevision: 0,
      bundle: f.bundle,
      startKey: 'old',
      completeKey: 'done',
    );
    await journal.saveActive(ordinary);
    await expectLater(
      build().loadLesson('placement'),
      throwsA(isA<LearningFailure>()),
    );
    expect((await journal.active())!.nodeId, 'node-0');
    expect(transport.to('POST /v1/sessions'), isEmpty);
  });
  test('placement completes with zero XP and enrolls using server session identity', () async {
    transport.json('POST /v1/sessions/sess-1/complete', {
      ...f.completion(),
      'mode': 'PLACEMENT',
      'rewardStatus': 'notEligible',
      'originalCorrect': 8,
    });
    transport.json('POST /v1/enrollments', f.path()['enrollment']);
    final repo = build();
    await repo.loadLesson('placement');
    final receipt = await repo.complete(
      nodeId: 'placement',
      originalCorrect: 10,
      originalTotal: 10,
      elapsed: Duration.zero,
      guest: false,
      placement: true,
    );
    expect(receipt.xp, 0);
    expect(receipt.rewardPending, false);
    expect(receipt.firstCompletion, false);
    expect(receipt.accuracy, .8);
    expect(bodyOf(transport.to('POST /v1/enrollments').single), {
      'courseId': 'vi_en',
      'startPoint': 'placement',
      'placementSessionId': 'sess-1',
    });
    expect(await journal.active(), isNull);
  });
}
