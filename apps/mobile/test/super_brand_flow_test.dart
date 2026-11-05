import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/super_trial/presentation/super_trial_screen.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final size in [const Size(360, 800), const Size(430, 932)]) {
    testWidgets('Super branding Continue opens trial once at ${size.width}', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await t.pumpAndSettle();
      final router = GoRouter.of(t.element(find.byTooltip('Practice')));
      final results = <bool?>[];
      router.push<bool>('/super/brand').then(results.add);
      await t.pumpAndSettle();
      final next = find.byKey(const ValueKey('super-brand-continue'));
      expect(next, findsOneWidget);
      await t.tap(next);
      await t.pumpAndSettle();
      expect(find.byType(SuperTrialScreen), findsOneWidget);
      await t.tap(find.text('NO THANKS'));
      await t.pumpAndSettle();
      expect(results, [false]);
      expect(find.byType(SuperTrialScreen), findsNothing);
      expect(find.byTooltip('Practice'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
