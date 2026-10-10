import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ShopScreen golden tests at 360 and 430', (t) async {
    for (final width in [360.0, 430.0]) {
      for (final textScale in [1.0, 2.0]) {
        t.view.physicalSize = Size(width, 1600);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.resetPhysicalSize);

        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1600),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: const ShopScreen(),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        
        await expectLater(
          find.byType(ShopScreen),
          matchesGoldenFile('../../goldens/ui_master/shop_${width.toInt()}_scale${textScale.toInt()}.png'),
        );
      }
    }
  });
}
