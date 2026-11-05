import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/promo/presentation/promo_code_screen.dart';
import 'package:cocenglish/features/shop/presentation/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MaxExtendedController extends ExtendedController {
  @override
  ExtendedState build() => const ExtendedState(plan: 'max-individual');
}

Future<({ProviderContainer container, GoRouter router})> _pumpShop(
  WidgetTester tester, {
  bool max = false,
  Size size = const Size(360, 717),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      previewWalletProvider.overrideWithValue(525),
      if (max)
        extendedControllerProvider.overrideWith(_MaxExtendedController.new),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/shop',
    routes: [
      GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
      GoRoute(
        path: PromoCodeScreen.route,
        builder: (_, _) => const PromoCodeScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: referenceTheme(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, router: router);
}

void main() {
  testWidgets('Free Shop excludes the Max subscriber banner', (tester) async {
    await _pumpShop(tester);
    expect(
      find.text('Thanks for being a\nDuolingo Max subscriber!'),
      findsNothing,
    );
    expect(find.text('My Items'), findsOneWidget);
  });

  testWidgets('Max Shop retains the subscriber banner', (tester) async {
    await _pumpShop(tester, max: true);
    expect(
      find.text('Thanks for being a\nDuolingo Max subscriber!'),
      findsOneWidget,
    );
  });

  testWidgets('Promo REDEEM opens and returns without changing the wallet', (
    tester,
  ) async {
    final result = await _pumpShop(
      tester,
      size: const Size(320, 568),
      textScale: 2,
    );
    final before = result.container.read(previewWalletProvider);
    final action = find.byKey(const ValueKey('shop-promo-redeem'));
    await tester.dragUntilVisible(
      find.text('Promo Code'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(find.text('Promo Code'), findsOneWidget);
    expect(find.text('Redeem a promo code'), findsOneWidget);
    expect(find.text('Enter a promo code to earn rewards'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReferenceArt &&
            widget.region.file == 'android-promo-shop' &&
            widget.region.source == const Rect.fromLTWH(34, 631, 78, 78),
      ),
      findsOneWidget,
    );
    await tester.dragUntilVisible(
      action,
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    final redeem = tester.widget<TextButton>(action);
    redeem.onPressed!();
    redeem.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(PromoCodeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopScreen), findsOneWidget);
    expect(result.container.read(previewWalletProvider), before);

    await tester.dragUntilVisible(
      action,
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(PromoCodeScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopScreen), findsOneWidget);
    expect(result.container.read(previewWalletProvider), before);
    expect(tester.takeException(), isNull);
  });
}
