import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/main.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/onboarding/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_comparison.dart';

const capture = bool.fromEnvironment('CAPTURE_UI');
final fixtures = <OnboardingState?>[
  null,
  OnboardingState(),
  OnboardingState(step: OnboardingStep.greeting),
  OnboardingState(step: OnboardingStep.questions),
  OnboardingState(step: OnboardingStep.language),
  OnboardingState(step: OnboardingStep.language, language: 'French'),
  OnboardingState(step: OnboardingStep.building, language: 'French'),
  OnboardingState(
    step: OnboardingStep.knowledge,
    language: 'French',
    knowledge: 1,
  ),
  OnboardingState(step: OnboardingStep.reasons, language: 'French'),
  OnboardingState(
    step: OnboardingStep.reasons,
    language: 'French',
    reasonIds: {0, 2, 3},
  ),
  OnboardingState(step: OnboardingStep.routine),
  OnboardingState(step: OnboardingStep.goal, goal: 10),
  OnboardingState(step: OnboardingStep.promise),
  OnboardingState(step: OnboardingStep.reminder),
  OnboardingState(step: OnboardingStep.widget),
  OnboardingState(step: OnboardingStep.benefits),
  OnboardingState(step: OnboardingStep.plan),
  OnboardingState(step: OnboardingStep.plan, plan: 0),
  OnboardingState(
    step: OnboardingStep.startPoint,
    language: 'French',
    startPoint: 1,
  ),
  OnboardingState(step: OnboardingStep.levelConfirmation, knowledge: 1),
];

void main() {
  testWidgets(
    'all 20 reference states render with bundled fonts at original resolution',
    (tester) async {
      final comparison = UiComparison();
      tester.view.physicalSize = const Size(1180, 2556);
      tester.view.devicePixelRatio = 1180 / 390;
      tester.view.padding = const FakeViewPadding(
        top: 59 * 1180 / 390,
        bottom: 34 * 1180 / 390,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.runAsync(() async {
        final sans = FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf'));
        final feather = FontLoader('Feather')
          ..addFont(rootBundle.load('assets/fonts/Feather.ttf'));
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await Future.wait([
          sans.load(),
          feather.load(),
          icons.load(),
          ReferenceArt.preload(),
        ]);
      });
      for (var index = 0; index < fixtures.length; index++) {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: fixtures[index] == null
                ? MaterialApp(
                    theme: referenceTheme(),
                    home: const SplashScreen(),
                    debugShowCheckedModeBanner: false,
                  )
                : MainApp(key: ValueKey(index), initial: fixtures[index]),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
        if (fixtures[index] != null &&
            fixtures[index]!.step != OnboardingStep.welcome &&
            fixtures[index]!.step != OnboardingStep.building) {
          final step = fixtures[index]!.step;
          final label = step == OnboardingStep.goal
              ? 'I’M COMMITTED'
              : step == OnboardingStep.reminder
              ? 'REMIND ME TO PRACTICE'
              : step == OnboardingStep.widget
              ? 'ADD WIDGET'
              : 'CONTINUE';
          expect(
            find.text(label).hitTestable(),
            findsOneWidget,
            reason: 'Footer of ${index + 1}',
          );
        }
        expect(
          tester.takeException(),
          isNull,
          reason: 'Reference screen ${index + 1}',
        );
        if (capture) {
          await tester.runAsync(
            () => ReferenceArt.preloadFiles(
              tester
                  .widgetList<ReferenceArt>(find.byType(ReferenceArt))
                  .map((art) => art.region.file),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1180 / 390);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '../../docs/design/qa/onboarding/${(index + 1).toString().padLeft(2, '0')}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            await comparison.compare(index + 1, image);
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
      if (capture) await tester.runAsync(comparison.write);
    },
  );
}
