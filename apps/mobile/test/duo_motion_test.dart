import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';

import 'package:cocenglish/core/design/cocenglish_brand.dart';
import 'package:cocenglish/core/design/duo_motion.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const fallbackKey = ValueKey('non-owl-fallback');
const humanSpec = DuoMotionSpec(
  asset: 'assets/motion/bea-smores.json',
  startFrame: 0,
  endFrame: 440,
  loop: true,
);

Widget harness({
  DuoMotionSpec? spec,
  bool enabled = true,
  bool reduced = false,
  AssetBundle? bundle,
}) => DefaultAssetBundle(
  bundle: bundle ?? rootBundle,
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(
        child: DuoMotion(
          pose: DuoPose.wave,
          width: 180,
          height: 140,
          spec: spec,
          enabled: enabled,
          fallback: const ColoredBox(key: fallbackKey, color: Colors.blue),
        ),
      ),
    ),
  ),
);

void main() {
  routineBrandTest();
  setUp(() => DuoMotion.debugSingleCycleLoops = false);
  tearDown(() => DuoMotion.debugSingleCycleLoops = true);

  testWidgets(
    'owl motion renders C at original bounds without loading owl assets',
    (tester) async {
      final bundle = RecordingBundle();
      await tester.pumpWidget(harness(bundle: bundle));
      await tester.pumpAndSettle();
      expect(find.byType(CocEnglishMascot), findsOneWidget);
      expect(
        tester.getSize(find.byType(CocEnglishMascot)),
        const Size(180, 140),
      );
      expect(bundle.requested.where((p) => p.contains('/duo-')), isEmpty);
      expect(find.byKey(fallbackKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disabled and reduced motion still use C rather than archived owl fallback',
    (tester) async {
      await tester.pumpWidget(harness(enabled: false));
      await tester.pumpAndSettle();
      expect(find.byType(CocEnglishMascot), findsOneWidget);
      expect(find.byKey(fallbackKey), findsNothing);
      await tester.pumpWidget(harness(reduced: true));
      await tester.pumpAndSettle();
      expect(find.byType(CocEnglishMascot), findsOneWidget);
      expect(find.byKey(fallbackKey), findsNothing);
    },
  );

  testWidgets('custom owl path animation is replaced too', (tester) async {
    await tester.pumpWidget(
      harness(
        spec: const DuoMotionSpec(
          asset: 'assets/motion/duo-path-jump.json',
          startFrame: 0,
          endFrame: 220,
          loop: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CocEnglishMascot), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'non-owl animation advances and retains reduced-motion fallback',
    (tester) async {
      await tester.pumpWidget(harness(spec: humanSpec));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final first = motionPainter(tester).frame;
      await tester.pump(const Duration(milliseconds: 300));
      expect(motionPainter(tester).frame, greaterThan(first));
      expect(find.byType(CocEnglishMascot), findsNothing);
      await tester.pumpWidget(harness(spec: humanSpec, reduced: true));
      expect(find.byKey(fallbackKey), findsOneWidget);
    },
  );

  testWidgets(
    'switching a running non-owl asset to owl stops animation and disposes safely',
    (tester) async {
      const transition = DuoMotionSpec(
        asset: 'assets/motion/test-human-transition.json',
        startFrame: 0,
        endFrame: 440,
        loop: true,
      );
      await tester.pumpWidget(
        harness(spec: transition, bundle: RecordingBundle()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(motionPainter(tester).frame, greaterThanOrEqualTo(0));
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(find.byType(CocEnglishMascot), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'static owl crop and dynamic widget art render C while a book stays artwork',
    (tester) async {
      Future<void> show(ArtRegion region) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: ReferenceArt(region, width: 72, height: 96)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(ReferenceArtRegions.questionDuo);
      expect(find.byType(CocEnglishMascot), findsOneWidget);
      expect(tester.getSize(find.byType(CocEnglishMascot)), const Size(72, 96));
      await show(
        const ArtRegion('widget-ready', Rect.fromLTWH(690, 487, 413, 241)),
      );
      expect(find.byType(CocEnglishMascot), findsOneWidget);
      await show(ReferenceArtRegions.book);
      await tester.runAsync(() => ReferenceArt.preloadFiles(['19']));
      await tester.pumpAndSettle();
      expect(find.byType(CocEnglishMascot), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ReferenceArt),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

// Capture the exact routine screen from the user's report and verify navigation.
void routineBrandTest() {
  testWidgets('routine screen displays C and Continue opens daily goal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    if (const bool.fromEnvironment('CAPTURE_COC_BRAND')) {
      await tester.runAsync(() async {
        final body = FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf'));
        final heading = FontLoader('Feather')
          ..addFont(rootBundle.load('assets/fonts/Feather.ttf'));
        await Future.wait([body.load(), heading.load()]);
      });
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MainApp(initial: OnboardingState(step: OnboardingStep.routine)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CocEnglishMascot), findsOneWidget);
    expect(find.text('CONTINUE').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_COC_BRAND')) {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '../../../outputs/CocEnglish_SEP490_Documents_20261029/10_Branding/onboarding-routine.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('What’s your daily learning goal?'), findsOneWidget);
  });
}

DuoMotionPainter motionPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<DuoMotionPainter>()
    .single;

class RecordingBundle extends CachingAssetBundle {
  final requested = <String>[];
  @override
  Future<ByteData> load(String key) {
    requested.add(key);
    if (key == 'assets/motion/test-human-transition.json') {
      return rootBundle.load(humanSpec.asset);
    }
    return rootBundle.load(key);
  }
}
