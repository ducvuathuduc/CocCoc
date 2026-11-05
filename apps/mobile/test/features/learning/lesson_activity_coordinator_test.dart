import 'dart:async';

import 'package:cocenglish/features/learning/application/lesson_activity_coordinator.dart';
import 'package:cocenglish/features/learning/domain/lesson_activity.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/services/lesson_activity_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLessonActivityGateway implements LessonActivityGateway {
  final calls = <Object>[];
  final firstSync = Completer<bool>();
  bool blockFirstSync = false;
  bool blockFirstEnd = false;
  bool throwOnCall = false;
  final firstEnd = Completer<bool>();

  @override
  Future<bool> sync(LessonActivitySnapshot snapshot) async {
    calls.add(snapshot);
    if (throwOnCall) throw StateError('plugin unavailable');
    if (blockFirstSync &&
        calls.whereType<LessonActivitySnapshot>().length == 1) {
      return firstSync.future;
    }
    return true;
  }

  @override
  Future<bool> end() async {
    calls.add('end');
    if (throwOnCall) throw StateError('plugin unavailable');
    if (blockFirstEnd && calls.where((call) => call == 'end').length == 1) {
      return firstEnd.future;
    }
    return true;
  }
}

LessonState lesson({
  LessonStage stage = LessonStage.answering,
  LessonStage resumeStage = LessonStage.answering,
  int index = 1,
  int attempted = 0,
  bool isRetry = false,
}) => LessonState(
  stage: stage,
  resumeStage: resumeStage,
  exercises: const [
    Exercise(id: 'one', kind: ExerciseKind.choice, title: 'One', prompt: '1'),
    Exercise(id: 'two', kind: ExerciseKind.choice, title: 'Two', prompt: '2'),
    Exercise(
      id: 'three',
      kind: ExerciseKind.choice,
      title: 'Three',
      prompt: '3',
    ),
  ],
  index: index,
  attempted: attempted,
  isRetry: isRetry,
  nodeId: 'node-4',
  startedAt: DateTime(2026, 10, 24, 8),
  originalTotal: 3,
  heartsEnforced: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cold cleanup completes before a newly started activity sync', () async {
    final gateway = FakeLessonActivityGateway()..blockFirstEnd = true;
    final coordinator = LessonActivityCoordinator(gateway);

    final cleanup = coordinator.initialize();
    final update = coordinator.update(lesson: lesson(), userId: 'u1');
    await Future<void>.delayed(Duration.zero);
    expect(gateway.calls, ['end']);

    gateway.firstEnd.complete(true);
    await Future.wait([cleanup, update]);
    expect(gateway.calls.first, 'end');
    expect(gateway.calls.last, isA<LessonActivitySnapshot>());

    await coordinator.initialize();
    expect(gateway.calls.where((call) => call == 'end'), hasLength(1));
  });

  test('progress stays monotonic through feedback pause and retry passes', () {
    final now = DateTime(2026, 10, 24, 8, 2);
    final feedback = LessonActivitySnapshot.fromLesson(
      lesson(stage: LessonStage.feedback, index: 1, attempted: 2),
      streak: 0,
      now: now,
    );
    final paused = LessonActivitySnapshot.fromLesson(
      lesson(
        stage: LessonStage.paused,
        resumeStage: LessonStage.feedback,
        index: 1,
        attempted: 2,
      ),
      streak: 0,
      now: now,
    );
    final retry = LessonActivitySnapshot.fromLesson(
      lesson(isRetry: true, index: 0, attempted: 3),
      streak: 0,
      now: now,
    );

    expect(feedback.completed, 2);
    expect(paused.completed, feedback.completed);
    expect(retry.completed, retry.total);
  });

  test('publishes progress, pause state, and ends completed lessons', () async {
    final gateway = FakeLessonActivityGateway();
    final coordinator = LessonActivityCoordinator(
      gateway,
      now: () => DateTime(2026, 10, 24, 8, 2),
    );
    await coordinator.initialize();
    gateway.calls.clear();

    await coordinator.update(lesson: lesson(), streak: 7, userId: 'u1');
    await coordinator.update(
      lesson: lesson(stage: LessonStage.paused),
      streak: 7,
      userId: 'u1',
    );
    await coordinator.update(
      lesson: lesson(stage: LessonStage.completed),
      streak: 7,
      userId: 'u1',
    );

    final active = gateway.calls[0] as LessonActivitySnapshot;
    final paused = gateway.calls[1] as LessonActivitySnapshot;
    expect(active.toChannelArguments(), {
      'lessonId': 'node-4',
      'completed': 1,
      'total': 3,
      'hearts': 5,
      'unlimited': false,
      'elapsedSeconds': 120,
      'streak': 7,
      'paused': false,
    });
    expect(paused.paused, isTrue);
    expect(gateway.calls.last, 'end');
    expect(coordinator.retainedSession, isNull);
  });

  test(
    'end wins over queued progress and stale sync cannot recreate',
    () async {
      final gateway = FakeLessonActivityGateway()..blockFirstSync = true;
      final coordinator = LessonActivityCoordinator(gateway);
      await coordinator.initialize();
      gateway.calls.clear();

      final first = coordinator.update(lesson: lesson(index: 0), userId: 'u1');
      await Future<void>.delayed(Duration.zero);
      final stale = coordinator.update(lesson: lesson(index: 2), userId: 'u1');
      final ended = coordinator.end();
      gateway.firstSync.complete(true);
      await Future.wait([first, stale, ended]);

      expect(gateway.calls.whereType<LessonActivitySnapshot>(), hasLength(1));
      expect(gateway.calls.last, 'end');
    },
  );

  test('gateway failures never escape into learning', () async {
    final gateway = FakeLessonActivityGateway()..throwOnCall = true;
    final coordinator = LessonActivityCoordinator(gateway);
    await coordinator.initialize();

    await expectLater(
      coordinator.update(lesson: lesson(), userId: 'u1'),
      completes,
    );
    await expectLater(coordinator.end(), completes);
  });

  test('unsupported platform and missing plugin are clean no-ops', () async {
    final snapshot = LessonActivitySnapshot.fromLesson(
      lesson(),
      streak: 0,
      now: DateTime(2026, 10, 24, 8, 2),
    );
    final unsupported = MethodChannelLessonActivityGateway(supported: false);
    final unavailable = MethodChannelLessonActivityGateway(
      channel: const MethodChannel('cocenglish/test_missing_activity_plugin'),
      supported: true,
    );

    expect(await unsupported.sync(snapshot), isFalse);
    expect(await unsupported.end(), isFalse);
    expect(await unavailable.sync(snapshot), isFalse);
    expect(await unavailable.end(), isFalse);
  });

  test('account switch clears the retained activity', () async {
    final gateway = FakeLessonActivityGateway();
    final coordinator = LessonActivityCoordinator(gateway);
    await coordinator.initialize();
    gateway.calls.clear();
    await coordinator.update(lesson: lesson(), userId: 'u1');

    await coordinator.accountChanged('u2');

    expect(coordinator.retainedSession, isNull);
    expect(gateway.calls.last, 'end');
  });

  test('resume route requires matching retained account and active lesson', () {
    const retained = LessonActivitySession(lessonId: 'node-4', userId: 'u1');
    expect(
      lessonActivityResumeLocation(
        authRequired: true,
        signedInUserId: null,
        retained: retained,
      ),
      '/login',
    );
    expect(
      lessonActivityResumeLocation(
        authRequired: true,
        signedInUserId: 'u2',
        retained: retained,
      ),
      '/home',
    );
    expect(
      lessonActivityResumeLocation(
        authRequired: true,
        signedInUserId: 'u1',
        retained: retained,
      ),
      '/lesson/node-4',
    );
    expect(
      lessonActivityResumeLocation(
        authRequired: false,
        signedInUserId: null,
        retained: null,
      ),
      '/home',
    );
  });
}
