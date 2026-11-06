import 'dart:ui' as ui;

import 'package:cocenglish/features/account/presentation/avatar_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('avatar choices repaint and survive reduced motion', (
    tester,
  ) async {
    final key = GlobalKey();
    Widget harness(Map<String, double> values) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: AvatarMotion(
              values: values,
              width: 160,
              height: 160,
              animate: false,
            ),
          ),
        ),
      ),
    );
    Future<List<int>> pixels() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = bytes!.buffer.asUint8List().toList();
      image.dispose();
      return result;
    }

    await tester.pumpWidget(harness(const {'SkinTone': 1}));
    await tester.pumpAndSettle();
    final first = (await tester.runAsync(pixels))!;
    for (final values in [
      const {'SkinTone': 10.0},
      const {'SkinTone': 1.0, 'ClothingColor': 3.0},
      const {'SkinTone': 1.0, 'BackgroundColor': 5.0},
    ]) {
      await tester.pumpWidget(harness(values));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(pixels))!, isNot(equals(first)));
    }
    await tester.pumpWidget(harness(const {'SkinTone': 1}));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(pixels))!, first);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
