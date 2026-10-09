import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await ReferenceArt.preloadFiles(['lesson-01', 'lesson-03']);
  });

  for (final state in ['ready', 'selected', 'correct', 'incorrect']) {
    testWidgets('390x844 lesson image $state golden', (tester) async {
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
      final vm = container.read(lessonControllerProvider.notifier);
      await vm.start(exercises: mockEnglishExercises);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                padding: const EdgeInsets.only(top: 59, bottom: 34),
              ),
              child: RepaintBoundary(
                key: const ValueKey('ui-master-screen'),
                child: child!,
              ),
            ),
            home: const LessonScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (state != 'ready') {
        vm.select(state == 'incorrect' ? 'boy' : 'woman');
        if (state != 'selected') await tester.runAsync(vm.check);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      for (final element in find.byType(ReferenceArt).evaluate()) {
        expect(
          find.descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(CustomPaint),
          ),
          findsWidgets,
          reason: 'Bundled illustrations must be decoded in the golden',
        );
      }
      await expectLater(
        find.byKey(const ValueKey('ui-master-screen')),
        matchesGoldenFile('goldens/ui_master/core_lesson_image_$state.png'),
      );
    });
  }

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final correct in [true, false]) {
        testWidgets(
          'feedback $correct at $width text $scale keeps next reachable',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
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
            final vm = container.read(lessonControllerProvider.notifier);
            await vm.start(exercises: mockEnglishExercises);
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: referenceTheme(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(scale),
                      padding: const EdgeInsets.only(top: 59, bottom: 34),
                    ),
                    child: RepaintBoundary(
                      key: const ValueKey('ui-master-responsive-screen'),
                      child: child!,
                    ),
                  ),
                  home: const LessonScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            vm.select(correct ? 'woman' : 'boy');
            await tester.runAsync(vm.check);
            await tester.pumpAndSettle();
            expect(
              find.text(correct ? 'CONTINUE' : 'GOT IT').hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byKey(const ValueKey('ui-master-responsive-screen')),
              matchesGoldenFile(
                'goldens/ui_master/core_feedback_${correct ? 'correct' : 'incorrect'}_${width.toInt()}_text${scale.toInt()}.png',
              ),
            );
          },
        );
      }
    }
  }
}
