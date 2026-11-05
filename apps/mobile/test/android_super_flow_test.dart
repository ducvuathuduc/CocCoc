import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/billing/application/billing_controller.dart';
import 'package:cocenglish/features/billing/domain/billing_models.dart';
import 'package:cocenglish/features/super_trial/presentation/android_super_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ActiveBilling extends BillingController {
  @override
  BillingState build() => BillingState(
    loaded: true,
    snapshot: BillingSnapshot(
      selection: 'individual',
      receipt: BillingReceipt(
        id: 'verified-demo',
        productId: 'super_annual',
        state: 'ACTIVE',
        expiresAt: DateTime(2099),
        autoRenew: false,
      ),
    ),
  );
}

class FreeBilling extends BillingController {
  @override
  BillingState build() => const BillingState(loaded: true);
}

void main() {
  testWidgets(
    'Android comparison, reminder, catalog plans and all plans at text2',
    (t) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        ProviderScope(
          overrides: [billingControllerProvider.overrideWith(FreeBilling.new)],
          child: MaterialApp(
            theme: referenceTheme(),
            builder: (_, child) => MediaQuery(
              data: const MediaQueryData(
                disableAnimations: true,
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: const AndroidSuperFlow(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('android-super-next')));
      await t.pumpAndSettle();
      expect(find.textContaining('2 days'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('android-super-next')));
      await t.pumpAndSettle();
      expect(find.text('Individual'), findsOneWidget);
      expect(find.textContaining('83.99'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('VIEW ALL PLANS'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('VIEW ALL PLANS'));
      await t.pumpAndSettle();
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('GO BACK'), findsOneWidget);
      await t.ensureVisible(find.text('GO BACK'));
      await t.tap(find.text('GO BACK'));
      await t.pumpAndSettle();
      expect(find.text('GO BACK'), findsNothing);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('success flow requires verified active access', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [billingControllerProvider.overrideWith(FreeBilling.new)],
        child: MaterialApp(home: const AndroidSuperWelcome()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Super is ready!'), findsNothing);
    expect(find.text('CHECK ACCESS'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'verified success advances through original Android welcome artwork',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            billingControllerProvider.overrideWith(ActiveBilling.new),
          ],
          child: MaterialApp(home: const AndroidSuperWelcome()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Super is ready!'), findsOneWidget);
      expect(find.textContaining('2099'), findsOneWidget);
      await t.tap(find.text('NEXT'));
      await t.pumpAndSettle();
      expect(find.text('Welcome to Super!'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
      expect(t.takeException(), isNull);
    },
  );
}
