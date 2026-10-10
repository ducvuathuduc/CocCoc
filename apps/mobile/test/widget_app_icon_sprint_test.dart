import 'package:cocenglish/features/progress/application/streak_controller.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/presentation/streak_widgets_screen.dart';
import 'package:cocenglish/features/progress/presentation/streak_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('streak widgets screen $width text$scale golden', (tester) async {
        tester.view.physicalSize = Size(width, width == 430 ? 932 : 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: referenceTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: RepaintBoundary(
                  key: const ValueKey('streak-widgets-master-screen'),
                  child: child!,
                ),
              ),
              home: const StreakWidgetsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const ValueKey('streak-widgets-master-screen')),
          matchesGoldenFile(
            'goldens/ui_master/sprint_streak_widgets_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
      });

      testWidgets('app icon sheet $width text$scale golden', (tester) async {
        tester.view.physicalSize = Size(width, width == 430 ? 932 : 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              streakFixtureProvider.overrideWithValue(
                StreakFixture(
                  days: 12,
                  month: DateTime(2026, 10),
                  practiced: {for (var d = 1; d <= 11; d++) d},
                ),
              ),
            ],
            child: MaterialApp(
              theme: referenceTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: RepaintBoundary(
                  key: const ValueKey('app-icon-master-screen'),
                  child: child!,
                ),
              ),
              home: const StreakScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Share streak'));
        await tester.pumpAndSettle();
        await tester.drag(find.text('Streak Society'), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CHANGE APP ICON').first);
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const ValueKey('app-icon-master-screen')),
          matchesGoldenFile(
            'goldens/ui_master/sprint_app_icon_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
      });
    }
  }
}
