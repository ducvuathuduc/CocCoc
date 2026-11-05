import 'learning_models.dart';

/// Display-only lesson facts sent to ActivityKit. Rewards remain owned by the
/// normal lesson completion flow and are never accepted back from the widget.
class LessonActivitySnapshot {
  const LessonActivitySnapshot({
    required this.lessonId,
    required this.completed,
    required this.total,
    required this.hearts,
    required this.unlimited,
    required this.elapsedSeconds,
    required this.streak,
    required this.paused,
  });

  factory LessonActivitySnapshot.fromLesson(
    LessonState lesson, {
    required int streak,
    required DateTime now,
  }) {
    final total =
        (lesson.originalTotal > 0
                ? lesson.originalTotal
                : lesson.exercises.length)
            .clamp(1, 999);
    final effectiveStage = lesson.stage == LessonStage.paused
        ? lesson.resumeStage
        : lesson.stage;
    final indexed = effectiveStage == LessonStage.feedback
        ? lesson.index + 1
        : lesson.index;
    final answered = lesson.stage == LessonStage.completed || lesson.isRetry
        ? total
        : lesson.attempted > indexed
        ? lesson.attempted
        : indexed;
    return LessonActivitySnapshot(
      lessonId: lesson.nodeId.trim().substring(
        0,
        lesson.nodeId.trim().length.clamp(0, 128),
      ),
      completed: answered.clamp(0, total),
      total: total,
      hearts: lesson.hearts.clamp(0, 99),
      unlimited: !lesson.heartsEnforced,
      elapsedSeconds: now
          .difference(lesson.startedAt ?? now)
          .inSeconds
          .clamp(0, 7 * 24 * 60 * 60),
      streak: streak.clamp(0, 9999),
      paused: lesson.stage == LessonStage.paused,
    );
  }

  final String lessonId;
  final int completed, total, hearts, elapsedSeconds, streak;
  final bool unlimited, paused;

  Map<String, Object> toChannelArguments() => {
    'lessonId': lessonId,
    'completed': completed,
    'total': total,
    'hearts': hearts,
    'unlimited': unlimited,
    'elapsedSeconds': elapsedSeconds,
    'streak': streak,
    'paused': paused,
  };
}

class LessonActivitySession {
  const LessonActivitySession({required this.lessonId, required this.userId});

  final String lessonId;
  final String? userId;
}

/// Resolves the fixed ActivityKit resume link from retained in-memory state.
/// The URL supplies no lesson identifier, so it cannot start arbitrary work.
String lessonActivityResumeLocation({
  required bool authRequired,
  required String? signedInUserId,
  required LessonActivitySession? retained,
}) {
  if (authRequired && signedInUserId == null) return '/login';
  if (retained == null || retained.lessonId.isEmpty) return '/home';
  if (authRequired && retained.userId != signedInUserId) return '/home';
  return '/lesson/${Uri.encodeComponent(retained.lessonId)}';
}
