import 'package:cocenglish/core/design/duo_motion.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('original Duo timelines draw and advance on Android', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    for (final pose in [
      DuoPose.wave,
      DuoPose.idle,
      DuoPose.pencil,
      DuoPose.celebrate,
      DuoPose.reading,
    ]) {
      final viewport = switch (pose) {
        DuoPose.wave => const Rect.fromLTWH(269, 549, 363, 392),
        DuoPose.idle => const Rect.fromLTWH(75, -72, 454, 560),
        DuoPose.pencil => const Rect.fromLTWH(69, -25, 571, 545),
        DuoPose.celebrate => const Rect.fromLTWH(260, 542, 408, 415),
        _ => const Rect.fromLTWH(295, 288, 512, 711),
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: referenceTheme(),
          home: Scaffold(
            body: Center(
              child: DuoMotion(
                key: ValueKey(pose),
                enabled: true,
                pose: pose,
                width: 180,
                height: 220,
                viewport: viewport,
                fallback: const SizedBox(key: ValueKey('loading')),
              ),
            ),
          ),
        ),
      );
      for (
        var attempt = 0;
        attempt < 30 &&
            find.byKey(const ValueKey('loading')).evaluate().isNotEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final paints = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is DuoMotionPainter,
      );
      expect(paints, findsOneWidget);
      final before =
          (tester.widget<CustomPaint>(paints).painter! as DuoMotionPainter)
              .frame;
      await binding.takeScreenshot('android-motion-${pose.name}-a');
      await tester.pump(const Duration(milliseconds: 400));
      final after =
          (tester.widget<CustomPaint>(paints).painter! as DuoMotionPainter)
              .frame;
      expect(after, isNot(before));
      await binding.takeScreenshot('android-motion-${pose.name}-b');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
