import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/practice/application/clash_controller.dart';
import 'package:cocenglish/features/practice/presentation/clash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets(
    'actual Clash Rive actors render and character transition disposes safely',
    (tester) async {
      if (!const bool.fromEnvironment('CAPTURE_CLASH_RIVE')) return;
      const ratio = 1180 / 390;
      tester.view.physicalSize = const Size(1180, 2556);
      tester.view.devicePixelRatio = ratio;
      tester.view.padding = const FakeViewPadding(
        top: 59 * ratio,
        bottom: 34 * ratio,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.runAsync(() async {
        await rive.RiveNative.init();
        await (FontLoader('DuolingoSans')
              ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
              ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await ReferenceArt.preloadFiles([
          'clash-intro',
          'clash-coach',
          'clash-zari',
          'clash-oscar',
          'clash-finish',
        ]);
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(clashControllerProvider.notifier);
      vm
        ..advance()
        ..advance();
      final key = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: referenceTheme(),
              home: const ClashScreen(clockEnabled: false),
            ),
          ),
        ),
      );
      Future<void> frame(String name) async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(rive.RiveWidget), findsOneWidget, reason: name);
        expect(tester.takeException(), isNull, reason: name);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await boundary.toImage(pixelRatio: ratio);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          await File('../../docs/design/qa/english-extended/$name.png')
              .writeAsBytes(png!.buffer.asUint8List());
          img.dispose();
        });
      }

      await frame('clash-rive-eddy');
      vm.advance();
      await frame('clash-rive-zari');
      vm
        ..choose('sister')
        ..check();
      await frame('clash-rive-correct');
      vm.advance();
      await frame('clash-rive-oscar');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
