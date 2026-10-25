import 'dart:convert';

import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/core/cache/lesson_journal_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

JournalSession draft(String id) => JournalSession(
  nodeId: 'native-node',
  courseId: 'vi_en',
  lessonId: 'native-lesson',
  lessonVersion: 'v1',
  bundleHash: 'native-fixture-hash',
  enrollmentRevision: 1,
  bundle: const {'exercises': <Object?>[]},
  startKey: 'native-start-$id',
  completeKey: 'native-complete-$id',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android rejected answers remain durable and stop replaying', (
    tester,
  ) async {
    final namespace =
        'qa.native.rejected.${DateTime.now().microsecondsSinceEpoch}';
    final first = createDurableLessonJournal(namespace: namespace);
    final payload = <String, Object?>{
      'operationId': 'rejected-op',
      'lessonId': 'old-lesson',
      'answers': <Object?>[],
    };
    await first.enqueueCompletion(payload);
    await (first as RejectedLessonJournal).rejectCompletion(
      'rejected-op',
      'CONTENT_STALE',
    );
    expect(await first.pendingCompletions(), isEmpty);
    await (first as ClosableLessonJournal).close();
    final reopened = createDurableLessonJournal(namespace: namespace);
    try {
      final rejected = await (reopened as RejectedLessonJournal)
          .rejectedCompletions();
      expect(rejected.single.payload, payload);
      expect(rejected.single.reasonCode, 'CONTENT_STALE');
      await reopened.clear();
    } finally {
      await (reopened as ClosableLessonJournal).close();
    }
  });

  testWidgets(
    'Android Drift factory persists and isolates actual native storage',
    (tester) async {
      const accountA = 'qa.native.journal.a';
      const accountB = 'qa.native.journal.b';
      final first = createDurableLessonJournal(namespace: accountA);
      await first.clear();
      await first.saveActive(draft('a'));
      await (first as AtomicLessonJournal).stageCompletionAndClearActive({
        'operationId': 'native-op',
        'lessonId': 'native-lesson',
        'answers': <Object?>[],
      });
      expect(await first.active(), isNull);
      await (first as ClosableLessonJournal).close();

      final reopened = createDurableLessonJournal(namespace: accountA);
      final other = createDurableLessonJournal(namespace: accountB);
      try {
        await other.clear();
        expect(
          (await reopened.pendingCompletions()).single['operationId'],
          'native-op',
        );
        expect(await other.pendingCompletions(), isEmpty);
        await other.saveActive(draft('b'));
        expect(await reopened.active(), isNull);
        expect((await other.active())?.completeKey, 'native-complete-b');
        await expectLater(
          reopened.enqueueCompletion({
            'operationId': 'native-op',
            'lessonId': 'changed',
            'answers': <Object?>[],
          }),
          throwsA(
            isA<JournalFailure>().having(
              (error) => error.code,
              'code',
              JournalFailure.operationConflict,
            ),
          ),
        );
      } finally {
        await reopened.clear();
        await other.clear();
        await (reopened as ClosableLessonJournal).close();
        await (other as ClosableLessonJournal).close();
      }
    },
  );

  testWidgets(
    'Android legacy migration retains backup and recovers after corrupt input',
    (tester) async {
      final namespace =
          'qa.native.migration.${DateTime.now().microsecondsSinceEpoch}';
      final key = 'journal.lesson.active.v1.$namespace';
      final preferences = SharedPreferencesAsync();
      await preferences.setString(key, '{invalid');
      final corrupt = createDurableLessonJournal(namespace: namespace);
      await expectLater(
        corrupt.active(),
        throwsA(
          isA<JournalFailure>().having(
            (error) => error.code,
            'code',
            JournalFailure.legacyCorrupt,
          ),
        ),
      );
      await (corrupt as ClosableLessonJournal).close();
      expect(await preferences.getString(key), '{invalid');

      final raw = jsonEncode(draft('migrated').toJson());
      await preferences.setString(key, raw);
      final recovered = createDurableLessonJournal(namespace: namespace);
      try {
        expect(
          (await recovered.active())?.completeKey,
          'native-complete-migrated',
        );
        expect(await preferences.getString(key), raw);
        await recovered.clear();
      } finally {
        await (recovered as ClosableLessonJournal).close();
        await preferences.remove(key);
      }
    },
  );
}
