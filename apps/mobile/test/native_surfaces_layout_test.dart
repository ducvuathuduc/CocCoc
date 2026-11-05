import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/promo/presentation/promo_code_screen.dart';
import 'package:cocenglish/features/super_trial/presentation/super_brand_screen.dart';
import 'package:cocenglish/features/super_trial/presentation/super_trial_screen.dart';
import 'package:cocenglish/features/results/presentation/score_unlock_screen.dart';
import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

Future<GlobalKey> _pump(
  WidgetTester t,
  Widget screen,
  Size size,
  double scale, {
  double keyboard = 0,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
  );
  addTearDown(router.dispose);
  final boundary = GlobalKey();
  await t.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: referenceTheme(),
        routerConfig: router,
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: true,
            padding: padding,
            viewPadding: padding,
          ),
          child: RepaintBoundary(key: boundary, child: child!),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await settleImages(t);
  return boundary;
}

// Opt-in visual receipt, separate from the existing regression baselines.
Future<void> _capture(WidgetTester t, GlobalKey key, String name) async {
  const output = String.fromEnvironment('NATIVE_SURFACES_CAPTURE_DIR');
  if (output.isEmpty) return;
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final pixels = await boundary.toImage();
    final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    pixels.dispose();
  });
}

void main() {
  setUpAll(loadAppFonts);
  for (final (size, scale) in [
    (const Size(360, 717), 1.0),
    (const Size(430, 932), 1.0),
    (const Size(320, 568), 2.0),
  ]) {
    final label = '${size.width.toInt()}-text$scale';
    testWidgets('Android offer remains operable at $label', (t) async {
      final key = await _pump(t, const SuperTrialScreen(), size, scale);
      expect(t.takeException(), isNull);
      expect(find.text('NO THANKS'), findsOneWidget);
      await _capture(t, key, 'android-super-$label');
    });
    testWidgets('Score unlock remains operable at $label', (t) async {
      final key = await _pump(
        t,
        ScoreUnlockScreen(score: 5, onContinue: () {}),
        size,
        scale,
      );
      expect(t.takeException(), isNull);
      await _capture(t, key, 'score-unlock-$label');
    });
    testWidgets('promo remains operable with large text at $label', (t) async {
      final key = await _pump(t, const PromoCodeScreen(), size, scale);
      expect(t.takeException(), isNull);
      final action = find.byKey(const ValueKey('promo-redeem'));
      expect(t.getBottomLeft(action).dy, lessThanOrEqualTo(size.height));
      await _capture(t, key, 'promo-$label');
    });
    testWidgets('Super brand CTA remains visible at $label', (t) async {
      final key = await _pump(t, const SuperBrandScreen(), size, scale);
      expect(t.takeException(), isNull);
      final action = find.byKey(const ValueKey('super-brand-continue'));
      expect(t.getBottomLeft(action).dy, lessThanOrEqualTo(size.height));
      expect(t.getTopLeft(action).dy, greaterThan(0));
      expect(find.bySemanticsLabel('Super Duolingo'), findsOneWidget);
      await _capture(t, key, 'super-brand-$label');
    });
  }
  testWidgets('Android Shop promo card stays reachable after scrolling', (
    t,
  ) async {
    final key = await _pump(t, const ShopScreen(), const Size(360, 717), 1);
    final action = find.byKey(const ValueKey('shop-promo-redeem'));
    await t.dragUntilVisible(
      find.text('Promo Code'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await t.ensureVisible(action);
    await t.pumpAndSettle();
    await settleImages(t);
    expect(find.text('Redeem a promo code'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _capture(t, key, 'android-shop-promo-360');
  });
  testWidgets('Score controls clear Android status and navigation bars', (
    t,
  ) async {
    var continued = false;
    final key = await _pump(
      t,
      ScoreUnlockScreen(score: 5, onContinue: () => continued = true),
      const Size(360, 765),
      1,
      padding: const EdgeInsets.symmetric(vertical: 24),
    );
    final action = find.text('CONTINUE');
    expect(t.getTopLeft(action).dy, greaterThanOrEqualTo(24));
    expect(t.getBottomRight(action).dy, lessThanOrEqualTo(741));
    await _capture(t, key, 'score-unlock-android-safe-area');
    await t.tap(action);
    expect(continued, isTrue);
    expect(t.takeException(), isNull);
  });
  testWidgets('promo Apply stays above the keyboard at 2x text', (t) async {
    const size = Size(320, 568);
    final key = await _pump(t, const PromoCodeScreen(), size, 2, keyboard: 280);
    await t.enterText(find.byType(TextField), 'GEMS500');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
      t.getBottomLeft(find.byKey(const ValueKey('promo-redeem'))).dy,
      lessThanOrEqualTo(size.height - 280),
    );
    await _capture(t, key, 'promo-320-text2-keyboard');
  });
}
