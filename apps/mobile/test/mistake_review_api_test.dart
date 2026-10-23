import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';

import 'features/learning/api_learning_repository_test.dart' as fixtures;
import 'support/fake_api_transport.dart';

void main() {
  late FakeApiTransport transport;
  late InMemoryLessonJournal journal;
  late ApiLearningRepository repo;
  setUp(() {
    final reviewBundle = {...fixtures.bundle, 'lessonId': 'review_dynamic'};
    transport = FakeApiTransport()
      ..json('GET /v1/courses/vi_en/path', fixtures.path())
      ..json('POST /v1/sessions', {
        ...fixtures.session(),
        'mode': 'REVIEW',
        'lessonId': 'review_dynamic',
        'bundle': reviewBundle,
      });
    journal = InMemoryLessonJournal();
    repo = ApiLearningRepository(
      learning: LearningApi(fakeClient(transport)),
      journal: journal,
      courseId: 'vi_en',
      ids: SequenceIds(),
    );
  });
  ApiLearningRepository restart(
    FakeApiTransport transport,
    InMemoryLessonJournal journal,
  ) => ApiLearningRepository(
    learning: LearningApi(fakeClient(transport)),
    journal: journal,
    courseId: 'vi_en',
    ids: SequenceIds(),
  );
  test('lost start survives restart with identical request and key', () async {
    transport.on(
      'POST /v1/sessions',
      (_) => throw const ApiTransportException('lost response'),
    );
    await expectLater(
      repo.loadLesson('mistake-review'),
      throwsA(isA<LearningFailure>()),
    );
    final pending = (await journal.active())!;
    expect(pending.sessionId, isNull);
    transport.json('POST /v1/sessions', {
      ...fixtures.session(),
      'mode': 'REVIEW',
      'lessonId': 'review_dynamic',
      'bundle': {...fixtures.bundle, 'lessonId': 'review_dynamic'},
    });
    repo = restart(transport, journal);
    await repo.loadLesson('mistake-review');
    final sent = transport.to('POST /v1/sessions');
    expect(sent.last.body, sent.first.body);
    expect(sent.last.headers['Idempotency-Key'], pending.startKey);
  });
  test('hint evidence is sent to the server and journal', () async {
    final e = (await repo.loadLesson('mistake-review')).first;
    transport.json(
      'POST /v1/sessions/sess-1/answers',
      fixtures.answerResult(e.id, true, 1),
    );
    await repo.gradeWithEvidence(
      e,
      LessonAnswer(selectedId: e.correctIds.first),
      assisted: true,
      substituted: false,
    );
    expect(
      (jsonDecode(transport.to('POST /v1/sessions/sess-1/answers').single.body!)
          as Map)['assisted'],
      true,
    );
    expect((await journal.active())!.answers.single.assisted, true);
  });
  test('lost completion survives restart and replays the exact completion identity', () async {
    final exercises = await repo.loadLesson('mistake-review');
    var revision = 0;
    for (final e in exercises) {
      transport.json(
        'POST /v1/sessions/sess-1/answers',
        fixtures.answerResult(e.id, true, ++revision),
      );
      await repo.grade(
        e,
        LessonAnswer(
          selectedId: e.correctIds.firstOrNull,
          text: e.correctText,
          tokenIds: e.correctIds,
          matchedPairs: e.pairs,
        ),
      );
    }
    transport.on(
      'POST /v1/sessions/sess-1/complete',
      (_) => throw const ApiTransportException('lost completion'),
    );
    Future<SessionReceipt> finish() => repo.complete(
      nodeId: 'mistake-review',
      originalCorrect: exercises.length,
      originalTotal: exercises.length,
      elapsed: Duration.zero,
      guest: false,
      placement: false,
    );
    await expectLater(finish(), throwsA(isA<LearningFailure>()));
    final saved = (await journal.active())!;
    final sent = transport.to('POST /v1/sessions/sess-1/complete').first;
    transport.json('GET /v1/sessions/sess-1', {
      ...fixtures.session(revision: revision + 1, status: 'COMPLETED'),
      'mode': 'REVIEW',
      'lessonId': 'review_dynamic',
      'bundle': saved.bundle,
      'answerHistory': saved.answers
          .map((a) => a.toOfflineAnswerJson())
          .toList(),
    });
    transport.json('POST /v1/sessions/sess-1/complete', {
      ...fixtures.completion(),
      'mode': 'REVIEW',
    });
    repo = restart(transport, journal);
    await repo.loadLesson('mistake-review');
    expect(repo.loadDraft()!.stage, LessonStage.feedback);
    final receipt = await finish();
    expect(
      transport.to('POST /v1/sessions/sess-1/complete').last.body,
      sent.body,
    );
    expect(
      transport
          .to('POST /v1/sessions/sess-1/complete')
          .last
          .headers['Idempotency-Key'],
      sent.headers['Idempotency-Key'],
    );
    expect(receipt.firstCompletion, false);
    expect(await journal.active(), isNull);
    expect(await journal.pendingCompletions(), isEmpty);
  });
  test('restart restores the next unanswered original instead of resubmitting the first', () async {
    final e = (await repo.loadLesson('mistake-review')).first;
    transport.json(
      'POST /v1/sessions/sess-1/answers',
      fixtures.answerResult(e.id, true, 1),
    );
    await repo.grade(e, LessonAnswer(selectedId: e.correctIds.first));
    final saved = (await journal.active())!;
    transport.json('GET /v1/sessions/sess-1', {
      ...fixtures.session(revision: 1),
      'mode': 'REVIEW',
      'lessonId': 'review_dynamic',
      'bundle': saved.bundle,
      'answerHistory': saved.answers
          .map((a) => a.toOfflineAnswerJson())
          .toList(),
    });
    repo = restart(transport, journal);
    await repo.loadLesson('mistake-review');
    expect(repo.loadDraft()!.index, 1);
    expect(repo.loadDraft()!.attempted, 1);
    expect(transport.to('POST /v1/sessions'), hasLength(1));
  });
  test(
    'empty review pool does not leave a pending intent that blocks lessons',
    () async {
      final envelope = errorEnvelope('NOT_FOUND');
      (envelope['error'] as Map)['details'] = {'reason': 'REVIEW_POOL_EMPTY'};
      transport.json('POST /v1/sessions', envelope, status: 404);
      await expectLater(
        repo.loadLesson('mistake-review'),
        throwsA(
          isA<LearningFailure>().having(
            (e) => e.message,
            'empty pool',
            contains('Complete a lesson'),
          ),
        ),
      );
      expect(await journal.active(), isNull);
    },
  );
  test(
    'mistake review requests private REVIEW bundle instead of a path lesson',
    () async {
      await repo.loadLesson('mistake-review');
      final body =
          jsonDecode(transport.to('POST /v1/sessions').single.body!) as Map;
      expect(body['mode'], 'REVIEW');
      expect(body['lessonId'], 'review_dynamic');
      expect((await journal.active())!.nodeId, 'mistake-review');
    },
  );
  test('offline review completion keeps journal and never queues a public offline lesson', () async {
    await repo.loadLesson('mistake-review');
    transport.offline = true;
    await expectLater(
      repo.complete(
        nodeId: 'mistake-review',
        originalCorrect: 0,
        originalTotal: 10,
        elapsed: Duration.zero,
        guest: false,
        placement: false,
      ),
      throwsA(isA<LearningFailure>()),
    );
    expect(await journal.active(), isNotNull);
    expect(await journal.pendingCompletions(), isEmpty);
  });
  test(
    'review completion cannot advance local path or grant invented XP',
    () async {
      await repo.loadLesson('mistake-review');
      transport.json('POST /v1/sessions/sess-1/complete', {
        ...fixtures.completion(),
        'mode': 'REVIEW',
      });
      final receipt = await repo.complete(
        nodeId: 'mistake-review',
        originalCorrect: 10,
        originalTotal: 10,
        elapsed: Duration.zero,
        guest: false,
        placement: false,
      );
      expect(receipt.firstCompletion, false);
      expect(receipt.xp, 0);
      expect(await journal.active(), isNull);
    },
  );
  test('lost review answer replays same body and key on retry', () async {
    final exercises = await repo.loadLesson('mistake-review');
    final exercise = exercises.first;
    transport.offline = true;
    await expectLater(
      repo.grade(exercise, LessonAnswer(selectedId: exercise.correctIds.first)),
      throwsA(isA<LearningFailure>()),
    );
    final saved = (await journal.active())!.answers.single;
    transport.offline = false;
    transport.json(
      'POST /v1/sessions/sess-1/answers',
      fixtures.answerResult(exercise.id, true, 1),
    );
    expect(
      await repo.grade(
        exercise,
        LessonAnswer(selectedId: exercise.correctIds.first),
      ),
      true,
    );
    expect((await journal.active())!.answers, hasLength(1));
    final requests = transport.to('POST /v1/sessions/sess-1/answers');
    expect(requests.first.body, requests.last.body);
    expect(requests.last.headers['Idempotency-Key'], saved.idempotencyKey);
  });
}
