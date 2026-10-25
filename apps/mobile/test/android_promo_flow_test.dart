import 'dart:async';

import 'package:cocenglish/features/promo/application/promo_controller.dart';
import 'package:cocenglish/features/promo/data/promo_repository.dart';
import 'package:cocenglish/features/promo/domain/promo.dart';
import 'package:cocenglish/features/promo/presentation/promo_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/gap/screen_pump.dart';
import 'support/app_fonts.dart';

class _PendingPromo extends MockPromoRepository {
  final response = Completer<PromoResult>();
  int calls = 0;
  @override
  Future<PromoResult> redeem(String code, String idempotencyKey) {
    calls++;
    return response.future;
  }
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Android source copy and Apply remain at the bottom', (t) async {
    await pumpScreen(t, PromoCodeScreen.route, const PromoCodeScreen());
    expect(find.text('Enter a promo code to earn rewards'), findsOneWidget);
    expect(find.text('Gift code'), findsOneWidget);
    expect(find.text('APPLY'), findsOneWidget);
    expect(
      t.getBottomLeft(find.byKey(const ValueKey('promo-redeem'))).dy,
      greaterThan(750),
    );
  });

  testWidgets(
    'processing is visible, disables editing and prevents double apply',
    (t) async {
      final repo = _PendingPromo();
      await pumpScreen(
        t,
        PromoCodeScreen.route,
        const PromoCodeScreen(),
        overrides: [promoRepositoryProvider.overrideWithValue(repo)],
      );
      await t.enterText(find.byType(TextField), 'DUOLINGO25');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('promo-redeem')));
      await t.pump();
      expect(find.bySemanticsLabel('Applying promo code'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await t.tap(find.byKey(const ValueKey('promo-redeem')));
      await t.pump();
      expect(repo.calls, 1);
      repo.response.complete(const PromoResult.failure(PromoFailure.notFound));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Applying promo code'), findsNothing);
      expect(find.byKey(const ValueKey('promo-error')), findsOneWidget);
    },
  );

  testWidgets(
    'leaving during redemption does not write to a disposed controller',
    (t) async {
      final repo = _PendingPromo();
      final container = await pumpScreen(
        t,
        PromoCodeScreen.route,
        const PromoCodeScreen(),
        overrides: [promoRepositoryProvider.overrideWithValue(repo)],
      );
      final pending = container
          .read(promoControllerProvider.notifier)
          .redeem('GEMS500');
      container.invalidate(promoControllerProvider);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      repo.response.complete(
        const PromoResult.success(
          PromoReward(promoId: 'late', type: PromoRewardType.gems, gems: 500),
        ),
      );
      expect(await pending, isFalse);
      expect(t.takeException(), isNull);
    },
  );
}
