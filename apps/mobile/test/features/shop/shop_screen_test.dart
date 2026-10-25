import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/learning/presentation/learning_visuals.dart';
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
    await ReferenceArt.preloadFiles([
      'lesson-01',
      'shop-02',
      'shop-03',
      'shop-04',
      'shop-05',
    ]);
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
            overrides: [
              previewControllerProvider.overrideWith(_ShopPreview.new),
              previewWalletProvider.overrideWithValue(1035),
              // This reference depicts an existing Max subscriber.
              extendedControllerProvider.overrideWith(_MaxSubscriber.new),
            ],
            child: MaterialApp(
              theme: referenceTheme(),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 60),
                  textScaler: TextScaler.linear(textScale),
                ),
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
        expect(find.text('1035'), findsOneWidget);
        expect(find.text('x2'), findsOneWidget);
        expect(find.text('MAX'), findsOneWidget);
        final gem = find.byWidgetPredicate(
          (w) => w is ReferenceArt && w.region == LearningArt.gem,
        );
        expect(gem, findsWidgets);
        final gemPaint = find.descendant(
          of: gem.first,
          matching: find.byType(CustomPaint),
        );
        expect(t.widget<CustomPaint>(gemPaint).painter, isNotNull);
        expect(t.takeException(), isNull);

        await expectLater(
          find.byKey(const ValueKey('shop-screen')),
          matchesGoldenFile(
            '../../goldens/ui_master/shop_${width.toInt()}_scale${textScale.toInt()}.png',
          ),
        );
      }
    }
  });
}

class _ShopPreview extends PreviewController {
  @override
  PreviewState build() => const PreviewState(freezes: 2);
}

class _MaxSubscriber extends ExtendedController {
  @override
  ExtendedState build() => const ExtendedState(plan: 'max-individual');
}
