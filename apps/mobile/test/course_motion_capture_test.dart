import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/character_motion.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/unit_skip_controller.dart';
import 'package:cocenglish/features/learning/presentation/unit_skip_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets('native Lin advances and reacts in the real unit check', (
    t,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE_COURSE_MOTION')) return;
    const ratio = 1180 / 390;
    t.view.physicalSize = const Size(1180, 2556);
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
      await ReferenceArt.preloadFiles(['unit-skip-exercise']);
    });
    final key = GlobalKey();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Widget harness({bool reduced = false}) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: RepaintBoundary(
          key: key,
          child: UnitSkipScreen(unit: 2, onClose: () {}, onPassed: () {}),
        ),
      ),
    );
    await t.pumpWidget(harness());
    final vm = container.read(unitSkipControllerProvider(2).notifier);
    vm.start();
    Future<void> render() async {
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
    }

    Future<Uint8List> save(String name) async {
      return (await t.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final frame = await boundary.toImage(pixelRatio: ratio);
        final bytes = (await frame.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        final output = File(
          '../../docs/design/qa/course-finish-motion/$name.png',
        );
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes);
        frame.dispose();
        return bytes;
      }))!;
    }

    await render();
    expect(find.byType(rive.RiveWidget), findsOneWidget);
    final rig = t.widget<rive.RiveWidget>(find.byType(rive.RiveWidget));
    expect(rig.controller.active, isTrue);
    final first = await save('lin-idle-a');
    await t.pump(const Duration(milliseconds: 800));
    final second = await save('lin-idle-b');
    expect(listEquals(first, second), isFalse, reason: 'Live Lin must advance');
    vm.toggleToken(
      vm.question!.tokens
          .firstWhere(
            (token) => !vm.question!.answerTokenIds.contains(token.id),
          )
          .id,
    );
    vm.check();
    await render();
    expect(
      t.widget<CharacterMotion>(find.byType(CharacterMotion)).reaction,
      CharacterReaction.incorrect,
    );
    await save('lin-incorrect');
    vm.continueAfterFeedback();
    for (final id
        in container.read(unitSkipControllerProvider(2)).selectedTokenIds) {
      vm.toggleToken(id);
    }
    for (final id in vm.question!.answerTokenIds) {
      vm.toggleToken(id);
    }
    vm.check();
    await render();
    expect(
      t.widget<CharacterMotion>(find.byType(CharacterMotion)).reaction,
      CharacterReaction.correct,
    );
    await save('lin-correct');
    await t.pumpWidget(harness(reduced: true));
    await render();
    expect(find.byType(rive.RiveWidget), findsNothing);
    expect(find.byType(ReferenceArt), findsOneWidget);
    await save('lin-reduced-motion');
    await t.pumpWidget(const SizedBox());
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
