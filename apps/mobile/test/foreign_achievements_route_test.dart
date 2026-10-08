import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/achievements_controller.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/application/profile_achievements_provider.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('foreign awards are immutable read-only progress within each goal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(profileAchievementsProvider('missing')), isNull);
    for (final id in sampleProfileIds) {
      final snapshot = container.read(profileAchievementsProvider(id))!;
      expect(snapshot.profile.userId, id);
      for (final award in snapshot.awards) {
        expect(award.claimAvailable, isFalse);
        expect(
          award.progressFor(snapshot.profile.xp),
          inInclusiveRange(0, award.goal),
          reason: '$id:${award.id}',
        );
      }
      expect(() => snapshot.awards.clear(), throwsUnsupportedError);
    }
  });
  Future<BuildContext> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byTooltip('Profile'));
  }

  testWidgets(
    'foreign View all retains owner through achievement list and Back',
    (tester) async {
      final context = await open(tester);
      final container = ProviderScope.containerOf(context);
      final router = GoRouter.of(context);
      final xpBefore = container.read(learningStateProvider).xp;
      router.push('/profile/Alex');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('VIEW ALL'));
      await tester.pumpAndSettle();
      final profilePosition = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final profileOffset = profilePosition.pixels;
      await tester.tap(find.text('VIEW ALL'));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['profile'], 'Alex');
      expect(find.text('120'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
      expect(find.byTooltip('Monthly badges'), findsNothing);
      await tester.ensureVisible(find.text('Perfect Week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfect Week'));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['profile'], 'Alex');
      expect(find.text('CLAIM REWARD'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/achievements');
      expect(router.state.uri.queryParameters['profile'], 'Alex');
      expect(find.text('Perfect Week'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile/Alex');
      expect(find.text('VIEW ALL').hitTestable(), findsOneWidget);
      expect(profilePosition.pixels, closeTo(profileOffset, 1));
      expect(container.read(learningStateProvider).xp, xpBefore);
    },
  );

  testWidgets('foreign record cards do not invent learner record dates', (
    tester,
  ) async {
    final context = await open(tester);
    final router = GoRouter.of(context);
    router.go('/achievements?profile=Alex');
    await tester.pumpAndSettle();
    expect(find.text('Personal Records'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
    router.go('/achievements');
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'foreign detail cannot claim learner rewards; unknown owner fails safely',
    (tester) async {
      final context = await open(tester);
      final container = ProviderScope.containerOf(context);
      final router = GoRouter.of(context);
      final claimsBefore = container
          .read(achievementsControllerProvider)
          .claimedIds;
      final xpBefore = container.read(learningStateProvider).xp;
      router.push('/achievements/perfect-week?profile=Alex');
      await tester.pumpAndSettle();
      expect(find.text('CLAIM REWARD'), findsNothing);
      expect(find.byTooltip('Share'), findsNothing);
      expect(find.text('Perfect Week'), findsOneWidget);
      router.go('/achievements?profile=missing');
      await tester.pumpAndSettle();
      expect(find.text('Profile unavailable'), findsOneWidget);
      router.go('/achievements/perfect-week?profile=missing');
      await tester.pumpAndSettle();
      expect(find.text('Achievement unavailable'), findsOneWidget);
      expect(
        container.read(achievementsControllerProvider).claimedIds,
        claimsBefore,
      );
      expect(container.read(learningStateProvider).xp, xpBefore);
      expect(tester.takeException(), isNull);
    },
  );
}
