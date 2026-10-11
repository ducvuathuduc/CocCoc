import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/presentation/score_information_screen.dart';
import 'package:cocenglish/features/progress/presentation/energy_screen.dart';

void main() {
  testWidgets('ScoreInformationScreen matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: const Scaffold(
            body: RepaintBoundary(
              key: ValueKey('score-screen'),
              child: ScoreInformationScreen(),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('score-screen')),
      matchesGoldenFile('goldens/ui_master/sprint_score_screen_430.png'),
    );
  });

  testWidgets('EnergyScreen matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: const Scaffold(
            body: RepaintBoundary(
              key: ValueKey('energy-screen'),
              child: EnergyScreen(),
            ),
          ),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('energy-screen')),
      matchesGoldenFile('goldens/ui_master/sprint_energy_screen_430.png'),
    );
  });
}
