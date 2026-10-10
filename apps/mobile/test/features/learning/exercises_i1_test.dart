import 'package:cocenglish/core/design/reference_widgets.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/lesson_motion.dart';
import 'package:cocenglish/features/learning/presentation/image_choice.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const pairs = Exercise(
  id: 'i1-pairs',
  kind: ExerciseKind.matchPairs,
  title: 'Tap the matching pairs',
  prompt: '',
  pairs: {'woman': 'người phụ nữ', 'man': 'người đàn ông'},
);

Future<ProviderContainer> openI1(
  WidgetTester tester,
  Exercise exercise, {
  bool reduced = false,
  double scale = 1,
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
      .start(exercises: [exercise]);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: const LessonScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

BoxDecoration tileDecoration(WidgetTester tester, String label) {
  final box = find
      .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
      .first;
  return tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
}

void main() {
  testWidgets('text match track and CHECK use the same own-screen palette', (
    tester,
  ) async {
    await openI1(tester, pairs);
    final check = tester.widget<ReferenceButton>(
      find.byKey(const Key('lesson_check_button')),
    );
    expect(check.onPressed, isNull);
    expect(check.palette.surface, const Color(0xFFFEFCFE));
    expect(check.palette.border, const Color(0xFFE7E5E7));
    expect(check.palette.disabled, const Color(0xFFB3B0B3));
    expect(
      tester
          .widget<LessonProgressBar>(find.byType(LessonProgressBar))
          .trackColor,
      const Color(0xFFE7E5E7),
    );
  });
  testWidgets('text pairs retain their own sampled surface and flash palette', (
    tester,
  ) async {
    final c = await openI1(tester, pairs);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFFFEFCFE),
    );
    expect(tileDecoration(tester, 'woman').color, const Color(0xFFFEFCFE));
    expect(
      (tileDecoration(tester, 'woman').border! as Border).top.color,
      const Color(0xFFE7E5E7),
    );
    final vm = c.read(lessonControllerProvider.notifier);
    vm.selectPairLeft('woman');
    vm.selectPairRight('người phụ nữ');
    await tester.pump();
    expect(tileDecoration(tester, 'woman').color, const Color(0xFFDBFFBB));
    expect(
      (tileDecoration(tester, 'woman').border! as Border).top.color,
      const Color(0xFFA9EE73),
    );
    expect(
      tester.widget<Text>(find.text('woman').last).style!.color,
      const Color(0xFF61A513),
    );
  });
  testWidgets('modern image prompt uses its sampled source ink', (
    tester,
  ) async {
    await openI1(tester, mockEnglishExercises.first);
    expect(
      tester
          .widget<Text>(find.text(mockEnglishExercises.first.title))
          .style!
          .color,
      const Color(0xFF4B4B4B),
    );
  });

  testWidgets('image grid preserves source card proportions and row spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: referenceTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ImageChoiceExercise(
              exercise: mockEnglishExercises.first,
              state: const LessonState(),
              availableHeight: 600,
              onSelect: (_) {},
              audio: const SizedBox(width: 42, height: 42),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byKey(const Key('image_choice_card_0')));
    final right = tester.getRect(find.byKey(const Key('image_choice_card_1')));
    final next = tester.getRect(find.byKey(const Key('image_choice_card_2')));
    // Original1179px ref: cards510px wide/664px tall; grid gutter64px.
    expect(first.height / first.width, closeTo(664 / 510, .01));
    expect(right.left - first.right, closeTo(64 / 3, .01));
    expect(next.top - first.bottom, closeTo(64 / 3, .01));
  });

  testWidgets('idle girl crop contains the complete measured hair extent', (
    tester,
  ) async {
    await openI1(tester, mockEnglishExercises.first);
    final card = find.byKey(const Key('image_choice_card_1'));
    final art = tester.widget<ReferenceArt>(
      find.descendant(of: card, matching: find.byType(ReferenceArt)),
    );
    // Bundled lesson03 non-white art spans x676..1079/y891..1298.
    expect(art.region.source.left, lessThanOrEqualTo(676));
    expect(art.region.source.top, lessThanOrEqualTo(891));
    expect(art.region.source.right, greaterThanOrEqualTo(1080));
    expect(art.region.source.bottom, greaterThanOrEqualTo(1299));
  });
  testWidgets(
    'I1 uses sampled outline and ink while other lessons retain their palette',
    (tester) async {
      final c = await openI1(tester, mockEnglishExercises.first);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFFFFFFFF),
      );
      c.read(lessonControllerProvider.notifier).select('woman');
      await tester.pumpAndSettle();
      final decoration = tileDecoration(tester, 'the woman');
      expect(decoration.color, const Color(0xFFDDF4FF));
      expect((decoration.border! as Border).top.color, const Color(0xFF84D7FF));
      expect(
        tester.widget<Text>(find.text('the woman').last).style!.color,
        const Color(0xFF1CB0F6),
      );
      await c
          .read(lessonControllerProvider.notifier)
          .start(
            exercises: [
              mockEnglishExercises.firstWhere(
                (e) => e.kind == ExerciseKind.wordBank,
              ),
            ],
          );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        isNull,
      );
      expect(
        tester
            .widget<ReferenceButton>(
              find.byKey(const Key('lesson_check_button')),
            )
            .palette
            .border,
        const Color(0xFFE7E5E7),
      );
    },
  );

  testWidgets(
    'right-first selection paints selected state and matches stable IDs',
    (tester) async {
      final c = await openI1(tester, pairs);
      await tester.tap(find.text('người phụ nữ'));
      await tester.pumpAndSettle();
      expect(
        tileDecoration(tester, 'người phụ nữ').color,
        const Color(0xFFDDF4FF),
      );
      await tester.tap(find.text('woman'));
      await tester.pumpAndSettle();
      expect(c.read(lessonControllerProvider).matchedPairs, {
        'woman': 'người phụ nữ',
      });
    },
  );

  testWidgets('mismatch flashes locally then returns idle after 300ms', (
    tester,
  ) async {
    final c = await openI1(tester, pairs);
    await tester.tap(find.text('woman'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('người đàn ông'));
    await tester.pump();
    expect(tileDecoration(tester, 'woman').color, const Color(0xFFFFDFE0));
    expect(c.read(lessonControllerProvider).stage, LessonStage.answering);
    expect(c.read(lessonControllerProvider).attempted, 0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(tileDecoration(tester, 'woman').color, const Color(0xFFFEFCFE));
    expect(c.read(lessonControllerProvider).matchedPairs, isEmpty);
  });

  testWidgets('matched pair flashes green then disables both tiles', (
    tester,
  ) async {
    final c = await openI1(tester, pairs);
    await tester.tap(find.text('woman'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('người phụ nữ'));
    await tester.pump();
    expect(tileDecoration(tester, 'woman').color, const Color(0xFFDBFFBB));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(tileDecoration(tester, 'woman').boxShadow, isNull);
    expect(tileDecoration(tester, 'woman').color, const Color(0xFFFEFCFE));
    final before = c.read(lessonControllerProvider);
    final vm = c.read(lessonControllerProvider.notifier);
    vm.selectPairLeft('woman');
    vm.selectPairRight('người phụ nữ');
    expect(identical(c.read(lessonControllerProvider), before), isTrue);
  });

  testWidgets(
    'image CHECK stays disabled until selection and exposes required key',
    (tester) async {
      final c = await openI1(tester, mockEnglishExercises.first);
      final check = find.byKey(const Key('lesson_check_button'));
      expect(check, findsOneWidget);
      expect(tester.widget<ReferenceButton>(check).onPressed, isNull);
      expect(c.read(lessonControllerProvider).canCheck, isFalse);
      final vm = c.read(lessonControllerProvider.notifier);
      vm.select('unknown');
      expect(c.read(lessonControllerProvider).canCheck, isFalse);
      await tester.tap(find.text('the woman').last);
      await tester.pumpAndSettle();
      expect(c.read(lessonControllerProvider).canCheck, isTrue);
      expect(tester.widget<ReferenceButton>(check).onPressed, isNotNull);
      expect(find.byKey(const Key('image_choice_card_3')), findsOneWidget);
    },
  );

  testWidgets('pair input locks during flash and stale completion is ignored', (
    tester,
  ) async {
    final c = await openI1(tester, pairs);
    final vm = c.read(lessonControllerProvider.notifier);
    vm.selectPairLeft('woman');
    vm.selectPairRight('người đàn ông');
    final revision = c.read(lessonControllerProvider).pairAttempt!.revision;
    final locked = c.read(lessonControllerProvider);
    vm.selectPairRight('người phụ nữ');
    expect(identical(c.read(lessonControllerProvider), locked), isTrue);
    vm.pause();
    expect(c.read(lessonControllerProvider).pairAttempt, isNull);
    vm.resume();
    vm.selectPairRight('người đàn ông');
    vm.selectPairLeft('woman');
    final current = c.read(lessonControllerProvider).pairAttempt!;
    vm.finishPairAttempt(revision);
    expect(c.read(lessonControllerProvider).pairAttempt, same(current));
    await vm.start(exercises: [pairs]);
    vm.finishPairAttempt(current.revision);
    expect(c.read(lessonControllerProvider).matchedPairs, isEmpty);
    expect(c.read(lessonControllerProvider).pairAttempt, isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause preserves selected and matched pairs without replay', (
    tester,
  ) async {
    final c = await openI1(tester, pairs);
    final vm = c.read(lessonControllerProvider.notifier);
    vm.selectPairRight('người phụ nữ');
    vm.pause();
    vm.resume();
    expect(c.read(lessonControllerProvider).selectedPairRight, 'người phụ nữ');
    vm.selectPairLeft('woman');
    await tester.pump();
    vm.pause();
    await tester.pump(const Duration(seconds: 1));
    vm.resume();
    await tester.pumpAndSettle();
    expect(c.read(lessonControllerProvider).matchedPairs, {
      'woman': 'người phụ nữ',
    });
    expect(c.read(lessonControllerProvider).pairAttempt, isNull);
    expect(tileDecoration(tester, 'woman').color, const Color(0xFFFEFCFE));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion resolves mismatch and match immediately', (
    tester,
  ) async {
    final c = await openI1(tester, pairs, reduced: true);
    final vm = c.read(lessonControllerProvider.notifier);
    vm.selectPairLeft('woman');
    vm.selectPairRight('người đàn ông');
    await tester.pump();
    await tester.pump();
    expect(c.read(lessonControllerProvider).pairAttempt, isNull);
    expect(tileDecoration(tester, 'woman').color, const Color(0xFFFEFCFE));
    vm.selectPairRight('người phụ nữ');
    vm.selectPairLeft('woman');
    await tester.pump();
    await tester.pump();
    expect(c.read(lessonControllerProvider).pairAttempt, isNull);
    expect(tileDecoration(tester, 'woman').boxShadow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('image metadata controls NEW WORD and feedback locks choice', (
    tester,
  ) async {
    final c = await openI1(
      tester,
      mockEnglishExercises.first.copyWith(isNewWord: false),
    );
    expect(find.text('NEW WORD'), findsNothing);
    final vm = c.read(lessonControllerProvider.notifier);
    vm.select('woman');
    await tester.runAsync(vm.check);
    await tester.pumpAndSettle();
    await tester.tap(find.text('the boy'));
    await tester.pumpAndSettle();
    expect(c.read(lessonControllerProvider).selectedId, 'woman');
    expect(c.read(lessonControllerProvider).stage, LessonStage.feedback);
    expect(tileDecoration(tester, 'the woman').color, const Color(0xFFD6FFB8));
  });

  testWidgets('image press cancellation preserves selection', (tester) async {
    final c = await openI1(tester, mockEnglishExercises.first);
    final tile = find.byKey(const Key('image_choice_card_0'));
    final press = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(const Duration(milliseconds: 100));
    await press.cancel();
    await tester.pumpAndSettle();
    expect(c.read(lessonControllerProvider).selectedId, isNull);
    expect(tileDecoration(tester, 'the boy').boxShadow, isNotNull);
  });

  for (final exercise in [pairs, mockEnglishExercises.first]) {
    testWidgets('${exercise.kind.name} text2 remains scrollable and labelled', (
      tester,
    ) async {
      await openI1(tester, exercise, reduced: true, scale: 2);
      final semantics = tester.ensureSemantics();
      try {
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -350),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
