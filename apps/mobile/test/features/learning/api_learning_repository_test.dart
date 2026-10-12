import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/data/lesson_wire_mapper.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

final Map<String, Object?> bundle = jsonDecode(
  File('test/fixtures/api/lesson_bundle_u1n1l1.json').readAsStringSync(),
) as Map<String, Object?>;

Map<String, Object?> path({List<String> completed = const []}) => {
  'enrollment': {
    'courseId': 'vi_en',
    'courseVersion': 'v1',
    'frontierNodeOrder': 0,
    'completedLessonIds': completed,
    'masteredNodeIds': <String>[],
    'revision': 4,
  },
  'nodes': [
    {
      'nodeId': 'u1n1',
      'unitId': 'u1',
      'sectionId': 'sec1',
      'order': 0,
      'title': 'Xin chào',
      'kind': 'lesson',
      'state': 'current',
      'lessonIds': ['u1n1l1', 'u1n1l2'],
    },
  ],
  'asOf': isoNow,
  'nextCursor': null,
};

Map<String, Object?> session({int revision = 0, String status = 'ACTIVE'}) => {
  'sessionId': 'sess-1',
  'courseId': 'vi_en',
  'lessonId': 'u1n1l1',
  'lessonVersion': 'v1.u1n1l1',
  'status': status,
  'mode': 'LESSON',
  'revision': revision,
  'nextOriginalOrdinal': 0,
  'retryPass': 0,
  'expiresAt': isoNow,
  'bundle': bundle,
  'answerHistory': <Object?>[],
  'lastFeedback': null,
};

Map<String, Object?> answerResult(String id, bool correct, int revision) => {
  'exerciseId': id,
  'correct': correct,
  'explanation': '',
  'acceptedAnswer': '',
  'nextOriginalOrdinal': 1,
  'retryPass': 0,
  'sessionRevision': revision,
  'provisional': false,
};

Map<String, Object?> completion() => {
  'completionId': 'comp-1',
  'sessionId': 'sess-1',
  'originalCount': 10,
  'originalCorrect': 9,
  'assisted': false,
  'source': 'ONLINE',
  'mode': 'LESSON',
  'completedAt': isoNow,
  'enrollmentRevision': 5,
  'rewardStatus': 'pending',
  'needsReviewIds': <String>[],
};

Map<String, Object?> rewards(String status, int? awardXp) => {
  'completionId': 'comp-1',
  'status': status,
  'studyXp': 120,
  'leagueXp': 30,
  'gems': 500,
  'freezeSlots': 1,
  'currentStreak': 3,
  'awardXp': awardXp,
  'revision': 2,
  'asOf': isoNow,
};

void main() {
  late FakeApiTransport transport;
  late InMemoryLessonJournal journal;
  late ApiLearningRepository repo;

  ApiLearningRepository build() {
    final client = fakeClient(transport, ids: SequenceIds());
    return ApiLearningRepository(
      learning: LearningApi(client),
      progress: ProgressApi(client),
      journal: journal,
      ids: SequenceIds(),
      rewardPollDelay: Duration.zero,
    );
  }

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
      ..json('GET /v1/courses/vi_en/path', path())
      ..json('POST /v1/sessions', session());
    journal = InMemoryLessonJournal();
    repo = build();
  });

  test('fixture bundle validates and maps every exercise', () {
    final exercises = (bundle['exercises']! as List).length;
    expect(exercises, 10);
  });

  test('loadLesson starts a session and renders the server bundle', () async {
    final lesson = await repo.loadLesson('node-0');
    expect(lesson, hasLength(10));
    expect(lesson.first.kind, ExerciseKind.choice);
    expect(lesson.first.choices.map((c) => c.text), contains('xin chào'));
    expect(lesson[1].kind, ExerciseKind.matchPairs);
    expect(lesson[1].pairs['hello'], 'xin chào');
    final start = bodyOf(transport.to('POST /v1/sessions').single);
    expect(start, {
      'courseId': 'vi_en',
      'lessonId': 'u1n1l1',
      'mode': 'LESSON',
      'expectedEnrollmentRevision': 4,
    });
    expect((await journal.active())!.sessionId, 'sess-1');
  });

  test('picks the first uncompleted lesson of the node', () async {
    transport.json('GET /v1/courses/vi_en/path', path(completed: ['u1n1l1']));
    await repo.loadLesson('u1n1');
    expect(
      bodyOf(transport.to('POST /v1/sessions').single)['lessonId'],
      'u1n1l2',
    );
  });

  test('grade submits the wire answer; server verdict wins', () async {
    transport.json(
      'POST /v1/sessions/sess-1/answers',
      answerResult('x', false, 1),
    );
    final lesson = await repo.loadLesson('node-0');
    final choice = lesson.first;
    final correct = await repo.grade(
      choice,
      LessonAnswer(selectedId: choice.correctIds.single),
    );
    expect(correct, isFalse, reason: 'server said incorrect');
    final request = transport.to('POST /v1/sessions/sess-1/answers').single;
    expect(bodyOf(request), {
      'exerciseId': choice.id,
      'attemptOrdinal': 0,
      'answer': {'kind': 'choice', 'choiceId': choice.correctIds.single},
      'assisted': false,
      'substituted': false,
      'expectedRevision': 0,
    });
    expect(request.headers['Idempotency-Key'], isNotNull);
    expect(repo.activeSession!.revision, 1);
    expect(repo.activeSession!.answers.single.synced, isTrue);
  });

  test('match pairs answers use wire left/right ids', () async {
    transport.json(
      'POST /v1/sessions/sess-1/answers',
      answerResult('x', true, 1),
    );
    final lesson = await repo.loadLesson('node-0');
    final pairs = lesson[1];
    await repo.grade(pairs, LessonAnswer(matchedPairs: pairs.pairs));
    final answer =
        bodyOf(
              transport.to('POST /v1/sessions/sess-1/answers').single,
            )['answer']
            as Map;
    expect(answer['kind'], 'pairs');
    expect((answer['matches'] as List).first, {
      'leftId': 'p1l',
      'rightId': 'p1r',
    });
  });

  test('offline: grades provisionally, queues and later syncs once', () async {
    final lesson = await repo.loadLesson('node-0');
    transport.offline = true;
    final choice = lesson.first;
    expect(
      await repo.grade(
        choice,
        LessonAnswer(selectedId: choice.correctIds.single),
      ),
      isTrue,
    );
    expect(
      await repo.grade(lesson[2], const LessonAnswer(text: 'hi, i am lan')),
      isTrue,
      reason: 'case/punctuation-insensitive accepted text',
    );
    final receipt = await repo.complete(
      nodeId: 'node-0',
      originalCorrect: 2,
      originalTotal: 2,
      elapsed: const Duration(minutes: 2),
      guest: false,
      placement: false,
    );
    expect(receipt.xp, 0, reason: 'no client-side XP');
    expect(receipt.id, startsWith('offline-'));
    final pending = await journal.pendingCompletions();
    expect(pending, hasLength(1));
    expect(pending.single['bundleHash'], bundle['manifestHash']);
    expect((pending.single['answers'] as List), hasLength(2));
    expect(await journal.active(), isNull);

    transport
      ..offline = false
      ..json('POST /v1/offline-completions', {
        ...completion(),
        'source': 'OFFLINE',
      });
    expect(await repo.syncPending(), 1);
    expect(await repo.syncPending(), 0);
    final sync = transport.to('POST /v1/offline-completions').single;
    expect(sync.headers['Idempotency-Key'], pending.single['operationId']);
    expect(await journal.pendingCompletions(), isEmpty);
  });

  test('complete commits and reports server-credited XP', () async {
    transport
      ..json('POST /v1/sessions/sess-1/complete', completion())
      ..once('GET /base/v1/me/rewards', (_) {
        return ApiHttpResponse(200, jsonEncode(rewards('pending', null)));
      })
      ..json('GET /base/v1/me/rewards', rewards('credited', 19));
    await repo.loadLesson('node-0');
    final receipt = await repo.complete(
      nodeId: 'node-0',
      originalCorrect: 1,
      originalTotal: 1,
      elapsed: const Duration(minutes: 1),
      guest: false,
      placement: false,
    );
    expect(receipt.xp, 19);
    expect(receipt.id, 'comp-1');
    expect(receipt.accuracy, closeTo(0.9, 1e-9));
    expect(receipt.firstCompletion, isTrue);
    expect(await journal.active(), isNull);
  });

  test(
    'crash resume: replays unsynced answers with their original keys',
    () async {
      await repo.loadLesson('node-0');
      transport.offline = true;
      final lesson = await repo.loadLesson('node-0');
      await repo.grade(lesson.first, const LessonAnswer(selectedId: 'c2'));
      final key = repo.activeSession!.answers.single.idempotencyKey;

      // App restarts: new repository instance, same journal.
      transport.requests.clear();
      transport
        ..offline = false
        ..json('GET /v1/sessions/sess-1', session(revision: 0))
        ..json('POST /v1/sessions/sess-1/answers', answerResult('x', true, 1));
      final restarted = build();
      await restarted.loadLesson('node-0');
      final replays = transport.to('POST /v1/sessions/sess-1/answers');
      expect(replays.single.headers['Idempotency-Key'], key);
      expect(restarted.activeSession!.answers.single.synced, isTrue);
      expect(transport.to('POST /v1/sessions'), isEmpty, reason: 'resumed');
    },
  );

  test('server errors surface as LearningFailure with safe copy', () async {
    transport.json(
      'POST /v1/sessions',
      errorEnvelope('ENERGY_EMPTY'),
      status: 409,
    );
    await expectLater(
      repo.loadLesson('node-0'),
      throwsA(isA<LearningFailure>()),
    );
  });

  test('normalizeText honours diacritics flag', () {
    expect(
      LessonWireMapper.normalizeText('Tên tôi là Minh.', {
        'ignoreDiacritics': true,
        'ignorePunctuation': true,
      }),
      'ten toi la minh',
    );
    expect(
      LessonWireMapper.normalizeText('Tên', {'ignoreDiacritics': false}),
      'tên',
    );
  });
}
