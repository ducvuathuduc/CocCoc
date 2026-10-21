import '../../../core/cache/lesson_journal.dart';
import 'learning_models.dart';

/// Reconstructs the bounded original/retry queue from durable answer evidence.
/// This controls navigation only; the server owns grades, resolution and XP.
LessonState? restoreReviewState(
  JournalSession session,
  List<Exercise> originals,
) {
  final answers = session.answers
      .where((a) => a.synced && a.correct != null)
      .toList();
  if (answers.isEmpty || originals.isEmpty) return null;
  JournalAnswer? attempt(Exercise exercise, int pass) => answers
      .where((a) => a.exerciseId == exercise.id && a.attemptOrdinal == pass)
      .firstOrNull;
  final first = originals
      .map((e) => attempt(e, 0))
      .whereType<JournalAnswer>()
      .toList();
  var queue = originals;
  for (var pass = 0; pass <= 2; pass++) {
    final missed = <Exercise>[];
    for (var index = 0; index < queue.length; index++) {
      final item = attempt(queue[index], pass);
      if (item == null) {
        return LessonState(
          exercises: queue,
          index: index,
          stage: LessonStage.answering,
          nodeId: session.nodeId,
          originalTotal: originals.length,
          attempted: first.length,
          originalCorrect: first.where((a) => a.correct == true).length,
          retryPass: pass,
          isRetry: pass > 0,
          pendingMistakes: pass == 0 ? missed : const [],
          nextMistakes: pass > 0 ? missed : const [],
        );
      }
      if (item.correct == false) missed.add(queue[index]);
    }
    if (missed.isEmpty || pass == 2) {
      return LessonState(
        exercises: queue,
        index: queue.length - 1,
        stage: LessonStage.feedback,
        correct: attempt(queue.last, pass)!.correct,
        nodeId: session.nodeId,
        originalTotal: originals.length,
        attempted: first.length,
        originalCorrect: first.where((a) => a.correct == true).length,
        retryPass: pass,
        isRetry: pass > 0,
        nextMistakes: pass > 0 ? missed : const [],
      );
    }
    queue = missed;
  }
  return null;
}
