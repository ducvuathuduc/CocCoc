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
      // Entry points follow Duolingo: Streak widgets under Settings >
      // Preferences, Year in Review on the own profile, League history from
      // the league trophy row.
      router.push('/settings');
      await t.pumpAndSettle();
      await t.tap(find.text('Preferences'));
      await t.pumpAndSettle();
      await t.tap(find.text('Streak widgets'));
      await t.pumpAndSettle();
      expect(find.byType(StreakWidgetsScreen), findsOneWidget);
      router.pop();
      await t.pumpAndSettle();
      router.pop();
      await t.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      router.pop();
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('Profile'));
      await t.pumpAndSettle();
      final review = find.text('2025 YEAR IN REVIEW');
      await t.ensureVisible(review);
      await t.pumpAndSettle();
      await t.tap(review);
      await t.pumpAndSettle();
      expect(find.byType(YearReviewScreen), findsOneWidget);
      router.pop();
      await t.pumpAndSettle();

      c.read(previewControllerProvider.notifier).optIntoLeague();
      router.go('/league');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('league-history')));
      await t.pumpAndSettle();
      expect(find.byType(LeagueResultScreen), findsOneWidget);
      router.pop();
      await t.pumpAndSettle();

      router.push('/settings');
      await t.pumpAndSettle();
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
