import 'package:cocenglish/features/ads/presentation/ad_screen.dart';
import 'package:cocenglish/features/hearts/application/hearts_controller.dart';
import 'package:cocenglish/features/hearts/presentation/heart_earned_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';
import '../../support/settle_images.dart';
import 'hearts_ads_test.dart' as support;

void main() {
  setUpAll(loadAppFonts);
  for (final lesson in [false, true]) {
    testWidgets('new ${lesson ? 'lesson offer' : 'need hearts'} sheet at 360', (
      tester,
    ) async {
      await support.pump(
        tester,
        support.launcher(lesson, () {}),
        reduced: true,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await settleImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/gap/${lesson ? 'lesson_offer' : 'need_hearts'}_360.png',
        ),
      );
    });
  }
  testWidgets('new earned heart at 360', (tester) async {
    final c = await support.pump(
      tester,
      const HeartEarnedScreen(),
      reduced: true,
    );
    c.read(heartsControllerProvider.notifier).earnFromAd('golden-fixture');
    await tester.pumpAndSettle();
    await settleImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/heart_earned_360.png'),
    );
  });
  testWidgets('new house ad final frame at 360', (tester) async {
    await support.pump(tester, const AdScreen(), reduced: true);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await settleImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/house_ad_360.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
