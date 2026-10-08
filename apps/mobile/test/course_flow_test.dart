import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cocenglish/features/learning/application/course_navigation_controller.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/application/unit_skip_controller.dart';
import 'package:cocenglish/features/learning/domain/course_catalog.dart';
import 'package:cocenglish/features/learning/domain/unit_skip.dart';
import 'package:cocenglish/features/learning/presentation/unit_skip_screen.dart';
import 'package:cocenglish/features/learning/presentation/sections_screen.dart';
import 'package:cocenglish/features/learning/presentation/unit_guide_screen.dart';
import 'package:cocenglish/core/design/reference_theme.dart';

Future<GoRouter> openCourseApp(WidgetTester t) async {
  await t.pumpWidget(
    MainApp(
      initial: OnboardingState(
        step: OnboardingStep.lessonEntry,
        language: 'English',
      ),
    ),
  );
  await t.pumpAndSettle();
  return GoRouter.of(t.element(find.byType(Scaffold).first));
}

void main() {
  testWidgets('path jump node opens its matching unit check', (t) async {
    await openCourseApp(t);
    final jump = find.byTooltip('Jump to Unit 2');
    await t.scrollUntilVisible(
      jump,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(jump);
    await t.pumpAndSettle();
    expect(
      find.text('Pass this test to jump ahead to Unit 2!'),
      findsOneWidget,
    );
    await t.tap(find.text('NOT NOW'));
    await t.pumpAndSettle();
    expect(find.byType(UnitSkipScreen), findsNothing);
    await t.scrollUntilVisible(
      find.text('SECTION 1, UNIT 1'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('SECTION 1, UNIT 1'), findsOneWidget);
  });
  test('course targets reject malformed links and guides differ by unit', () {
    for (final id in ['unit-0', 'unit-9', 'unit-02', '2', 'unit-two']) {
      expect(guideTarget(id, null), isNull);
    }
    expect(guideTarget('unit-2', '99'), isNull);
    expect(guideTarget('unit-2', 'bad'), isNull);
    expect(guideTarget('unit-2', null), const CourseTarget(1, 2));
    expect(englishSections.map((s) => s.number), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(englishUnitGuides.map((g) => g.title).toSet().length, 8);
    expect(
      unitGuide(const CourseTarget(2, 1)).phrases.first.english,
      'My father is funny. He has a dog.',
    );
  });
  test(
    'navigation requires a completed acknowledged matching local check',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(courseNavigationProvider.notifier);
      final learning = c.read(learningStateProvider);
      expect(vm.select(const CourseTarget(2, 1)), isFalse);
      final p = unitSkipControllerProvider(2, section: 2, sectionCheck: true);
      final subscription = c.listen(p, (_, _) {});
      addTearDown(subscription.close);
      final check = c.read(p.notifier);
      expect(
        vm.acceptCompletedCheck(const CourseTarget(2, 1), c.read(p)),
        isFalse,
      );
      check.start();
      while (c.read(p).stage != UnitSkipStage.passed) {
        for (final id in c.read(p).currentQuestion!.answerTokenIds) {
          check.toggleToken(id);
        }
        check.check();
        check.continueAfterFeedback();
      }
      expect(
        vm.acceptCompletedCheck(const CourseTarget(2, 1), c.read(p)),
        isFalse,
      );
      check.acknowledgePass();
      expect(
        vm.acceptCompletedCheck(const CourseTarget(3, 1), c.read(p)),
        isFalse,
      );
      expect(
        vm.acceptCompletedCheck(const CourseTarget(2, 1), c.read(p)),
        isTrue,
      );
      expect(c.read(courseNavigationProvider).active, const CourseTarget(2, 1));
      expect(
        vm.acceptCompletedCheck(const CourseTarget(2, 1), c.read(p)),
        isFalse,
      );
      expect(
        vm.acceptCompletedCheck(const CourseTarget(2, 2), c.read(p)),
        isFalse,
      );
      expect(
        vm.acceptCompletedCheck(const CourseTarget(7, 2), c.read(p)),
        isFalse,
      );
      expect(c.read(learningStateProvider), same(learning));
      await vm.startLesson(0);
      final review = c.read(lessonControllerProvider);
      expect(review.guest, isTrue);
      expect(review.nodeId, 'section-2-unit-1-review-0');
      expect(
        review.current!.prompt,
        'Bố tôi rất vui tính. Ông ấy có một con chó.',
      );
      expect(c.read(learningStateProvider), same(learning));
      expect(
        () => c.read(courseNavigationProvider).unlocked.clear(),
        throwsUnsupportedError,
      );
    },
  );
  testWidgets(
    'English catalog exposes section eight and locked daily refresh',
    (t) async {
      final router = await openCourseApp(t);
      router.push('/sections');
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView).last, const Offset(0, -9000));
      await t.pumpAndSettle();
      expect(find.text('Section 8'), findsOneWidget);
      expect(find.text('Daily Refresh'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'guide route keeps its unit rather than showing unit one everywhere',
    (t) async {
      final router = await openCourseApp(t);
      router.push('/units/unit-2/guide');
      await t.pumpAndSettle();
      expect(find.text('SECTION 1, UNIT 2'), findsOneWidget);
      expect(find.text('Introduce yourself'), findsWidgets);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'section jump names its destination and cancel preserves progress',
    (t) async {
      final router = await openCourseApp(t);
      router.push('/sections');
      await t.pumpAndSettle();
      final button = find.byKey(const ValueKey('jump-section-2'));
      await t.ensureVisible(button);
      await t.pumpAndSettle();
      await t.tap(button);
      await t.pumpAndSettle();
      expect(
        find.text('Pass this test to jump ahead to Section 2!'),
        findsOneWidget,
      );
      final c = ProviderScope.containerOf(
        t.element(find.byType(UnitSkipScreen)),
      );
      final before = c.read(learningStateProvider);
      await t.tap(find.text('NOT NOW'));
      await t.pumpAndSettle();
      expect(find.byType(SectionsScreen), findsOneWidget);
      expect(find.byType(UnitSkipScreen), findsNothing);
      expect(c.read(courseNavigationProvider).active, const CourseTarget(1, 1));
      expect(c.read(learningStateProvider), same(before));
    },
  );

  testWidgets(
    'completed section check returns to its English path without rewards',
    (t) async {
      final router = await openCourseApp(t);
      router.push('/sections/2/check');
      await t.pumpAndSettle();
      final c = ProviderScope.containerOf(
        t.element(find.byType(UnitSkipScreen)),
      );
      final before = c.read(learningStateProvider);
      final p = unitSkipControllerProvider(2, section: 2, sectionCheck: true);
      final vm = c.read(p.notifier);
      vm.start();
      while (c.read(p).stage != UnitSkipStage.passed) {
        for (final id in c.read(p).currentQuestion!.answerTokenIds) {
          vm.toggleToken(id);
        }
        vm.check();
        vm.continueAfterFeedback();
      }
      await t.pumpAndSettle();
      await t.tap(find.text('CONTINUE'));
      await t.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.text('SECTION 2, UNIT 1'), findsOneWidget);
      expect(c.read(learningStateProvider), same(before));
    },
  );

  testWidgets('unit pass targets unit two and Back discards the next attempt', (
    t,
  ) async {
    final router = await openCourseApp(t);
    router.push('/units/unit-2/skip');
    await t.pumpAndSettle();
    final c = ProviderScope.containerOf(t.element(find.byType(UnitSkipScreen)));
    final p = unitSkipControllerProvider(2);
    final vm = c.read(p.notifier);
    final before = c.read(learningStateProvider);
    vm.start();
    while (c.read(p).stage != UnitSkipStage.passed) {
      for (final id in c.read(p).currentQuestion!.answerTokenIds) {
        vm.toggleToken(id);
      }
      vm.check();
      vm.continueAfterFeedback();
    }
    await t.pumpAndSettle();
    await t.tap(find.text('CONTINUE'));
    await t.pumpAndSettle();
    expect(find.text('SECTION 1, UNIT 2'), findsOneWidget);
    router.push('/units/unit-3/skip');
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(c.read(courseNavigationProvider).active, const CourseTarget(1, 2));
    expect(c.read(learningStateProvider), same(before));
  });

  testWidgets(
    'invalid course links show a safe return instead of clamping targets',
    (t) async {
      final router = await openCourseApp(t);
      for (final route in [
        '/sections/bad',
        '/sections/99',
        '/sections/1/check',
        '/units/unit-0/guide',
        '/units/unit-9/skip',
        '/units/unit-2/guide?section=99',
        '/units/unit-2/skip?section=8',
      ]) {
        router.push(route);
        await t.pumpAndSettle();
        expect(
          find.text('This lesson is unavailable.'),
          findsOneWidget,
          reason: route,
        );
        await t.tap(find.text('BACK TO LEARNING'));
        await t.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/home');
      }
    },
  );

  testWidgets('guide audio failure and translation retain the current unit', (
    t,
  ) async {
    final router = await openCourseApp(t);
    router.push('/units/unit-2/guide');
    await t.pumpAndSettle();
    final listen = find.byTooltip('Listen to My name is Linh.').first;
    await t.ensureVisible(listen);
    await t.pumpAndSettle();
    await t.tap(listen);
    await t.pumpAndSettle();
    expect(find.text('Audio unavailable'), findsOneWidget);
    await t.tap(find.text('GOT IT'));
    await t.pumpAndSettle();
    await t.tap(find.text('My name is Linh.').first);
    await t.pumpAndSettle();
    expect(find.text('Tên tôi là Linh.'), findsWidgets);
    await t.tap(find.text('GOT IT'));
    await t.pumpAndSettle();
    expect(find.byType(UnitGuideScreen), findsOneWidget);
    expect(find.text('Introduce yourself'), findsWidgets);
  });

  testWidgets('section CEFR and grammar expansion preserve English examples', (
    t,
  ) async {
    final router = await openCourseApp(t);
    router.push('/sections/1');
    await t.pumpAndSettle();
    final levels = find.text('All CEFR levels');
    await t.ensureVisible(levels);
    await t.pumpAndSettle();
    await t.tap(levels);
    await t.pumpAndSettle();
    expect(find.text('B2'), findsOneWidget);
    await t.tap(levels);
    await t.pumpAndSettle();
    final articles = find.text('Articles');
    await t.ensureVisible(articles);
    await t.pumpAndSettle();
    await t.tap(articles);
    await t.pumpAndSettle();
    expect(
      find.text(englishSections.first.grammar.first.explanation),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('course screens fit 320px text2 with reduced motion', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final screen in const [
      SectionsScreen(),
      SectionDetailScreen(section: 8),
      UnitGuideScreen(target: CourseTarget(1, 8)),
      CourseUnavailableScreen(),
    ]) {
      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: screen,
          ),
        ),
      );
      await t.pumpAndSettle();
      final scrolls = find.byType(Scrollable);
      if (scrolls.evaluate().isNotEmpty) {
        final scroll = scrolls.first;
        await t.drag(scroll, const Offset(0, -9000));
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull, reason: screen.runtimeType.toString());
    }
  });
}
