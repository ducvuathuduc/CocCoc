import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const goldenPairs = Exercise(
  id: 'i1-golden-pairs',
  kind: ExerciseKind.matchPairs,
  title: 'Tap the matching pairs',
  prompt: '',
  pairs: {'woman': 'người phụ nữ', 'man': 'người đàn ông', 'bear': 'con gấu'},
);

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
    await ReferenceArt.preloadFiles([
      'lesson-01',
      'lesson-03',
      'lesson-05',
      'lesson-06',
    ]);
  });
  final cases = <({String kind, String state, Size size, double scale})>[
    for (final state in ['idle', 'selected', 'correct', 'incorrect'])
      (kind: 'image', state: state, size: const Size(390, 844), scale: 1),
    for (final state in ['idle', 'selected_right', 'matched', 'wrong'])
      (kind: 'match', state: state, size: const Size(390, 844), scale: 1),
    for (final size in [const Size(360, 800), const Size(430, 932)])
      for (final scale in [1.0, 2.0]) ...[
        (kind: 'image', state: 'selected', size: size, scale: scale),
        (kind: 'match', state: 'idle', size: size, scale: scale),
      ],
  ];
  for (final fixture in cases) {
    final suffix = fixture.size.width == 390
        ? ''
        : '_${fixture.size.width.toInt()}_text${fixture.scale.toInt()}';
    testWidgets('I1 ${fixture.kind} ${fixture.state}$suffix golden', (
      tester,
    ) async {
      tester.view.physicalSize = fixture.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ProviderContainer(
        overrides: [
          learningRepositoryProvider.overrideWithValue(
            MockLearningRepository(delay: Duration.zero),
          ),
        ],
      );
      addTearDown(c.dispose);
      final vm = c.read(lessonControllerProvider.notifier);
      await vm.start(
        exercises: [
          fixture.kind == 'image' ? mockEnglishExercises.first : goldenPairs,
        ],
      );
      final animated = fixture.state == 'matched' || fixture.state == 'wrong';
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: !animated,
                textScaler: TextScaler.linear(fixture.scale),
                padding: const EdgeInsets.only(top: 59, bottom: 34),
              ),
              child: RepaintBoundary(
                key: const ValueKey('i1-screen'),
                child: child!,
              ),
            ),
            home: const LessonScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (fixture.kind == 'image' && fixture.state != 'idle') {
        vm.select(fixture.state == 'incorrect' ? 'boy' : 'woman');
        if (fixture.state == 'correct' || fixture.state == 'incorrect') {
          await tester.runAsync(vm.check);
        }
        await tester.pumpAndSettle();
      } else if (fixture.state == 'selected_right') {
        vm.selectPairRight('người phụ nữ');
        await tester.pumpAndSettle();
      } else if (animated) {
        vm.selectPairLeft('woman');
        vm.selectPairRight(
          fixture.state == 'wrong' ? 'người đàn ông' : 'người phụ nữ',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('i1-screen')),
        matchesGoldenFile(
          'goldens/ui_master/ex_${fixture.kind}_${fixture.state}$suffix.png',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
