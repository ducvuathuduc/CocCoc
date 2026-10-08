import 'package:cocenglish/core/design/character_motion.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/presentation/lesson_results.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const dialogue = Exercise(
  id: 'lily-greeting',
  kind: ExerciseKind.dialogueTurn,
  title: 'Respond to Lily',
  prompt: 'Hello!',
  correctText: 'Hello',
  meaning: 'Xin chào!',
);
const spoken = Exercise(
  id: 'spoken-greeting',
  kind: ExerciseKind.speakRepeat,
  title: 'Speak this sentence',
  prompt: 'Hello, I am Sam.',
  correctText: 'Hello, I am Sam.',
);

Future<ProviderContainer> openLesson(
  WidgetTester tester,
  Exercise exercise,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container
      .read(lessonControllerProvider.notifier)
      .start(exercises: [exercise]);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: referenceTheme(), home: const LessonScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('Lily reply offers speech fallback without grading an answer', (
    tester,
  ) async {
    final container = await openLesson(tester, dialogue);
    expect(
      tester.widget<CharacterMotion>(find.byType(CharacterMotion)).character,
      LessonCharacter.lily,
    );
    expect(tester.getTopLeft(find.text('Respond to Lily')).dx, 16);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text("CAN'T SPEAK NOW"));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(container.read(lessonControllerProvider).attempted, 0);
    await tester.enterText(find.byType(TextField), 'Hello');
    expect(container.read(lessonControllerProvider).current!.id, dialogue.id);
    expect(container.read(lessonControllerProvider).text, 'Hello');
  });

  testWidgets('speaking action exposes a usable text alternative', (
    tester,
  ) async {
    final container = await openLesson(tester, spoken);
    await tester.tap(find.byTooltip('Speak the sentence'));
    await tester.pumpAndSettle();
    expect(find.text('Speaking unavailable'), findsOneWidget);
    expect(container.read(lessonControllerProvider).attempted, 0);
    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("CAN'T SPEAK NOW"));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(
      container.read(lessonControllerProvider).current!.correctText,
      spoken.correctText,
    );
  });

  testWidgets('guest result uses product copy and actual accessible metrics', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(lessonControllerProvider.notifier);
    await tester.runAsync(() async {
      await controller.start(exercises: [dialogue], guest: true);
      controller.updateText('Hello');
      await controller.check();
      await controller.next();
    });
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: referenceTheme(),
          home: const LessonResults(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Practice complete'), findsOneWidget);
    expect(find.bySemanticsLabel('Accuracy, 100 percent'), findsOneWidget);
    expect(find.textContaining('ranked XP'), findsNothing);
    semantics.dispose();
  });

  test(
    'dialogue fallback is idempotent and pause preserves draft and meaning',
    () async {
      final container = ProviderContainer(
        overrides: [
          learningRepositoryProvider.overrideWithValue(
            MockLearningRepository(delay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);
      final vm = container.read(lessonControllerProvider.notifier);
      await vm.start(exercises: [dialogue, spoken]);
      vm.substituteMedia();
      vm.updateText('Hello');
      vm.substituteMedia();
      vm.pause();
      vm.resume();
      var state = container.read(lessonControllerProvider);
      expect(state.text, 'Hello');
      expect(state.current!.meaning, 'Xin chào!');
      expect(state.current!.kind, ExerciseKind.dialogueTurn);
      expect(state.textAlternative, isTrue);
      expect(state.attempted, 0);
      await vm.check();
      await vm.next();
      state = container.read(lessonControllerProvider);
      expect(state.textAlternative, isFalse);
      expect(state.text, isEmpty);
      expect(state.correctStreak, 1);
    },
  );

  test(
    'media fallback preserves a pre-existing draft and expected answer',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final vm = container.read(lessonControllerProvider.notifier);
      await vm.start(
        exercises: [spoken.copyWith(meaning: 'Xin chào, tôi là Sam.')],
      );
      vm.updateText('Hello, I');
      vm.substituteMedia();
      final state = container.read(lessonControllerProvider);
      expect(state.text, 'Hello, I');
      expect(state.current!.id, spoken.id);
      expect(state.current!.correctText, spoken.correctText);
      expect(state.current!.meaning, 'Xin chào, tôi là Sam.');
      expect(state.current!.kind, ExerciseKind.textTranslation);
      expect(state.assisted, isTrue);
    },
  );

  test('streak counts successful grades, survives failure and resets on a wrong answer', () async {
    final repo = _FailingGradeRepository();
    final container = ProviderContainer(
      overrides: [learningRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final vm = container.read(lessonControllerProvider.notifier);
    await vm.start(exercises: [dialogue, spoken]);
    vm.updateText('Hello');
    await vm.check();
    await vm.check();
    expect(container.read(lessonControllerProvider).correctStreak, 1);
    await vm.next();
    vm.updateText('Goodbye');
    repo.fail = true;
    await vm.check();
    var state = container.read(lessonControllerProvider);
    expect(state.correctStreak, 1);
    expect(state.text, 'Goodbye');
    expect(state.stage, LessonStage.answering);
    expect(state.attempted, 1);
    repo.fail = false;
    await vm.check();
    state = container.read(lessonControllerProvider);
    expect(state.correctStreak, 0);
    await vm.next();
    expect(container.read(lessonControllerProvider).isRetry, isTrue);
    expect(container.read(lessonControllerProvider).textAlternative, isFalse);
  });

  testWidgets(
    'Lily audio notice and correct meaning preserve the entered answer',
    (tester) async {
      final container = await openLesson(tester, dialogue);
      await tester.tap(find.byTooltip('Listen to Lily'));
      await tester.pumpAndSettle();
      expect(find.text('Audio unavailable'), findsOneWidget);
      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("CAN'T SPEAK NOW"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello');
      final vm = container.read(lessonControllerProvider.notifier);
      await tester.runAsync(vm.check);
      await tester.pumpAndSettle();
      expect(find.text('Meaning:'), findsOneWidget);
      expect(find.text('Xin chào!'), findsOneWidget);
      expect(
        tester.widget<CharacterMotion>(find.byType(CharacterMotion)).reaction,
        CharacterReaction.correct,
      );
      expect(container.read(lessonControllerProvider).text, 'Hello');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320 text two keeps Lily alternative, correction and next reachable',
    (tester) async {
      final container = await openLesson(tester, dialogue);
      tester.view.physicalSize = const Size(320, 844);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const LessonScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("CAN'T SPEAK NOW"));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Wrong');
      await tester.runAsync(
        container.read(lessonControllerProvider.notifier).check,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CharacterMotion>(find.byType(CharacterMotion)).reaction,
        CharacterReaction.incorrect,
      );
      expect(find.text('Correct Answer:'), findsOneWidget);
      expect(find.text('GOT IT').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('same Lily exercise retry clears the visible editor', (
    tester,
  ) async {
    final container = await openLesson(tester, dialogue);
    await tester.tap(find.text("CAN'T SPEAK NOW"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wrong');
    final vm = container.read(lessonControllerProvider.notifier);
    await tester.runAsync(vm.check);
    await tester.pumpAndSettle();
    await tester.runAsync(vm.next);
    await tester.pumpAndSettle();
    await tester.tap(find.text("CAN'T SPEAK NOW"));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(container.read(lessonControllerProvider).text, isEmpty);
    expect(container.read(lessonControllerProvider).retryPass, 1);
    expect(
      tester.widget<CharacterMotion>(find.byType(CharacterMotion)).epoch,
      '${dialogue.id}:1',
    );
  });
}

class _FailingGradeRepository extends MockLearningRepository {
  _FailingGradeRepository() : super(delay: Duration.zero);
  bool fail = false;
  @override
  Future<bool> grade(Exercise exercise, LessonAnswer answer) {
    if (fail) throw const LearningFailure('Try again');
    return super.grade(exercise, answer);
  }
}
