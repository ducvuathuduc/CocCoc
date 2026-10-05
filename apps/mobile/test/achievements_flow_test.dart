import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/achievements_controller.dart';
import 'package:cocenglish/features/progress/domain/achievement_models.dart';
import 'package:cocenglish/features/progress/presentation/achievements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('claim accepts one earned fixture and rejects duplicate locked and invalid IDs', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(achievementsControllerProvider.notifier);

    expect(
      controller.claim('perfect-week', currentXp: 0),
      AchievementClaimResult.claimed,
    );
    expect(
      controller.claim('perfect-week', currentXp: 0),
      AchievementClaimResult.alreadyClaimed,
    );
    expect(
      controller.claim('xp-olympian', currentXp: 24),
      AchievementClaimResult.locked,
    );
    expect(
      controller.claim('missing', currentXp: 1000),
      AchievementClaimResult.notFound,
    );
    expect(container.read(achievementsControllerProvider).claimedIds, {
      'perfect-week',
    });
  });

  testWidgets(
    'source award opens matching detail, shares locally, and keeps claim across Back',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: _Host(home: AchievementsScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Records'), findsOneWidget);
      expect(find.text('Awards'), findsOneWidget);
      await tester.tap(find.text('Perfect Week').last);
      await tester.pumpAndSettle();
      expect(find.text('DEC 6, 2025'), findsOneWidget);
      expect(find.textContaining('30 perfect weeks'), findsOneWidget);

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      expect(find.text('Share preview'), findsOneWidget);
      expect(find.textContaining('Perfect Week'), findsWidgets);
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CLAIM REWARD'));
      await tester.pumpAndSettle();
      expect(find.text('CLAIMED'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfect Week').last);
      await tester.pumpAndSettle();
      expect(find.text('CLAIMED'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('locked XP and invalid ID render safe native details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: _Host(
          home: AchievementDetailScreen(achievementId: 'xp-olympian'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Reach 100 XP to unlock this achievement.'),
      findsOneWidget,
    );
    expect(find.text('0/100'), findsOneWidget);
    expect(find.text('CLAIM REWARD'), findsNothing);

    await tester.pumpWidget(
      const ProviderScope(
        child: _Host(home: AchievementDetailScreen(achievementId: 'missing')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Achievement unavailable'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'achievement and monthly source grids render width$width text$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 932);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              child: _Host(
                media: MediaQueryData(
                  size: Size(width, 932),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                home: const AchievementsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Achievements'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byTooltip('Monthly badges'));
          await tester.pumpAndSettle();
          expect(find.text('2025 Badges'), findsOneWidget);
          expect(find.text('2024 Badges'), findsOneWidget);
          await tester.drag(find.byType(ListView).last, const Offset(0, -4000));
          await tester.pumpAndSettle();
          expect(find.text('2023 Badges'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Host extends StatelessWidget {
  const _Host({required this.home, this.media});

  final Widget home;
  final MediaQueryData? media;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: referenceTheme(),
    home: media == null ? home : MediaQuery(data: media!, child: home),
  );
}
