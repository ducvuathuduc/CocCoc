import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/learning_models.dart';
import '../domain/lesson_activity.dart';
import '../services/lesson_activity_gateway.dart';

final lessonActivityGatewayProvider = Provider<LessonActivityGateway>(
  (ref) => MethodChannelLessonActivityGateway(),
);

final lessonActivityCoordinatorProvider = Provider<LessonActivityCoordinator>(
  (ref) => LessonActivityCoordinator(ref.watch(lessonActivityGatewayProvider)),
);

class LessonActivityCoordinator {
  LessonActivityCoordinator(this._gateway, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LessonActivityGateway _gateway;
  final DateTime Function() _now;
  Future<void> _queue = Future<void>.value();
  int _revision = 0;
  bool _initialized = false;
  bool _sessionMayExist = false;
  LessonActivitySession? _retainedSession;

  LessonActivitySession? get retainedSession => _retainedSession;

  /// Ends an ActivityKit session that may have survived a prior app process.
  /// Every later operation is queued behind this cleanup.
  Future<void> initialize() {
    if (_initialized) return _queue;
    _initialized = true;
    return _serial(_safeEnd);
  }

  Future<void> update({
    required LessonState lesson,
    int streak = 0,
    String? userId,
  }) {
    initialize();
    final active =
        lesson.current != null &&
        const {
          LessonStage.answering,
          LessonStage.checking,
          LessonStage.feedback,
          LessonStage.paused,
        }.contains(lesson.stage);
    if (!active) return end();

    final snapshot = LessonActivitySnapshot.fromLesson(
      lesson,
      streak: streak,
      now: _now(),
    );
    final revision = ++_revision;
    _sessionMayExist = true;
    _retainedSession = LessonActivitySession(
      lessonId: snapshot.lessonId,
      userId: userId,
    );
    return _serial(() async {
      if (revision != _revision) return;
      try {
        await _gateway.sync(snapshot);
      } catch (_) {
        // Live Activities are optional and can never interrupt a lesson.
      }
    });
  }

  Future<void> end() {
    final initialized = initialize();
    _retainedSession = null;
    _revision += 1;
    if (!_sessionMayExist) return initialized;
    _sessionMayExist = false;
    return _serial(_safeEnd);
  }

  Future<void> accountChanged(String? userId) {
    final initialized = initialize();
    final retained = _retainedSession;
    if (retained == null || retained.userId == userId) {
      return initialized;
    }
    return end();
  }

  Future<void> _safeEnd() async {
    try {
      await _gateway.end();
    } catch (_) {
      // Missing plugins and platform denial are intentionally non-fatal.
    }
  }

  Future<void> _serial(Future<void> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }
}
