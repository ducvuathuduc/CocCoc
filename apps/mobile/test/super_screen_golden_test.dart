import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/presentation/super_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

/// Android Super comparison (Mobbin Super 01). Real fonts and a decoded
/// source gradient are required: without them the first golden of a run
/// rendered Ahem boxes on a flat fallback colour and later ones did not.
void main() {
  setUpAll(loadAppFonts);

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('super screen $width text$scale golden', (tester) async {
        tester.view.physicalSize = Size(width, width == 430 ? 932 : 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: referenceTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                  // Insets of the Mobbin Android capture (48 px status bar, 14 px
                  // gesture bar) so frames compare 1:1 at 360 px.
                  padding: const EdgeInsets.only(top: 48, bottom: 14),
                ),
                child: RepaintBoundary(
                  key: const ValueKey('super-master-screen'),
                  child: child!,
                ),
              ),
              home: const SuperScreen(),
            ),
          ),
        );
        final context = tester.element(find.byType(SuperScreen));
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/reference_art/android-super-gradient.png'),
            context,
          ),
        );
        await settleImages(tester);

        await expectLater(
          find.byKey(const ValueKey('super-master-screen')),
          matchesGoldenFile(
            'goldens/ui_master/sprint_super_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
      });
    }
  }
}
