import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    '390x844 path and lesson intro goldens preserve native start route',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('path-master-screen'),
          child: MainApp(
            initial: OnboardingState(
              step: OnboardingStep.lessonEntry,
              language: 'English',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => ReferenceArt.preloadFiles(
          tester
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file)
              .toSet(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('path-master-screen')),
        matchesGoldenFile('goldens/ui_master/core_path.png'),
      );
      await tester.tap(find.byTooltip('Start lesson 1'));
      await tester.pumpAndSettle();
      expect(find.text('START +20 XP').hitTestable(), findsOneWidget);
      await expectLater(
        find.byKey(const ValueKey('path-master-screen')),
        matchesGoldenFile('goldens/ui_master/core_lesson_intro.png'),
      );
      await tester.tap(find.text('START +20 XP'));
      await tester.pumpAndSettle();
      expect(find.text('Select the correct image'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
