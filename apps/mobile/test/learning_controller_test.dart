import 'dart:async';

import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer containerFor(LearningRepository repository) =>
    ProviderContainer(
      overrides: [learningRepositoryProvider.overrideWithValue(repository)],
    );

const choiceExercise = Exercise(
  id: 'choice-1',
  kind: ExerciseKind.choice,
  title: 'Choose',
  prompt: 'Bonjour',
  choices: [
    ExerciseChoice(id: 'hello', text: 'Hello'),
    ExerciseChoice(id: 'bye', text: 'Bye'),
  ],
  correctIds: ['hello'],
);

void main() {
  test(
    'English Score remains within its 0–160 scale after repeated lessons',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(learningStateProvider.notifier);
      for (var index = 0; index < 33; index++) {
        controller.claim(
          SessionReceipt(
            id: 'score-limit-$index',
            nodeId: 'score-node-$index',
            xp: 10,
            accuracy: 1,
            elapsed: const Duration(minutes: 1),
            firstCompletion: true,
            guest: false,
            placement: false,
          ),
        );
      }
      expect(container.read(learningStateProvider).score, 160);
      expect(container.read(learningStateProvider).xp, 330);
      expect(container.read(learningStateProvider).completedLessons, 33);
    },
  );

  test('unknown choices and tokens cannot enable checking', () async {
    final c = containerFor(MockLearningRepository(delay: Duration.zero));
    addTearDown(c.dispose);
    final vm = c.read(lessonControllerProvider.notifier);
    await vm.start(exercises: const [choiceExercise]);
    vm.select('unknown');
    expect(c.read(lessonControllerProvider).canCheck, false);
    await vm.start(
      exercises: const [
        Exercise(
          id: 'tokens',
          kind: ExerciseKind.wordBank,
          title: 'Translate',
          prompt: 'Hello',
          tokens: [ExerciseChoice(id: 'hello', text: 'Bonjour')],
          correctIds: ['hello'],
        ),
      ],
    );
    vm.toggleToken('unknown');
    expect(c.read(lessonControllerProvider).canCheck, false);
  });
  test(
    'guest completion does not consume the signed-in first reward',
    () async {
      final c = containerFor(MockLearningRepository(delay: Duration.zero));
      addTearDown(c.dispose);
      final vm = c.read(lessonControllerProvider.notifier);
      await vm.start(guest: true, exercises: const [choiceExercise]);
      vm.select('hello');
      await vm.check();
      await vm.next();
      await vm.claim();
      await vm.start(exercises: const [choiceExercise]);
      vm.select('hello');
      await vm.check();
      await vm.next();
      await vm.claim();
      expect(c.read(learningStateProvider).completedLessons, 1);
      expect(c.read(learningStateProvider).xp, 11);
    },
  );
  test(
    'pause and resume in the same controller keeps feedback and retries',
    () async {
      final container = containerFor(
        MockLearningRepository(delay: Duration.zero),
      );
      addTearDown(container.dispose);
      final controller = container.read(lessonControllerProvider.notifier);
      await controller.start(exercises: const [choiceExercise]);
      controller.select('bye');
      await controller.check();
      controller.pause();
      expect(
        container.read(lessonControllerProvider).stage,
        LessonStage.paused,
      );
      controller.resume();
      expect(
        container.read(lessonControllerProvider).stage,
        LessonStage.feedback,
      );
      await controller.next();
      expect(container.read(lessonControllerProvider).isRetry, isTrue);
      controller.pause();
      container.invalidate(lessonControllerProvider);
      final restored = container.read(lessonControllerProvider.notifier);
      restored.resume();
      restored.select('hello');
      await restored.check();
      await restored.next();
      expect(container.read(lessonControllerProvider).receipt!.accuracy, 0);
    },
  );
  test('invalid and duplicate CHECK issue at most one grade call', () async {
    final repository = _ControlledRepository()
      ..gradeCompleter = Completer<bool>();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(lessonControllerProvider.notifier);
    await controller.start(exercises: const [choiceExercise]);

    await controller.check();
    expect(repository.gradeCalls, 0);
    controller.select('hello');
    final first = controller.check();
    final duplicate = controller.check();
    expect(repository.gradeCalls, 1);
    expect(
      container.read(lessonControllerProvider).stage,
      LessonStage.checking,
    );
    repository.gradeCompleter!.complete(true);
    await Future.wait([first, duplicate]);
    expect(
      container.read(lessonControllerProvider).stage,
      LessonStage.feedback,
    );
  });

  test('grade failure preserves exact answer for retry', () async {
    final repository = _ControlledRepository()
      ..gradeError = const LearningFailure('Timeout');
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(lessonControllerProvider.notifier);
    await controller.start(exercises: const [choiceExercise]);
    controller.select('bye');

    await controller.check();

    final state = container.read(lessonControllerProvider);
    expect(state.stage, LessonStage.answering);
    expect(state.selectedId, 'bye');
    expect(state.error, 'Timeout');
  });

  test('wrong originals retry in order for at most two passes', () async {
    final repository = MockLearningRepository(delay: Duration.zero);
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(lessonControllerProvider.notifier);
    await controller.start(exercises: const [choiceExercise]);

    for (var pass = 0; pass < 3; pass++) {
      controller.select('bye');
      await controller.check();
      await controller.next();
      if (pass < 2) {
        final state = container.read(lessonControllerProvider);
        expect(state.stage, LessonStage.answering);
        expect(state.retryPass, pass + 1);
        expect(state.isRetry, true);
      }
    }
    final completed = container.read(lessonControllerProvider);
    expect(completed.stage, LessonStage.completed);
    expect(completed.originalCorrect, 0);
    expect(completed.attempted, 1);
    expect(repository.gradeCalls, 3);
  });

  test('pause and a new controller resume the exact draft', () async {
    final repository = MockLearningRepository(delay: Duration.zero);
    final container = containerFor(repository);
    addTearDown(container.dispose);
    var controller = container.read(lessonControllerProvider.notifier);
    await controller.start(exercises: const [choiceExercise]);
    controller.select('bye');
    controller.pause();
    container.invalidate(lessonControllerProvider);

    controller = container.read(lessonControllerProvider.notifier);
    controller.resume();
    final restored = container.read(lessonControllerProvider);
    expect(restored.stage, LessonStage.answering);
    expect(restored.selectedId, 'bye');
    expect(restored.current?.id, 'choice-1');
  });

  test('claim and replay cannot duplicate XP or frontier', () async {
    final repository = MockLearningRepository(delay: Duration.zero);
    final container = containerFor(repository);
    addTearDown(container.dispose);
    var controller = container.read(lessonControllerProvider.notifier);

    Future<void> complete() async {
      await controller.start(
        nodeId: 'node-0',
        exercises: const [choiceExercise],
      );
      controller.select('hello');
      await controller.check();
      await controller.next();
    }

    await complete();
    await controller.claim();
    await controller.claim();
    final first = container.read(learningStateProvider);
    expect(first.xp, greaterThan(0));
    expect(first.currentNode, 1);
    expect(first.completedLessons, 1);

    await complete();
    await controller.claim();
    final replay = container.read(learningStateProvider);
    expect(replay.xp, first.xp);
    expect(replay.currentNode, first.currentNode);
    expect(replay.streak, first.streak);
  });

  test(
    'media substitution changes task without answering or advancing',
    () async {
      final repository = MockLearningRepository(delay: Duration.zero);
      final container = containerFor(repository);
      addTearDown(container.dispose);
      final controller = container.read(lessonControllerProvider.notifier);
      await controller.start(exercises: [mockPracticeExercises.last]);

      controller.substituteMedia();

      final state = container.read(lessonControllerProvider);
      expect(state.index, 0);
      expect(state.current?.kind, ExerciseKind.textTranslation);
      expect(state.canCheck, false);
      expect(state.correct, isNull);
    },
  );

  test('disposed controller ignores delayed grade callback', () async {
    final repository = _ControlledRepository()
      ..gradeCompleter = Completer<bool>();
    final container = containerFor(repository);
    final controller = container.read(lessonControllerProvider.notifier);
    await controller.start(exercises: const [choiceExercise]);
    controller.select('hello');
    final check = controller.check();
    container.dispose();
    repository.gradeCompleter!.complete(true);
    await expectLater(check, completes);
  });
}

class _ControlledRepository extends MockLearningRepository {
  _ControlledRepository() : super(delay: Duration.zero);
  Completer<bool>? gradeCompleter;
  LearningFailure? gradeError;

  @override
  Future<bool> grade(Exercise exercise, LessonAnswer answer) async {
    gradeCalls++;
    if (gradeError case final error?) throw error;
    if (gradeCompleter case final completer?) return completer.future;
    return super.grade(exercise, answer);
  }
}
