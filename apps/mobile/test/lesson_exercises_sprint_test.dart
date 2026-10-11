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

Exercise _byKind(List<Exercise> list, ExerciseKind kind) =>
    list.firstWhere((e) => e.kind == kind);

Future<ProviderContainer> _pumpLesson(
  WidgetTester tester,
  List<Exercise> exercises, {
  bool reduceMotion = true,
  double width = 430,
  double height = 932,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      learningRepositoryProvider.overrideWithValue(
        MockLearningRepository(delay: Duration.zero, enforcesHearts: true),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(lessonControllerProvider.notifier)
      .start(exercises: exercises);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            padding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: RepaintBoundary(
            key: const ValueKey('lesson-sprint-screen'),
            child: child!,
          ),
        ),
        home: const LessonScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _golden(String name) => expectLater(
  find.byKey(const ValueKey('lesson-sprint-screen')),
  matchesGoldenFile('goldens/ui_master/sprint_lesson_${name}_430.png'),
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
      'lesson-07',
      'practice-01',
    ]);
  });

  final image = _byKind(mockEnglishExercises, ExerciseKind.imageChoice);
  final choice = _byKind(mockEnglishExercises, ExerciseKind.choice);
  final pairs = mockListeningPairsExercise;
  final blank = _byKind(mockEnglishExercises, ExerciseKind.fillBlank);
  final translate = _byKind(mockEnglishExercises, ExerciseKind.textTranslation);

  group('select image', () {
    testWidgets('ready', (tester) async {
      await _pumpLesson(tester, [image, choice]);
      expect(find.text('Select the correct image'), findsOneWidget);
      expect(find.text('CHECK'), findsOneWidget);
      await _golden('select_image_ready');
    });
    testWidgets('selected', (tester) async {
      await _pumpLesson(tester, [image, choice]);
      await tester.tap(find.text('the woman').last);
      await tester.pumpAndSettle();
      await _golden('select_image_selected');
    });
    testWidgets('correct feedback', (tester) async {
      await _pumpLesson(tester, [image, choice]);
      await tester.tap(find.text('the woman').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHECK'));
      await tester.pumpAndSettle();
      expect(find.text('Excellent!'), findsOneWidget);
      await _golden('select_image_correct');
    });
  });

  group('select translation', () {
    testWidgets('selected', (tester) async {
      await _pumpLesson(tester, [choice, image]);
      await tester.tap(find.text('boy'));
      await tester.pumpAndSettle();
      await _golden('translation_selected');
    });
    testWidgets('first mistake shows hearts sheet then incorrect', (
      tester,
    ) async {
      final c = await _pumpLesson(tester, [choice, image]);
      await tester.tap(find.text('boy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHECK'));
      await tester.pumpAndSettle();
      expect(find.text('KEEP GOING'), findsOneWidget);
      expect(c.read(lessonControllerProvider).hearts, 4);
      await _golden('hearts_warning');
      await tester.tap(find.text('KEEP GOING'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('woman'), findsWidgets);
      await _golden('translation_incorrect');
    });
  });

  group('match pairs', () {
    testWidgets('ready', (tester) async {
      await _pumpLesson(tester, [pairs, image]);
      expect(find.text('Tap the matching pairs'), findsOneWidget);
      await _golden('match_pairs');
    });
    testWidgets('matching all pairs enables check', (tester) async {
      final c = await _pumpLesson(tester, [pairs, image]);
      for (final entry in pairs.pairs.entries) {
        await tester.tap(find.byKey(ValueKey('pair-left-${entry.key}')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('pair-right-${entry.value}')));
        await tester.pumpAndSettle();
      }
      expect(
        c.read(lessonControllerProvider).matchedPairs.length,
        pairs.pairs.length,
      );
      expect(c.read(lessonControllerProvider).canCheck, isTrue);
    });
    testWidgets('wrong pair is not matched', (tester) async {
      final c = await _pumpLesson(tester, [pairs, image], reduceMotion: false);
      final keys = pairs.pairs.keys.toList();
      await tester.tap(find.byKey(ValueKey('pair-left-${keys[0]}')));
      await tester.pump();
      await tester.tap(
        find.byKey(ValueKey('pair-right-${pairs.pairs[keys[1]]}')),
      );
      await tester.pumpAndSettle();
      expect(c.read(lessonControllerProvider).matchedPairs, isEmpty);
    });
    testWidgets('can’t listen skips with yellow sheet', (tester) async {
      await _pumpLesson(tester, [pairs, image]);
      await tester.tap(find.text('CAN’T LISTEN NOW'));
      await tester.pumpAndSettle();
      expect(find.textContaining('skip listening'), findsOneWidget);
      await _golden('cant_listen');
      await tester.tap(find.text('CONTINUE').last);
      await tester.pumpAndSettle();
      expect(find.text('Select the correct image'), findsOneWidget);
    });
  });

  group('typed answers', () {
    testWidgets('fill blank', (tester) async {
      await _pumpLesson(tester, [blank, image]);
      expect(find.text('Complete the sentence'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'am');
      await tester.pumpAndSettle();
      await _golden('fill_blank');
    });
    testWidgets('type answer', (tester) async {
      await _pumpLesson(tester, [translate, image]);
      await tester.enterText(find.byType(TextField), 'The cat');
      await tester.pumpAndSettle();
      await _golden('type_answer');
    });
  });

  test('hearts are not enforced unless the repository opts in', () async {
    final container = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWithValue(
          MockLearningRepository(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    final vm = container.read(lessonControllerProvider.notifier);
    await vm.start(exercises: [choice, image]);
    vm.select('boy');
    await vm.check();
    final state = container.read(lessonControllerProvider);
    expect(state.hearts, 4);
    expect(state.showHeartsIntro, isFalse);
    expect(state.outOfHearts, isFalse);
  });

  group('sheets', () {
    testWidgets('quit lesson sheet', (tester) async {
      await _pumpLesson(tester, [image, choice]);
      await tester.tap(find.byTooltip('Exit lesson'));
      await tester.pumpAndSettle();
      expect(find.text('KEEP LEARNING'), findsOneWidget);
      await _golden('quit_sheet');
    });
    testWidgets('out of hearts', (tester) async {
      final wrong = List.generate(
        5,
        (i) => choice.copyWith(),
      ).map((e) => e).toList();
      final c = await _pumpLesson(tester, [...wrong, image]);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('boy'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CHECK'));
        await tester.pumpAndSettle();
        if (find.text('KEEP GOING').evaluate().isNotEmpty) {
          await tester.tap(find.text('KEEP GOING'));
          await tester.pumpAndSettle();
        }
        if (i < 4) {
          await tester.tap(find.text('GOT IT'));
          await tester.pumpAndSettle();
        }
      }
      expect(c.read(lessonControllerProvider).hearts, 0);
      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
      expect(find.text('You ran out of hearts!'), findsOneWidget);
      await _golden('out_of_hearts');
    });
  });

  group('motion', () {
    testWidgets('animations run and settle with motion on', (tester) async {
      await _pumpLesson(tester, [choice, image], reduceMotion: false);
      await tester.tap(find.text('boy'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHECK'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('KEEP GOING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('word tile flies into the answer line', (tester) async {
      final bank = _byKind(mockEnglishExercises, ExerciseKind.wordBank);
      final c = await _pumpLesson(tester, [bank, image], reduceMotion: false);
      await tester.tap(find.text('woman'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('answer-woman')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(c.read(lessonControllerProvider).tokenIds, ['woman']);
      expect(tester.takeException(), isNull);
    });
    testWidgets('match pair flash and fade settle', (tester) async {
      await _pumpLesson(tester, [pairs, image], reduceMotion: false);
      final first = pairs.pairs.entries.first;
      await tester.tap(find.byKey(ValueKey('pair-left-${first.key}')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(ValueKey('pair-right-${first.value}')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
