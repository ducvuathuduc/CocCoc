import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/main.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/learning/application/unit_skip_controller.dart';
import 'package:cocenglish/features/learning/domain/unit_skip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('capture English catalog guidebook and unit check native states', (
    t,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE_COURSE_UI')) return;
    const ratio = 1180 / 390;
    t.view.physicalSize = const Size(1180, 2556);
    t.view.devicePixelRatio = ratio;
    t.view.padding = const FakeViewPadding(top: 59 * ratio, bottom: 34 * ratio);
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
        'section-list-source',
        'section-more-source',
        'section-detail-source',
        'section-cefr-source',
        'section-grammar-source',
        'guide-header-source',
        'guide-phrases-source',
        'guide-tips-source',
        'unit-skip-intro',
        'unit-skip-exercise',
        'unit-skip-warning',
        'unit-skip-failed',
        'unit-skip-result',
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
    final context = t.element(find.byType(Scaffold).first);
    final router = GoRouter.of(context);
    final c = ProviderScope.containerOf(context);
    Future<void> save(String name) async {
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await ReferenceArt.preloadFiles(
          t
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file)
              .toSet(),
        );
      });
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: name);
      for (final element in find.byType(ReferenceArt).evaluate()) {
        expect(
          find.descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(CustomPaint),
          ),
          findsWidgets,
          reason:
              '$name: illustration ${(element.widget as ReferenceArt).region.file} must be decoded before capture',
        );
      }
      await t.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final bitmap = await boundary.toImage(pixelRatio: ratio);
        final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../../docs/design/qa/course-finish/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        bitmap.dispose();
      });
    }

    await save('home-before');
    router.push('/sections');
    await t.pumpAndSettle();
    await save('sections-start');
    await t.drag(find.byType(ListView).last, const Offset(0, -9000));
    await save('sections-last');
    router.go('/home');
    await t.pumpAndSettle();
    router.push('/sections/1');
    await save('section-detail');
    final levels = find.text('All CEFR levels');
    await t.ensureVisible(levels);
    await t.pumpAndSettle();
    await t.tap(levels);
    await save('section-cefr');
    await t.tap(levels);
    await t.pumpAndSettle();
    final articles = find.text('Articles');
    await t.ensureVisible(articles);
    await t.pumpAndSettle();
    await t.tap(articles);
    await save('section-grammar');
    router.go('/home');
    await t.pumpAndSettle();
    router.push('/units/unit-4/guide');
    await save('guide-header');
    await t.drag(find.byType(CustomScrollView).last, const Offset(0, -380));
    await save('guide-phrases');
    await t.ensureVisible(find.text('TIP'));
    await save('guide-tip');
    router.go('/home');
    await t.pumpAndSettle();
    router.push('/units/unit-2/skip');
    await save('skip-intro');
    final p = unitSkipControllerProvider(2);
    final vm = c.read(p.notifier);
    vm.start();
    await save('skip-exercise');
    vm.toggleToken('like');
    vm.check();
    await save('skip-incorrect');
    vm.continueAfterFeedback();
    for (var i = 0; i < 3; i++) {
      vm.check();
      vm.continueAfterFeedback();
    }
    expect(c.read(p).stage, UnitSkipStage.lastHeartWarning);
    await save('skip-warning');
    vm.continueAfterWarning();
    vm.check();
    vm.continueAfterFeedback();
    await save('skip-failed');
    vm.restart();
    vm.start();
    while (c.read(p).stage != UnitSkipStage.passed) {
      for (final id in c.read(p).currentQuestion!.answerTokenIds) {
        vm.toggleToken(id);
      }
      vm.check();
      vm.continueAfterFeedback();
    }
    await save('skip-passed');
    await t.tap(find.text('CONTINUE'));
    await save('home-unit-two');
    router.push('/sections/2/check');
    await save('section-check-intro');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}
