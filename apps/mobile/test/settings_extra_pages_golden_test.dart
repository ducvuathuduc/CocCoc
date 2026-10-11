import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await ReferenceArt.preloadFiles([
      'lesson-01',
      'shop-02',
      'shop-03',
      'shop-04',
      'shop-05',
    ]);
  });

  final pages = <String, Widget>{
    'schools': const SchoolsSettingsScreen(),
    'social': const SocialAccountsScreen(),
    'feedback': const FeedbackScreen(),
  };

  for (final entry in pages.entries) {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${entry.key} page ${width.toInt()} x$scale', (t) async {
          t.view.physicalSize = Size(width, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: referenceTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: const ValueKey('page'),
                  child: entry.value,
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await expectLater(
            find.byKey(const ValueKey('page')),
            matchesGoldenFile(
              'goldens/ui_master/settings_${entry.key}_${width.toInt()}_text${scale.toInt()}.png',
            ),
          );
        });
      }
    }
  }

  testWidgets('shop streak freeze maxed row 430', (t) async {
    t.view.physicalSize = const Size(430, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          previewControllerProvider.overrideWith(_TwoFreezes.new),
          previewWalletProvider.overrideWithValue(1035),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: referenceTheme(),
          home: const RepaintBoundary(
            key: ValueKey('page'),
            child: ShopScreen(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('1-day'), 300, scrollable: list);
    await t.drag(list, const Offset(0, -400));
    await settleImages(t);
    await t.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('page')),
      matchesGoldenFile('goldens/ui_master/shop_freeze_maxed_430.png'),
    );
  });
}

class _TwoFreezes extends PreviewController {
  @override
  PreviewState build() => const PreviewState(freezes: 2);
}
