import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/main.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/league_result_controller.dart';
import 'package:cocenglish/features/progress/application/streak_widgets_controller.dart';
import 'package:cocenglish/features/progress/domain/streak_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'capture native league history, seven review pages, and widget moods',
    (t) async {
      if (!const bool.fromEnvironment('CAPTURE_SESSION_UI')) return;
      const ratio = 1180 / 390;
      t.view.physicalSize = const Size(1180, 2556);
      t.view.devicePixelRatio = ratio;
      t.view.padding = const FakeViewPadding(
        top: 59 * ratio,
        bottom: 34 * ratio,
      );
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPadding);
      await t.runAsync(() async {
        await (FontLoader('DuolingoSans')
              ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
              ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await ReferenceArt.preloadFiles([
          'league-result-source',
          'league-promotion-source',
          'league-reward-source',
          'year-review-intro',
          'year-review-lessons',
          'year-review-xp',
          'year-review-league',
          'year-review-gate',
          'year-review-student',
          'year-review-summary',
          ...streakWidgetStyles.map((s) => s.asset),
        ]);
      });
      final boundaryKey = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MainApp(
            initial: OnboardingState(
              step: OnboardingStep.lessonEntry,
              language: 'English',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final context = t.element(find.byTooltip('Practice'));
      final router = GoRouter.of(context);
      final container = ProviderScope.containerOf(context);
      Future<void> save(String name) async {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await t.pump();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final bitmap = await boundary.toImage(pixelRatio: ratio);
          final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          final file = File('../../docs/design/qa/session-finish/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          bitmap.dispose();
        });
      }

      router.push('/league/results');
      await t.pumpAndSettle();
      for (final stage in ['result', 'promotion', 'reward']) {
        expect(
          container.read(leagueResultControllerProvider).stage.name,
          stage,
        );
        await save('league-$stage');
        await t.tap(find.text('CONTINUE').hitTestable());
        await t.pumpAndSettle();
      }
      router.push('/year-review');
      await t.pumpAndSettle();
      for (var index = 0; index < 7; index++) {
        await save('year-$index');
        if (index < 6) {
          final action = find.bySemanticsLabel(index == 0 ? 'START' : 'NEXT');
          await t.ensureVisible(action);
          await t.pumpAndSettle();
          await t.tap(action.hitTestable());
          await t.pumpAndSettle();
        }
      }
      await t.tap(find.byTooltip('Close Year in Review'));
      await t.pumpAndSettle();
      router.push('/streak/widgets');
      await t.pumpAndSettle();
      for (final mood in StreakWidgetMood.values) {
        container.read(streakWidgetsProvider.notifier).select(mood);
        await t.pumpAndSettle();
        await save('widget-${mood.name}');
      }
    },
  );
}
