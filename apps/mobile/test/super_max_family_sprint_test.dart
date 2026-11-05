import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/presentation/max_screen.dart';
import 'package:cocenglish/features/progress/presentation/family_subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('max screen $width text$scale golden', (tester) async {
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
                  key: const ValueKey('max-master-screen'),
                  child: child!,
                ),
              ),
              home: const MaxScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const ValueKey('max-master-screen')),
          matchesGoldenFile(
            'goldens/ui_master/sprint_max_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
      });

      testWidgets('family screen $width text$scale golden', (tester) async {
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
                  key: const ValueKey('family-master-screen'),
                  child: child!,
                ),
              ),
              home: const FamilySubscriptionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const ValueKey('family-master-screen')),
          matchesGoldenFile(
            'goldens/ui_master/sprint_family_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
      });
    }
  }
}
