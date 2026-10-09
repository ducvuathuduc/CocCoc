import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  testWidgets('inspect original Duo vector timeline frames', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_MOTION')) return;
    const frames = {
      'wave': [600.0, 635.0, 680.0, 744.0],
      'idle': [0.0, 70.0, 220.0, 290.0],
      'pencil': [0.0, 25.0, 100.0, 190.0],
      'celebrate': [759.0, 850.0, 965.0, 1020.0],
      'reading': [0.0, 100.0, 200.0, 300.0],
      'bea-smores': [0.0, 110.0, 220.0, 330.0],
      'whistling': [0.0, 100.0, 200.0],
      'headphones': [0.0, 100.0, 200.0],
    };
    await tester.runAsync(() async {
      for (final entry in frames.entries) {
        final composition = await AssetLottie(
          'assets/motion/${entry.key == 'bea-smores' ? entry.key : 'duo-${entry.key}'}.json',
        ).load();
        for (final frame in entry.value) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final bounds = composition.bounds;
          canvas.drawColor(Colors.white, BlendMode.src);
          final drawable = LottieDrawable(composition);
          drawable.setProgress(
            (frame - composition.startFrame) / composition.durationFrames,
          );
          drawable.draw(
            canvas,
            Rect.fromLTWH(
              0,
              0,
              bounds.width.toDouble(),
              bounds.height.toDouble(),
            ),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(bounds.width, bounds.height);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final path = File(
            '../../docs/design/qa/motion/${entry.key}-${frame.toInt()}.png',
          );
          await path.parent.create(recursive: true);
          await path.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
      }
    });
  });
}
