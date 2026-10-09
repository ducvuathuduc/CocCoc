import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/features/quests/presentation/quests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'QuestsScreen intro and main golden at width \$width textScale \$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const RepaintBoundary(
                  key: ValueKey('quests-screen'),
                  child: QuestsScreen(),
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
            find.byKey(const ValueKey('quests-screen')),
            matchesGoldenFile(
                '../../goldens/ui_master/quests_intro_w\${width.toInt()}_s\${scale.toInt()}.png'),
          );

          // Tap CONTINUE to dismiss the intro
          await tester.tap(find.text('CONTINUE'));
          await tester.pumpAndSettle();

          // Preload art for the main screen
          await tester.runAsync(
            () => ReferenceArt.preloadFiles(
              tester
                  .widgetList<ReferenceArt>(find.byType(ReferenceArt))
                  .map((art) => art.region.file)
                  .toSet(),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byKey(const ValueKey('quests-screen')),
            matchesGoldenFile(
                '../../goldens/ui_master/quests_main_w\${width.toInt()}_s\${scale.toInt()}.png'),
          );
        },
      );
    }
  }
}
