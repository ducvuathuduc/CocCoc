import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:cocenglish/features/account/presentation/avatar_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

void main() {
  testWidgets(
    'failed avatar does not poison new consumers and in-flight disposal is safe',
    (t) async {
      const asset = 'assets/avatar/avatar_builder_25_sept2025.riv';
      final original = await t.runAsync(() => rootBundle.load(asset));
      var fail = true;
      t.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (_) async => fail ? null : original,
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        ),
      );
      Widget harness(bool second) => MaterialApp(
        home: Row(
          children: [
            const AvatarMotion(
              key: ValueKey('first'),
              values: {},
              width: 160,
              height: 120,
              animate: false,
            ),
            if (second)
              const AvatarMotion(
                key: ValueKey('second'),
                values: {'SkinTone': 5},
                width: 160,
                height: 120,
                animate: false,
              ),
          ],
        ),
      );
      Future<void> loaded() async {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await t.pump();
      }

      await t.pumpWidget(harness(false));
      await loaded();
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      fail = false;
      await t.pumpWidget(harness(true));
      await loaded();
      expect(
        find.byType(rive.RiveWidget),
        findsOneWidget,
        reason: 'New consumers must retry after an earlier failed file load',
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(harness(true));
      await t.pumpWidget(const SizedBox.shrink());
      await loaded();
      await t.pumpWidget(harness(true));
      await loaded();
      expect(find.byType(rive.RiveWidget), findsNWidgets(2));
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('avatar renders source states and pauses while backgrounded', (
    t,
  ) async {
    final key = GlobalKey();
    Widget harness(Map<String, double> values, {bool animate = true}) =>
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: AvatarMotion(
                values: values,
                width: 390,
                height: 296,
                animate: animate,
              ),
            ),
          ),
        );
    const values = {
      'SkinTone': 5.0,
      'Body': 1.0,
      'Expression': 17.0,
      'MainHair': 58.0,
      'MainHairColor': 5.0,
      'ClothingColor': 1.0,
      'BackgroundColor': 1.0,
      'EyeColor': 1.0,
      'Glasses': 0.0,
      'Wrinkles': 0.0,
      'Piercings': 0.0,
      'Nose Piercing': 0.0,
      'FacialHair': 0.0,
      'Headwear': 0.0,
    };
    await t.pumpWidget(harness(values));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(rive.RiveWidget), findsOneWidget);
    final controller = t
        .widget<rive.RiveWidget>(find.byType(rive.RiveWidget))
        .controller;
    expect(
      controller.active,
      !const bool.fromEnvironment('ENABLE_MASCOT_MOTION', defaultValue: true)
          ? false
          : true,
    );
    Future<List<int>> pixels() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final frame = await boundary.toImage();
      final data = await frame.toByteData();
      final result = data!.buffer.asUint8List().toList();
      frame.dispose();
      return result;
    }

    final before = await t.runAsync(pixels);
    if (const bool.fromEnvironment(
          'ENABLE_MASCOT_MOTION',
          defaultValue: true,
        ) ==
        false) {
      var whiteEyePixels = 0;
      for (var i = 0; i < before!.length; i += 4) {
        if (before[i] > 248 && before[i + 1] > 248 && before[i + 2] > 248) {
          whiteEyePixels++;
        }
      }
      expect(
        whiteEyePixels,
        greaterThan(100),
        reason: 'Reduced-motion avatar must keep its eyes visible',
      );
    }
    // ignore: avoid_print
    print(
      'Original avatar bounds: ${controller.artboard.width}x${controller.artboard.height}',
    );
    if (const bool.fromEnvironment('CAPTURE_AVATAR')) {
      await t.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final frame = await boundary.toImage(pixelRatio: 3);
        final data = (await frame.toByteData(format: ui.ImageByteFormat.png))!;
        await File('../../docs/design/qa/avatar-rig.png')
            .writeAsBytes(data.buffer.asUint8List());
        frame.dispose();
      });
    }
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(controller.active, isFalse);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pumpWidget(harness(values, animate: false));
    expect(controller.active, isFalse);
    // ignore: deprecated_member_use
    final staticAnimation = controller.stateMachine.number(
      'ENG_ONLY_Animation',
    );
    expect(
      staticAnimation!.value,
      0,
      reason: 'Changing animate keeps an original static pose',
    );
    staticAnimation.dispose();
    await t.pumpWidget(harness(values));
    expect(
      controller.active,
      const bool.fromEnvironment('ENABLE_MASCOT_MOTION', defaultValue: true),
    );
    await t.pumpWidget(harness({...values, 'SkinTone': 15.0}));
    await t.pump(const Duration(seconds: 1));
    final after = await t.runAsync(pixels);
    expect(
      after,
      isNot(equals(before)),
      reason: 'Changing skin renders different original pixels',
    );
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: AvatarMotion(values: values, width: 390, height: 296),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await t.pump();
    expect(
      t.widget<rive.RiveWidget>(find.byType(rive.RiveWidget)).controller.active,
      isFalse,
    );
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets('original avatar rig exposes selectable states and triggers', (
    t,
  ) async {
    final file = await t.runAsync(
      () => rive.File.asset(
        'assets/avatar/avatar_builder_25_sept2025.riv',
        riveFactory: rive.Factory.flutter,
      ),
    );
    expect(file, isNotNull);
    final controller = rive.RiveWidgetController(
      file!,
      artboardSelector: rive.ArtboardSelector.byName('MainAvatar'),
      stateMachineSelector: rive.StateMachineSelector.byName('SMAvatar'),
    );
    // This original export predates Rive data binding.
    // ignore: deprecated_member_use
    final inputs = controller.stateMachine.inputs;
    // ignore: avoid_print
    print(
      'Original avatar inputs: ${inputs.map((i) => '${i.name}:${i.runtimeType}').join(', ')}',
    );
    for (final name in [
      'SkinTone',
      'Body',
      'Expression',
      'MainHair',
      'MainHairColor',
      'Glasses',
      'ClothingColor',
      'BackgroundColor',
    ]) {
      // ignore: deprecated_member_use
      final input = controller.stateMachine.number(name);
      expect(input, isNotNull, reason: name);
      input!.dispose();
    }
    for (final input in inputs) {
      input.dispose();
    }
    controller.dispose();
    file.dispose();
  });
}
