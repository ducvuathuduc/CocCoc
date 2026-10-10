import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
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
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await ReferenceArt.preloadFiles(
        ['shop-02', 'shop-03', 'shop-04', 'shop-05']);
  });

  testWidgets('ShopScreen golden tests at 360 and 430', (t) async {
    for (final width in [360.0, 430.0]) {
      for (final textScale in [1.0, 2.0]) {
        t.view.physicalSize = Size(width, 1600);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);

        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: referenceTheme(),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const ValueKey('shop-screen'),
                child: const ShopScreen(),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();

        await expectLater(
          find.byKey(const ValueKey('shop-screen')),
          matchesGoldenFile(
              '../../goldens/ui_master/shop_${width.toInt()}_scale${textScale.toInt()}.png'),
        );
      }
    }
  });
}
