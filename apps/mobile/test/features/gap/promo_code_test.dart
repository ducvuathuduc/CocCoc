import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/promo/application/promo_controller.dart';
import 'package:cocenglish/features/promo/data/promo_repository.dart';
import 'package:cocenglish/features/promo/domain/promo.dart';
import 'package:cocenglish/features/promo/presentation/promo_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';
import 'screen_pump.dart';

Future<(ProviderContainer, MockPromoRepository)> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double scale = 1,
}) async {
  final repo = MockPromoRepository();
  final c = await pumpScreen(
    tester,
    PromoCodeScreen.route,
    const PromoCodeScreen(),
    overrides: [promoRepositoryProvider.overrideWithValue(repo)],
    size: size,
    scale: scale,
  );
  return (c, repo);
}

Future<void> _redeem(WidgetTester t, String code) async {
  await t.enterText(find.byKey(const ValueKey('promo-code-field')), code);
  await t.pump();
  await t.tap(find.byKey(const ValueKey('promo-redeem')));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);
  const content = PromoContent();

  test('normalizes to the contract shape', () {
    expect(normalizePromoCode('  gems500 '), 'GEMS500');
    expect(normalizePromoCode('abc'), isNull);
    expect(normalizePromoCode('A' * 33), isNull);
    expect(normalizePromoCode('GEMS 500'), isNull);
  });

  testWidgets('REDEEM is disabled until a code is typed', (t) async {
    final (_, repo) = await _pump(t);
    await t.tap(find.byKey(const ValueKey('promo-redeem')));
    await t.pumpAndSettle();
    expect(repo.redeemed, isEmpty);
    expect(find.text(content.title), findsOneWidget);
  });

  testWidgets('gem code credits the wallet once', (t) async {
    final (c, repo) = await _pump(t);
    final before = c.read(previewWalletProvider);
    await _redeem(t, 'gems500');
    expect(find.text(content.successTitle), findsOneWidget);
    expect(find.text('500${content.gemsSuffix}'), findsOneWidget);
    expect(c.read(previewWalletProvider), before + 500);
    expect(repo.redeemed, {'promo-gems-500'});
  });

  testWidgets('Super days and item rewards read from the repository', (
    t,
  ) async {
    await _pump(t);
    await _redeem(t, 'COCSUPER7');
    expect(find.text('You got 7 days of Super Duolingo.'), findsOneWidget);
  });

  testWidgets('unknown code shows NOT_FOUND copy, then clears on edit', (
    t,
  ) async {
    await _pump(t);
    await _redeem(t, 'NOPE-1234');
    expect(find.text(content.notFound), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('promo-code-field')), 'NOPE');
    await t.pump();
    expect(find.text(content.notFound), findsNothing);
  });

  testWidgets('short code fails format check without a request', (t) async {
    final (_, repo) = await _pump(t);
    await _redeem(t, 'AB');
    expect(find.text(content.invalidFormat), findsOneWidget);
    expect(repo.redeemed, isEmpty);
  });

  testWidgets('second redemption is PROMO_ALREADY_REDEEMED', (t) async {
    final repo = MockPromoRepository();
    await repo.redeem('FREEZE-2', 'first-key');
    await pumpScreen(
      t,
      PromoCodeScreen.route,
      const PromoCodeScreen(),
      overrides: [promoRepositoryProvider.overrideWithValue(repo)],
    );
    await _redeem(t, 'freeze-2');
    expect(find.text(content.alreadyRedeemed), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('no overflow at $size with 2x text', (t) async {
      await _pump(t, size: size, scale: 2);
      await _redeem(t, 'NOPE-1234');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('promo code entry golden', (t) async {
    await _pump(t);
    await _redeem(t, 'NOPE-1234');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/promo_code_error_360.png'),
    );
  });

  testWidgets('promo code success golden', (t) async {
    await _pump(t);
    await _redeem(t, 'GEMS500');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/promo_code_success_360.png'),
    );
  });
}
