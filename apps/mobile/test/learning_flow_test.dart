import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'complete the native lesson, claim once, return to the unlocked path',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'French',
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
      Future<void> tapText(String text) async {
        final f = find.text(text).hitTestable().last;
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      for (var i = 0; i < 10; i++) {
        final e = c.read(lessonControllerProvider).current!;
        switch (e.kind) {
          case ExerciseKind.imageChoice ||
              ExerciseKind.choice ||
              ExerciseKind.listenChoice:
            await tapText(
              e.choices.firstWhere((v) => v.id == e.correctIds.first).text,
            );
          case ExerciseKind.wordBank || ExerciseKind.sentenceOrder:
            for (final id in e.correctIds) {
              await tapText(e.tokens.firstWhere((v) => v.id == id).text);
            }
          case ExerciseKind.matchPairs:
            for (final pair in e.pairs.entries) {
              await tapText(pair.key);
              await tapText(pair.value);
            }
          case ExerciseKind.textTranslation ||
              ExerciseKind.fillBlank ||
              ExerciseKind.dictation ||
              ExerciseKind.dialogueTurn ||
              ExerciseKind.storyQuestion ||
              ExerciseKind.speakRepeat:
            await tester.enterText(find.byType(TextField), e.correctText);
            await tester.pumpAndSettle();
        }
        await tapText('CHECK');
        expect(find.text('Excellent!'), findsOneWidget);
        await tapText('CONTINUE');
      }
      expect(find.text('Flawless'), findsOneWidget);
      await tapText('CLAIM XP');
      expect(c.read(learningStateProvider).xp, 20);
      await c.read(lessonControllerProvider.notifier).claim();
      expect(c.read(learningStateProvider).xp, 20);
      for (var i = 0; i < 2; i++) {
        await tapText('CONTINUE');
      }
      await tapText('I’M COMMITTED');
      await tapText('CONTINUE');
      await tapText('MAYBE LATER');
      await tapText('NOT NOW');
      expect(find.text('Use basic phrases'), findsOneWidget);
      expect(c.read(learningStateProvider).currentNode, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('finished onboarding opens path and a selectable lesson', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'French',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Use basic phrases'), findsOneWidget);
    await tester.tap(find.byTooltip('Start lesson 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START +20 XP'));
    await tester.pumpAndSettle();
    expect(find.text('Select the correct image'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'CHECK'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('the woman').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHECK'));
    await tester.pumpAndSettle();
    expect(find.text('Excellent!'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Select the correct translation'), findsOneWidget);
  });
}
