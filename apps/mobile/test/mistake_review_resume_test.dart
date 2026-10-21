import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/domain/review_resume.dart';

void main() {
  final originals = [
    for (final id in ['a', 'b', 'c'])
      Exercise(
        id: id,
        kind: ExerciseKind.textTranslation,
        title: '',
        prompt: '',
        correctText: '',
      ),
  ];
  JournalAnswer answer(String id, int pass, bool correct) => JournalAnswer(
    exerciseId: id,
    attemptOrdinal: pass,
    answer: const {'kind': 'text', 'text': 'answer'},
    assisted: false,
    substituted: false,
    idempotencyKey: '$id-$pass',
    synced: true,
    correct: correct,
    expectedRevision: pass,
  );
  JournalSession session(List<JournalAnswer> answers) => JournalSession(
    nodeId: 'mistake-review',
    courseId: 'vi_en',
    lessonId: 'review_dynamic',
    lessonVersion: 'review.1',
    bundleHash: '',
    enrollmentRevision: 0,
    bundle: const {},
    startKey: 'start',
    completeKey: 'finish',
    answers: answers,
  );
  test('empty or unsynced review history starts at the original queue', () {
    expect(restoreReviewState(session([]), originals), isNull);
    expect(
      restoreReviewState(
        session([
          const JournalAnswer(
            exerciseId: 'a',
            attemptOrdinal: 0,
            answer: {},
            assisted: false,
            substituted: false,
            idempotencyKey: 'pending',
          ),
        ]),
        originals,
      ),
      isNull,
    );
  });
  test(
    'partial originals restore first-attempt counters and pending mistakes',
    () {
      final state = restoreReviewState(
        session([answer('a', 0, false), answer('b', 0, true)]),
        originals,
      )!;
      expect(state.current!.id, 'c');
      expect(state.attempted, 2);
      expect(state.originalCorrect, 1);
      expect(state.pendingMistakes.map((e) => e.id), ['a']);
    },
  );
  test('partial retry and exhausted second retry restore bounded queues', () {
    final first = [
      answer('a', 0, false),
      answer('b', 0, false),
      answer('c', 0, true),
    ];
    final partial = restoreReviewState(
      session([...first, answer('a', 1, false)]),
      originals,
    )!;
    expect(partial.retryPass, 1);
    expect(partial.current!.id, 'b');
    expect(partial.nextMistakes.map((e) => e.id), ['a']);
    final exhausted = restoreReviewState(
      session([
        ...first,
        answer('a', 1, false),
        answer('b', 1, true),
        answer('a', 2, false),
      ]),
      originals,
    )!;
    expect(exhausted.stage, LessonStage.feedback);
    expect(exhausted.retryPass, 2);
    expect(exhausted.correct, false);
  });
  test(
    'journal roundtrip keeps exact answer revision and accepts legacy fields',
    () {
      final saved = session([answer('a', 0, true)]);
      expect(
        JournalSession.fromJson(saved.toJson()).answers.single.expectedRevision,
        0,
      );
      final legacy = answer('a', 0, true).toJson()..remove('expectedRevision');
      expect(JournalAnswer.fromJson(legacy).expectedRevision, isNull);
    },
  );
}
