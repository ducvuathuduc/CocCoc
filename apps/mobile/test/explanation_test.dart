import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:cocenglish/features/learning/presentation/explanation_screen.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/data/english_explanations.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'explanation back retains wrong selection and feedback without advancing',
    (tester) async {
      await tester.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Start lesson 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START +20 XP'));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(LessonScreen)),
      );
      final vm = c.read(lessonControllerProvider.notifier);
      vm.select('boy');
      final checked = vm.check();
      await tester.pump(const Duration(milliseconds: 40));
      await checked;
      await tester.pumpAndSettle();
      final before = c.read(lessonControllerProvider);
      await tester.tap(find.text('EXPLAIN MY ANSWER'));
      await tester.pumpAndSettle();
      expect(find.text('Replaced'), findsOneWidget);
      await tester.tap(find.byTooltip('Helpful'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE LESSON'));
      await tester.pumpAndSettle();
      final after = c.read(lessonControllerProvider);
      expect(after.index, before.index);
      expect(after.selectedId, 'boy');
      expect(after.correct, isFalse);
      expect(after.attempted, before.attempted);
      expect(find.text('Incorrect'), findsOneWidget);
    },
  );
  test(
    'every active English exercise has an authored explanation and answer',
    () {
      for (final exercise in [
        ...mockEnglishExercises,
        ...mockPracticeExercises,
      ]) {
        expect(
          englishExplanations.containsKey(exercise.id),
          isTrue,
          reason: exercise.id,
        );
        expect(exerciseAnswer(exercise), isNotEmpty, reason: exercise.id);
      }
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('long explanation fits $width text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lessonControllerProvider.overrideWith(_LongExplanation.new),
            ],
            child: MaterialApp(
              theme: referenceTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: const ExplanationScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('CONTINUE LESSON'), findsOneWidget);
      });
    }
  }
}

class _LongExplanation extends LessonController {
  @override
  LessonState build() => LessonState(
    stage: LessonStage.feedback,
    exercises: [mockEnglishExercises[3]],
    correct: false,
    matchedPairs: const {
      'woman': 'người đàn ông',
      'man': 'người phụ nữ',
      'bear': 'con gấu',
    },
  );
}
