import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('language requires a selection and Back retains it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MainApp(initial: OnboardingState(step: OnboardingStep.language)),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'CONTINUE'),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'CONTINUE'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('How much French do you know?'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('For English speakers'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'CONTINUE'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('reminder preview can be cancelled without losing the step', (
    tester,
  ) async {
    await tester.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.reminder,
          language: 'French',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMIND ME TO PRACTICE'));
    await tester.pumpAndSettle();
    expect(find.text('Practice reminders'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Practice reminders'), findsNothing);
    expect(find.text('REMIND ME TO PRACTICE'), findsOneWidget);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final step in OnboardingStep.values.where(
      (s) => s != OnboardingStep.building,
    )) {
      testWidgets('${step.name} fits width $width with text scale 2', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MainApp(
            initial: OnboardingState(
              step: step,
              language: 'French',
              knowledge: 1,
              reasonIds: {0},
              plan: 0,
              startPoint: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (step != OnboardingStep.welcome &&
            step != OnboardingStep.lessonEntry) {
          final label = step == OnboardingStep.goal
              ? 'I’M COMMITTED'
              : step == OnboardingStep.reminder
              ? 'REMIND ME TO PRACTICE'
              : step == OnboardingStep.widget
              ? 'ADD WIDGET'
              : 'CONTINUE';
          expect(find.text(label).hitTestable(), findsOneWidget);
        }
      });
    }
  }
}
