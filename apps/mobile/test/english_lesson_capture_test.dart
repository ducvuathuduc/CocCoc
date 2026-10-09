import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/character_motion.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_results.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets('capture English lesson states and original Lily runtime', (
    t,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE_ENGLISH_LESSON')) return;
    const motion = bool.fromEnvironment('CAPTURE_ENGLISH_LILY_MOTION');
    const ratio = 1180 / 390;
    t.view.physicalSize = const Size(390 * ratio, 844 * ratio);
    t.view.devicePixelRatio = ratio;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.runAsync(() async {
      await (FontLoader('DuolingoSans')
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await ReferenceArt.preloadFiles(['lesson-lily-source', 'results-02']);
    });
    final boundaryKey = GlobalKey();
    final c = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWithValue(
          MockLearningRepository(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(c.dispose);
    final vm = c.read(lessonControllerProvider.notifier);
    final lily = mockEnglishExercises.firstWhere(
      (e) => e.kind == ExerciseKind.dialogueTurn,
    );
    final spoken = mockPracticeExercises.firstWhere(
      (e) => e.kind == ExerciseKind.speakRepeat,
    );
    final router = GoRouter(
      initialLocation: '/lesson',
      routes: [
        GoRoute(path: '/lesson', builder: (_, _) => const LessonScreen()),
        GoRoute(path: '/results/:id', builder: (_, _) => const LessonResults()),
      ],
    );
    addTearDown(router.dispose);
    Widget harness({bool reduced = false, double scale = 1}) =>
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            theme: referenceTheme(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduced,
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 59, bottom: 34),
              ),
              child: RepaintBoundary(key: boundaryKey, child: child!),
            ),
          ),
        );
    Future<void> render() async {
      if (motion) {
        await t.pump();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 350)),
        );
        await t.pump(const Duration(milliseconds: 400));
      } else {
        await t.pumpAndSettle();
      }
    }

    Future<Uint8List> save(String name) async {
      await render();
      if (c.read(lessonControllerProvider).stage == LessonStage.completed) {
        expect(find.byType(LessonResults), findsOneWidget, reason: name);
      }
      await t.runAsync(
        () => ReferenceArt.preloadFiles(
          t
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file)
              .toSet(),
        ),
      );
      await render();
      expect(t.takeException(), isNull, reason: name);
      for (final element in find.byType(ReferenceArt).evaluate()) {
        expect(
          find.descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(CustomPaint),
          ),
          findsWidgets,
          reason: '$name: source illustration must be decoded',
        );
      }
      return (await t.runAsync(() async {
        final frame =
            await (boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: ratio);
        final bytes = (await frame.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        final file = File(
          '../../docs/design/qa/english-lesson-${motion ? 'motion' : 'native'}/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        frame.dispose();
        return bytes;
      }))!;
    }

    Future<void> start(List<Exercise> exercises, {bool guest = false}) async {
      await vm.start(exercises: exercises, guest: guest);
      router.go('/lesson');
      await render();
    }

    await vm.start(exercises: [lily]);
    await t.pumpWidget(harness());
    await render();
    if (motion) {
      expect(find.byType(rive.RiveWidget), findsOneWidget);
      final rig = t.widget<rive.RiveWidget>(find.byType(rive.RiveWidget));
      expect(rig.controller.active, isTrue);
      debugPrint('Lily viewport: ${t.getRect(find.byType(CharacterMotion))}');
      final a = await save('lily-idle-a');
      await t.pump(const Duration(milliseconds: 900));
      final b = await save('lily-idle-b');
      expect(
        listEquals(a, b),
        isFalse,
        reason: 'Original Lily runtime must advance',
      );
      vm.substituteMedia();
      vm.updateText('Goodbye');
      await t.runAsync(vm.check);
      await save('lily-incorrect');
      expect(
        t.widget<CharacterMotion>(find.byType(CharacterMotion)).reaction,
        CharacterReaction.incorrect,
      );
      await start([lily]);
      vm.substituteMedia();
      vm.updateText(lily.correctText);
      await t.runAsync(vm.check);
      await save('lily-correct');
      expect(
        t.widget<CharacterMotion>(find.byType(CharacterMotion)).reaction,
        CharacterReaction.correct,
      );
      await t.pumpWidget(harness(reduced: true));
      await save('lily-reduced-motion');
      expect(find.byType(rive.RiveWidget), findsNothing);
    } else {
      await save('01-lily-ready');
      await t.tap(find.byTooltip('Listen to Lily'));
      await save('02-lily-audio-unavailable');
      await t.tap(find.text('GOT IT'));
      await render();
      await t.tap(find.text("CAN'T SPEAK NOW"));
      await render();
      await t.enterText(find.byType(TextField), 'Goodbye');
      await save('03-lily-text');
      await t.runAsync(vm.check);
      await save('04-lily-incorrect');
      await t.runAsync(vm.next);
      await render();
      await t.tap(find.text("CAN'T SPEAK NOW"));
      await render();
      await t.enterText(find.byType(TextField), lily.correctText);
      await t.runAsync(vm.check);
      await save('05-lily-correct-meaning');
      await t.runAsync(vm.next);
      await save('06-result-with-mistake');
      await start([spoken]);
      await save('07-speaking-ready');
      await t.tap(find.byTooltip('Speak the sentence'));
      await save('08-speaking-unavailable');
      await t.tap(find.text('GOT IT'));
      await render();
      await t.tap(find.text("CAN'T SPEAK NOW"));
      await save('09-speaking-text');
      await start(
        List.generate(
          6,
          (i) => Exercise(
            id: 'english-combo-$i',
            kind: ExerciseKind.textTranslation,
            title: 'Translate this sentence',
            prompt: 'Xin chào!',
            correctText: 'Hello',
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        vm.updateText('Hello');
        await t.runAsync(vm.check);
        await t.runAsync(vm.next);
      }
      await save('10-five-correct');
      vm.updateText('Hello');
      await t.runAsync(vm.check);
      await t.runAsync(vm.next);
      await save('11-flawless');
      await start([lily], guest: true);
      vm.updateText(lily.correctText);
      await t.runAsync(vm.check);
      await t.runAsync(vm.next);
      await save('12-practice-result');
      t.view.physicalSize = const Size(320 * ratio, 844 * ratio);
      await t.pumpWidget(harness(reduced: true, scale: 2));
      await save('13-result-320-text2');
      await start([lily]);
      vm.substituteMedia();
      vm.updateText('Goodbye');
      await t.runAsync(vm.check);
      await save('14-lily-320-text2');
      await start([spoken]);
      await save('15-speaking-320-text2');
    }
    await t.pumpWidget(const SizedBox());
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
