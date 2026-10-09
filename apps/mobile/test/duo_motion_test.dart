import 'dart:async';

import 'package:cocenglish/core/design/duo_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

const fallbackKey = ValueKey('duo-fallback');

Widget harness({
  DuoPose pose = DuoPose.wave,
  bool enabled = true,
  bool disableAnimations = false,
  DuoMotionSpec? spec,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Center(
      child: DuoMotion(
        pose: pose,
        width: 180,
        height: 180,
        enabled: enabled,
        spec: spec,
        fallback: const ColoredBox(key: fallbackKey, color: Colors.green),
      ),
    ),
  ),
);

void main() {
  testWidgets('all original motion assets parse into compositions', (
    tester,
  ) async {
    for (final path in {
      ...DuoPose.values.map((pose) => pose.spec.asset),
      'assets/motion/duo-path-jump.json',
      'assets/motion/duo-path-twirl.json',
      'assets/motion/bea-smores.json',
      'assets/motion/duo-whistling.json',
      'assets/motion/duo-headphones.json',
    }) {
      final composition = await AssetLottie(path)
          .load(context: tester.element(find.byType(View).first));
      expect(composition.bounds.width, greaterThan(0), reason: path);
      expect(composition.duration, greaterThan(Duration.zero), reason: path);
    }
  });

  testWidgets('original path jump advances and honors reduced motion', (
    tester,
  ) async {
    const spec = DuoMotionSpec(
      asset: 'assets/motion/duo-path-jump.json',
      startFrame: 0,
      endFrame: 220,
      loop: true,
    );
    await tester.pumpWidget(harness(spec: spec));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final first =
        (tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!
                as DuoMotionPainter)
            .frame;
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      (tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!
              as DuoMotionPainter)
          .frame,
      greaterThan(first),
    );
    await tester.pumpWidget(harness(spec: spec, disableAnimations: true));
    expect(find.byKey(fallbackKey), findsOneWidget);
  });

  testWidgets('playing advances the painted source frame', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final first =
        tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!
            as DuoMotionPainter;
    final firstFrame = first.frame;

    await tester.pump(const Duration(milliseconds: 500));
    final second =
        tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!
            as DuoMotionPainter;

    expect(second.frame, greaterThan(firstFrame));
    expect(second.progress, greaterThan(first.progress));
  });

  testWidgets('disabled and reduced motion render the static fallback', (
    tester,
  ) async {
    await tester.pumpWidget(harness(enabled: false));
    expect(find.byKey(fallbackKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DuoMotion),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );

    await tester.pumpWidget(harness(disableAnimations: true));
    expect(find.byKey(fallbackKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DuoMotion),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('removal disposes ticker without asynchronous state errors', (
    tester,
  ) async {
    await tester.pumpWidget(harness(pose: DuoPose.idle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'switching assets while disabled cannot install stale composition',
    (tester) async {
      final bundle = _DelayedAssetBundle();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: harness(
            pose: DuoPose.wave,
            spec: const DuoMotionSpec(
              asset: 'assets/motion/test-delayed-wave.json',
              startFrame: 600,
              endFrame: 755,
              loop: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: harness(pose: DuoPose.reading, enabled: false),
        ),
      );
      await bundle.completeWave();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byKey(fallbackKey), findsOneWidget);
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: harness(pose: DuoPose.reading),
        ),
      );
      await tester.pump();
      expect(_motionPainter(tester).composition.bounds.width, 1080);
    },
  );

  testWidgets('app lifecycle pauses and resumes looping motion', (
    tester,
  ) async {
    await tester.pumpWidget(harness(pose: DuoPose.idle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final beforePause = _motionPainter(tester).frame;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 300));
    final whilePaused = _motionPainter(tester).frame;
    expect(whilePaused, closeTo(beforePause, 0.001));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_motionPainter(tester).frame, greaterThan(whilePaused));
  });
}

DuoMotionPainter _motionPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(DuoMotion),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as DuoMotionPainter;

class _DelayedAssetBundle extends CachingAssetBundle {
  final _wave = Completer<ByteData>();
  final requested = <String>[];

  @override
  Future<ByteData> load(String key) {
    requested.add(key);
    if (key == 'assets/motion/test-delayed-wave.json') return _wave.future;
    return rootBundle.load(key);
  }

  Future<void> completeWave() async {
    _wave.complete(await rootBundle.load('assets/motion/duo-wave.json'));
  }
}
