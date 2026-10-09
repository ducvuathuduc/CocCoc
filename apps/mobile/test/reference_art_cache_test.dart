import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'original illustration survives cache eviction and releases after navigation',
    (tester) async {
      final cache = PaintingBinding.instance.imageCache;
      final previous = cache.maximumSizeBytes;
      cache
        ..clear()
        ..clearLiveImages();
      cache.maximumSizeBytes = 14000000;
      addTearDown(() {
        cache.maximumSizeBytes = previous;
        cache
          ..clear()
          ..clearLiveImages();
      });
      await tester.runAsync(() => ReferenceArt.preloadFiles(['lesson-03']));
      expect(
        cache.currentSize,
        greaterThan(0),
        reason: 'Decoded illustrations must use Flutter’s bounded image cache.',
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: const ReferenceArt(
                ArtRegion('lesson-03', Rect.fromLTWH(117, 887, 365, 427)),
                width: 122,
                height: 142,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<List<int>> pixels() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final result = bytes!.buffer.asUint8List().toList();
        image.dispose();
        return result;
      }

      final before = (await tester.runAsync(pixels))!;
      cache.clear();
      await tester.runAsync(
        () => ReferenceArt.preloadFiles([
          'lesson-07',
          'results-02',
          'results-03',
          'sections-01',
          'super-07',
          'radio-host',
        ]),
      );
      await tester.pump();
      final after = (await tester.runAsync(pixels))!;
      expect(
        after,
        before,
        reason:
            'Eviction must not dispose an image currently painted by a screen.',
      );
      expect(cache.currentSizeBytes, lessThanOrEqualTo(cache.maximumSizeBytes));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(cache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
