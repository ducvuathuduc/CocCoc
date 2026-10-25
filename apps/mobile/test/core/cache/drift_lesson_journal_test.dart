import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/cache/drift_lesson_journal.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

JournalSession session(String id) => JournalSession(
  nodeId: 'node-$id',
  courseId: 'course',
  lessonId: 'lesson-$id',
  lessonVersion: 'v1',
  bundleHash: 'hash',
  enrollmentRevision: 1,
  bundle: const {'lessonId': 'lesson', 'exercises': <Object?>[]},
  startKey: 'start-$id',
  completeKey: 'complete-$id',
);

Map<String, Object?> completion(String id, {String lesson = 'lesson'}) => {
  'operationId': id,
  'lessonId': lesson,
  'answers': <Object?>[],
};

void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('journal-'));
  tearDown(() async => temp.delete(recursive: true));

  DriftLessonJournal open(
    String account, {
    LegacyLessonJournalSource? legacy,
    int maxOperations = 500,
    int maxMetadataBytes = 10 * 1024 * 1024,
  }) => DriftLessonJournal(
    namespace: account,
    executor: NativeDatabase(File('${temp.path}/journal.sqlite')),
    legacy: legacy,
    maxOperations: maxOperations,
    maxMetadataBytes: maxMetadataBytes,
  );

  test(
    'rejected completion survives restart and remains account scoped',
    () async {
      final first = open('a');
      final original = completion('rejected');
      await first.enqueueCompletion(original);
      await first.rejectCompletion('rejected', 'CONTENT_STALE');
      await first.rejectCompletion('rejected', 'CONTENT_STALE');
      expect(await first.pendingCompletions(), isEmpty);
      await first.close();
      final reopened = open('a');
      final other = open('b');
      final rows = await reopened.rejectedCompletions();
      expect(rows.single.payload, original);
      expect(rows.single.reasonCode, 'CONTENT_STALE');
      expect(await other.rejectedCompletions(), isEmpty);
      await expectLater(
        reopened.enqueueCompletion(completion('rejected', lesson: 'changed')),
        throwsA(isA<JournalFailure>()),
      );
      await reopened.enqueueCompletion(original);
      expect(await reopened.pendingCompletions(), isEmpty);
      await reopened.clear();
      expect(await reopened.rejectedCompletions(), isEmpty);
      await reopened.close();
      await other.close();
    },
  );

  test('rejected answers still consume the bounded storage budget', () async {
    final journal = open('a', maxOperations: 1);
    await journal.enqueueCompletion(completion('rejected'));
    await journal.rejectCompletion('rejected', 'CONTENT_STALE');
    await expectLater(
      journal.enqueueCompletion(completion('next')),
      throwsA(
        isA<JournalFailure>().having(
          (e) => e.code,
          'code',
          JournalFailure.queueCountLimit,
        ),
      ),
    );
    expect(
      (await journal.rejectedCompletions()).single.operationId,
      'rejected',
    );
    await journal.close();
  });

  test(
    'file-backed journal survives close and reopen in insertion order',
    () async {
      final first = open('a');
      await first.saveActive(session('a'));
      await first.enqueueCompletion(completion('op-1'));
      await first.enqueueCompletion(completion('op-2'));
      await first.close();

      final reopened = open('a');
      expect((await reopened.active())?.completeKey, 'complete-a');
      expect(
        (await reopened.pendingCompletions()).map(
          (item) => item['operationId'],
        ),
        ['op-1', 'op-2'],
      );
      await reopened.close();
    },
  );

  test('accounts sharing one database remain isolated', () async {
    final a = open('a');
    await a.saveActive(session('a'));
    await a.enqueueCompletion(completion('a-op'));
    await a.close();

    final b = open('b');
    expect(await b.active(), isNull);
    expect(await b.pendingCompletions(), isEmpty);
    await b.saveActive(session('b'));
    await b.close();

    final again = open('a');
    expect((await again.active())?.completeKey, 'complete-a');
    expect((await again.pendingCompletions()).single['operationId'], 'a-op');
    await again.close();
  });

  test(
    'same operation and payload deduplicates but changed payload rejects',
    () async {
      final journal = open('a');
      await journal.enqueueCompletion(completion('op'));
      await journal.enqueueCompletion(completion('op'));
      expect(await journal.pendingCompletions(), hasLength(1));

      await expectLater(
        journal.enqueueCompletion(completion('op', lesson: 'changed')),
        throwsA(
          isA<JournalFailure>().having(
            (error) => error.code,
            'code',
            JournalFailure.operationConflict,
          ),
        ),
      );
      expect(await journal.pendingCompletions(), hasLength(1));
      await journal.close();
    },
  );

  test(
    'atomic completion staging clears active or rolls back together',
    () async {
      final journal = open('a');
      await journal.saveActive(session('first'));
      await journal.stageCompletionAndClearActive(completion('op'));
      expect(await journal.active(), isNull);
      expect(await journal.pendingCompletions(), hasLength(1));

      await journal.saveActive(session('second'));
      await expectLater(
        journal.stageCompletionAndClearActive(
          completion('op', lesson: 'conflict'),
        ),
        throwsA(isA<JournalFailure>()),
      );
      expect((await journal.active())?.completeKey, 'complete-second');
      expect(await journal.pendingCompletions(), hasLength(1));
      await journal.close();
    },
  );

  test(
    'legacy migration runs once and keeps corrupt source recoverable',
    () async {
      final legacy = _Legacy(
        activeRaw: jsonEncode(session('legacy').toJson()),
        pendingRaw: jsonEncode([completion('legacy-op')]),
      );
      final first = open('migrated', legacy: legacy);
      expect((await first.active())?.completeKey, 'complete-legacy');
      expect(await first.pendingCompletions(), hasLength(1));
      await first.close();
      expect(legacy.reads, 2);

      final shouldNotRead = _Legacy(activeRaw: '{bad', pendingRaw: '[bad');
      final reopened = open('migrated', legacy: shouldNotRead);
      expect((await reopened.active())?.completeKey, 'complete-legacy');
      expect(shouldNotRead.reads, 0);
      await reopened.close();

      final corrupt = _Legacy(
        activeRaw: '{bad',
        pendingRaw: jsonEncode([completion('kept')]),
      );
      final failed = open('corrupt', legacy: corrupt);
      await expectLater(
        failed.active(),
        throwsA(
          isA<JournalFailure>().having(
            (error) => error.code,
            'code',
            JournalFailure.legacyCorrupt,
          ),
        ),
      );
      expect(corrupt.activeRaw, '{bad', reason: 'legacy backup is retained');
      expect(corrupt.pendingRaw, isNotNull);
      await failed.close();

      final repaired = _Legacy(
        activeRaw: jsonEncode(session('recovered').toJson()),
        pendingRaw: jsonEncode([completion('kept')]),
      );
      final recovery = open('corrupt', legacy: repaired);
      expect((await recovery.active())?.completeKey, 'complete-recovered');
      expect(await recovery.pendingCompletions(), hasLength(1));
      await recovery.close();
    },
  );

  test('closed handles reject late work with a stable failure', () async {
    final journal = open('a');
    await journal.close();
    await expectLater(
      journal.saveActive(session('late')),
      throwsA(
        isA<JournalFailure>().having(
          (error) => error.code,
          'code',
          JournalFailure.closed,
        ),
      ),
    );
  });

  test('stored corruption halts reads and retains the damaged row', () async {
    late dynamic rawDatabase;
    final journal = DriftLessonJournal(
      namespace: 'damaged',
      executor: NativeDatabase(
        File('${temp.path}/journal.sqlite'),
        setup: (database) => rawDatabase = database,
      ),
    );
    await journal.enqueueCompletion(completion('op'));
    rawDatabase.execute(
      "UPDATE lesson_pending_completions SET payload = '{bad' "
      "WHERE namespace = 'damaged'",
    );

    await expectLater(
      journal.pendingCompletions(),
      throwsA(
        isA<JournalFailure>().having(
          (error) => error.code,
          'code',
          JournalFailure.corrupt,
        ),
      ),
    );
    expect(
      rawDatabase
          .select(
            "SELECT COUNT(*) AS c FROM lesson_pending_completions "
            "WHERE namespace = 'damaged'",
          )
          .single['c'],
      1,
    );
    await journal.close();
  });

  test('queue count and metadata budgets fail closed', () async {
    final count = open('count', maxOperations: 2);
    await count.enqueueCompletion(completion('one'));
    await count.enqueueCompletion(completion('two'));
    await expectLater(
      count.enqueueCompletion(completion('three')),
      throwsA(
        isA<JournalFailure>().having(
          (error) => error.code,
          'code',
          JournalFailure.queueCountLimit,
        ),
      ),
    );
    await count.close();

    final bytes = open('bytes', maxMetadataBytes: 64);
    await expectLater(
      bytes.enqueueCompletion({...completion('large'), 'metadata': 'x' * 128}),
      throwsA(
        isA<JournalFailure>().having(
          (error) => error.code,
          'code',
          JournalFailure.queueSizeLimit,
        ),
      ),
    );
    await bytes.close();
  });
}

final class _Legacy implements LegacyLessonJournalSource {
  _Legacy({this.activeRaw, this.pendingRaw});

  final String? activeRaw;
  final String? pendingRaw;
  int reads = 0;

  @override
  Future<String?> readActive() async {
    reads++;
    return activeRaw;
  }

  @override
  Future<String?> readPending() async {
    reads++;
    return pendingRaw;
  }
}
