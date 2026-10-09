import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/streak_controller.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/presentation/streak_screen.dart';
import 'package:cocenglish/features/progress/presentation/family_subscription_screen.dart';
import 'package:cocenglish/features/progress/presentation/achievements_screen.dart';
import 'package:cocenglish/features/practice/application/clash_controller.dart';
import 'package:cocenglish/features/practice/presentation/clash_screen.dart';

void main() {
  testWidgets('capture native social source states', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    const ratio = 1180 / 390;
    tester.view.physicalSize = const Size(1180, 2556);
    tester.view.devicePixelRatio = ratio;
    tester.view.padding = const FakeViewPadding(
      top: 59 * ratio,
      bottom: 34 * ratio,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.runAsync(() async {
      await (FontLoader('DuolingoSans')
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    Future<void> save(String name, GlobalKey boundary) async {
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final img = await render.toImage(pixelRatio: ratio);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../../docs/design/qa/english-extended/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    for (final name in [
      'streak-personal',
      'streak-frozen',
      'streak-perfect',
      'streak-incoming',
      'streak-accepted',
      'streak-edit',
      'streak-invite',
      'streak-pending',
      'family-subscription',
      'family-reaction',
      'achievements',
      'achievement-perfect',
      'achievement-xp',
      'badges',
      'clash-intro',
      'clash-versus',
      'clash-rules',
      'clash-choice',
      'clash-correct',
      'clash-bank',
      'clash-time-up',
      'clash-waiting',
    ]) {
      final fixture = name == 'streak-frozen'
          ? StreakFixture(
              days: 5,
              month: DateTime(2025, 12),
              practiced: const {8, 9, 10, 11, 12},
              frozen: const {13},
              appearance: StreakAppearance.frozen,
            )
          : name == 'streak-perfect'
          ? StreakFixture(
              days: 847,
              month: DateTime(2025, 12),
              practiced: Set.of(List.generate(10, (i) => i + 1)),
              appearance: StreakAppearance.perfect,
            )
          : null;
      final c = ProviderContainer(
        overrides: [
          streakClockProvider.overrideWithValue(DateTime(2026, 10, 5)),
          streakFixtureProvider.overrideWithValue(fixture),
        ],
      );
      final streak = c.read(streakControllerProvider.notifier);
      if ([
        'streak-incoming',
        'streak-accepted',
        'streak-edit',
        'streak-pending',
      ].contains(name)) {
        streak.selectFriends(true);
      }
      if (name == 'streak-accepted' || name == 'streak-edit') {
        streak.accept('alex');
      }
      if (name == 'streak-edit') streak.toggleEdit();
      if (name == 'streak-invite' || name == 'streak-pending') {
        streak.decline('alex');
        if (name == 'streak-pending') streak.invite('alex');
      }
      if (name.startsWith('family')) {
        c.read(extendedControllerProvider.notifier)
          ..choosePlan('max-family')
          ..confirmPlan()
          ..invite('Alex Smith');
      }
      final clash = c.read(clashControllerProvider.notifier);
      if (name.startsWith('clash')) {
        final stage = switch (name) {
          'clash-intro' => 0,
          'clash-versus' => 1,
          'clash-rules' => 2,
          _ => 3,
        };
        for (var i = 0; i < stage; i++) {
          clash.advance();
        }
        if (name == 'clash-correct' ||
            name == 'clash-bank' ||
            name == 'clash-time-up' ||
            name == 'clash-waiting') {
          clash
            ..choose('sister')
            ..check();
        }
        if (name == 'clash-bank') {
          clash
            ..advance()
            ..choose('I')
            ..choose('am');
        }
        if (name == 'clash-time-up' || name == 'clash-waiting') clash.tick(60);
        if (name == 'clash-waiting') clash.advance();
      }
      final Widget screen = name.startsWith('clash')
          ? const ClashScreen(clockEnabled: false)
          : name.startsWith('family')
          ? const FamilySubscriptionScreen()
          : name == 'achievements'
          ? const AchievementsScreen()
          : name == 'achievement-perfect'
          ? const AchievementDetailScreen(achievementId: 'perfect-week')
          : name == 'achievement-xp'
          ? const AchievementDetailScreen(achievementId: 'xp-olympian')
          : name == 'badges'
          ? const MonthlyBadgesScreen()
          : name == 'streak-invite'
          ? const FriendStreakInviteScreen()
          : const StreakScreen();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: referenceTheme(),
              home: screen,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => ReferenceArt.preloadFiles(
          tester
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file),
        ),
      );
      await tester.pumpAndSettle();
      await save(name, boundary);
      if (name == 'family-reaction') {
        await tester.tap(find.text('NUDGE'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => ReferenceArt.preloadFiles(['family-nudge']),
        );
        await tester.pumpAndSettle();
        await save('family-reaction-sheet', boundary);
      }
      if (name == 'streak-perfect' ||
          name == 'streak-frozen' ||
          name == 'achievements' ||
          name == 'badges') {
        await tester.drag(find.byType(ListView).first, const Offset(0, -560));
        await tester.pumpAndSettle();
        await save('$name-scrolled', boundary);
      }
      if (name == 'streak-perfect') {
        await tester.drag(find.byType(ListView).first, const Offset(0, -420));
        await tester.pumpAndSettle();
        await save('$name-society', boundary);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      c.dispose();
    }
  });
}
