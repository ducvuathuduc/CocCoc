import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/xp_boost/presentation/xp_boost_activated_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';
import '../../support/settle_images.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets('new XP Boost activated screen at 360', (t) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 56, bottom: 34),
                disableAnimations: true,
              ),
              child: const XpBoostActivatedScreen(),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await settleImages(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/xp_boost_activated_360.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
  });
}
