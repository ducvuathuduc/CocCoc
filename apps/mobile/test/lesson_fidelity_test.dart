import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/core/design/lesson_motion.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> openLesson(
  WidgetTester tester, {
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      learningRepositoryProvider.overrideWithValue(
        MockLearningRepository(delay: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(lessonControllerProvider.notifier)
      .start(exercises: mockEnglishExercises);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: const LessonScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('progress fills with ease out and keeps its shine inset', (
    tester,
  ) async {
    var value = .2;
    Widget harness({bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Center(
          child: SizedBox(
            width: 200,
            child: LessonProgressBar(
              value: value,
              color: Colors.green,
              shineColor: Colors.lightGreen,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    final fill = find.byKey(const ValueKey('lesson-progress-fill'));
    final shine = find.byKey(const ValueKey('lesson-progress-shine'));
    expect(tester.getSize(fill), const Size(40, 16));
    expect(
      tester.getTopLeft(shine) - tester.getTopLeft(fill),
      const Offset(8, 4),
    );
    expect(tester.getSize(shine), const Size(24, 4));
    value = .8;
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(fill).width, greaterThan(100));
    expect(tester.getSize(fill).width, lessThan(160));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getSize(fill).width, 160);
    value = 1.5;
    await tester.pumpWidget(harness(reduced: true));
    await tester.pump();
    expect(tester.getSize(fill).width, 200);
  });

  testWidgets('heart loss shakes once and reduced motion stays still', (
    tester,
  ) async {
    final container = await openLesson(tester);
    final vm = container.read(lessonControllerProvider.notifier);
    final heart = find.byKey(const ValueKey('lesson-heart-shake'));
    double displacement() =>
        tester.widget<Transform>(heart).transform.storage[12];
    vm.select('boy');
    await tester.runAsync(vm.check);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    expect(displacement(), isNot(closeTo(0, .01)));
    await tester.pump(const Duration(milliseconds: 225));
    expect(displacement(), 0);
    await tester.pump(const Duration(milliseconds: 75));
    expect(displacement(), 0);
    expect(
      tester.widget<LessonHeartCounter>(find.byType(LessonHeartCounter)).hearts,
      4,
    );
  });

  testWidgets(
    'reduced motion shows feedback immediately without heart displacement',
    (tester) async {
      final container = await openLesson(tester, reduced: true);
      final vm = container.read(lessonControllerProvider.notifier);
      final heart = find.byKey(const ValueKey('lesson-heart-shake'));
      vm.select('boy');
      await tester.runAsync(vm.check);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Transform>(heart).transform.storage[12], 0);
      expect(
        tester
            .widget<FractionalTranslation>(
              find.descendant(
                of: find.byType(LessonFeedbackEntrance),
                matching: find.byType(FractionalTranslation),
              ),
            )
            .translation,
        Offset.zero,
      );
      expect(find.text('GOT IT').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('backgrounding stops a heart shake without replay on resume', (
    tester,
  ) async {
    var hearts = 5;
    Widget harness() => MaterialApp(
      home: Center(
        child: LessonHeartCounter(
          hearts: hearts,
          child: const SizedBox(width: 50, height: 24),
        ),
      ),
    );
    await tester.pumpWidget(harness());
    final heart = find.byKey(const ValueKey('lesson-heart-shake'));
    double displacement() =>
        tester.widget<Transform>(heart).transform.storage[12];
    hearts = 4;
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 75));
    expect(displacement(), isNot(closeTo(0, .01)));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(displacement(), 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 75));
    expect(displacement(), 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('correct feedback is compact with one primary Continue action', (
    tester,
  ) async {
    final container = await openLesson(tester);
    final vm = container.read(lessonControllerProvider.notifier);
    vm.select('woman');
    await tester.runAsync(vm.check);
    await tester.pumpAndSettle();
    expect(find.text('EXPLAIN MY ANSWER'), findsNothing);
    expect(
      tester.getSize(find.byType(LessonFeedbackEntrance)).height,
      lessThan(160),
    );
  });
  testWidgets(
    'feedback overlays choices without resizing their illustration viewport',
    (tester) async {
      final container = await openLesson(tester);
      final choice = find.text('the woman').last;
      final before = tester.getRect(choice);
      final vm = container.read(lessonControllerProvider.notifier);
      vm.select('woman');
      await tester.runAsync(vm.check);
      await tester.pumpAndSettle();
      expect(tester.getRect(choice), before);
      expect(find.text('Excellent!'), findsOneWidget);
      expect(find.text('CONTINUE').hitTestable(), findsOneWidget);
      expect(container.read(lessonControllerProvider).attempted, 1);
    },
  );

  testWidgets('feedback slides upward for 250ms and announces its outcome', (
    tester,
  ) async {
    final container = await openLesson(tester);
    final vm = container.read(lessonControllerProvider.notifier);
    vm.select('woman');
    await tester.runAsync(vm.check);
    await tester.pump();
    final label = find.text('Excellent!');
    final entranceY = tester.getTopLeft(label).dy;
    await tester.pump(const Duration(milliseconds: 125));
    final midwayY = tester.getTopLeft(label).dy;
    await tester.pump(const Duration(milliseconds: 125));
    final settledY = tester.getTopLeft(label).dy;
    expect(entranceY, greaterThan(midwayY));
    expect(midwayY, greaterThan(settledY));
    final region = tester.widgetList<Semantics>(
      find.ancestor(of: label, matching: find.byType(Semantics)),
    );
    expect(
      region.any((widget) => widget.properties.liveRegion == true),
      isTrue,
    );
  });

  testWidgets(
    'one haptic per grade; rebuilds and duplicate checks do not replay it',
    (tester) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final container = await openLesson(tester);
      final vm = container.read(lessonControllerProvider.notifier);
      vm.select('boy');
      await tester.runAsync(vm.check);
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      await tester.runAsync(vm.check);
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1));
      await tester.runAsync(vm.next);
      await tester.pumpAndSettle();
      vm.select('woman');
      await tester.runAsync(vm.check);
      await tester.pumpAndSettle();
      expect(haptics, [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.lightImpact',
      ]);
    },
  );
}
