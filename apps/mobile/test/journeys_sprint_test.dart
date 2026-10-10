import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/practice/presentation/journey_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final kind in ['story', 'radio', 'legendary', 'rapid']) {
        testWidgets('journey $kind $width text$scale golden', (tester) async {
          tester.view.physicalSize = Size(width, width == 430 ? 932 : 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: referenceTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(top: 59, bottom: 34),
                  ),
                  child: RepaintBoundary(
                    key: ValueKey('journey-$kind-master-screen'),
                    child: child!,
                  ),
                ),
                home: JourneyScreen(kind: kind, clockEnabled: false),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byKey(ValueKey('journey-$kind-master-screen')),
            matchesGoldenFile(
              'goldens/ui_master/sprint_journey_${kind}_${width.toInt()}_text${scale.toInt()}.png',
            ),
          );
        });
      }
    }
  }
}
