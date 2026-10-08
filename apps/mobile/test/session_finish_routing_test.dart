import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/league_result_controller.dart';
import 'package:cocenglish/features/progress/presentation/league_result_screen.dart';
import 'package:cocenglish/features/progress/presentation/year_review_screen.dart';
import 'package:cocenglish/features/progress/presentation/streak_widgets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'settings opens all new histories and preserves learner progress',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
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
      final context = t.element(find.byTooltip('Practice'));
      final router = GoRouter.of(context);
      final c = ProviderScope.containerOf(context);
      final learning = c.read(learningStateProvider);
      final gems = c.read(previewControllerProvider).bonusGems;
      router.push('/settings');
      await t.pumpAndSettle();
      for (final (title, screen) in <(String, Type)>[
        ('Streak widgets', StreakWidgetsScreen),
        ('2025 Year in Review', YearReviewScreen),
        ('League history', LeagueResultScreen),
      ]) {
        await t.scrollUntilVisible(
          find.text(title),
          220,
          scrollable: find.byType(Scrollable).last,
        );
        await t.tap(find.text(title));
        await t.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget);
        router.pop();
        await t.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
      }
      router.push('/league/results');
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Close').hitTestable());
      await t.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      router.push('/league/results');
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      for (var replay = 0; replay < 2; replay++) {
        router.push('/league/results');
        await t.pumpAndSettle();
        for (final stage in [
          LeagueResultStage.result,
          LeagueResultStage.promotion,
          LeagueResultStage.reward,
        ]) {
          expect(c.read(leagueResultControllerProvider).stage, stage);
          await t.tap(find.text('CONTINUE').hitTestable());
          await t.pumpAndSettle();
        }
        expect(find.text('Settings'), findsOneWidget);
      }
      expect(c.read(learningStateProvider).xp, learning.xp);
      expect(c.read(learningStateProvider).streak, learning.streak);
      expect(c.read(previewControllerProvider).bonusGems, gems);
      expect(c.read(learningStateProvider).gems, learning.gems);
      expect(t.takeException(), isNull);
    },
  );
}
