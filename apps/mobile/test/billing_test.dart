import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/features/billing/application/billing_controller.dart';
import 'package:cocenglish/features/billing/data/billing_repository.dart';
import 'package:cocenglish/features/billing/domain/billing_models.dart';
import 'package:cocenglish/features/billing/presentation/billing_checkout.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';

class SlowBilling implements BillingRepository {
  final purchaseResult = Completer<BillingSnapshot>();
  int purchases = 0;
  @override
  Future<BillingSnapshot> restore() async => const BillingSnapshot();
  @override
  Future<BillingSnapshot> purchase(
    BillingProduct product,
    DemoPaymentOutcome outcome,
  ) {
    purchases++;
    return purchaseResult.future;
  }

  @override
  Future<BillingSnapshot> cancelRenewal() async => const BillingSnapshot();
  @override
  Future<BillingSnapshot> checkPending() async => const BillingSnapshot();
}

void main() {
  final superPlan = BillingProduct.forSelection('monthly')!;
  test('pending upgrade preserves current paid plan after restart', () async {
    final store = MemorySnapshotStore();
    final repo = LocalBillingRepository(store);
    await repo.purchase(superPlan, DemoPaymentOutcome.success);
    final pending = await repo.purchase(
      BillingProduct.forSelection('max-family')!,
      DemoPaymentOutcome.pending,
    );
    expect(pending.selection, 'monthly');
    final restored = await LocalBillingRepository(store).restore();
    expect(restored.selection, 'monthly');
    expect(restored.receipt!.state, 'PENDING');
  });
  test(
    'mock purchase persists receipt and restores after repository recreation',
    () async {
      final store = MemorySnapshotStore();
      final now = DateTime.utc(2026, 10, 21);
      final repo = LocalBillingRepository(store, clock: () => now);
      final bought = await repo.purchase(superPlan, DemoPaymentOutcome.success);
      final restored = await LocalBillingRepository(
        store,
        clock: () => now,
      ).restore();
      expect(restored.selection, 'monthly');
      expect(restored.receipt!.id, bought.receipt!.id);
      expect(restored.receipt!.expiresAt, DateTime.utc(2026, 11, 20));
    },
  );
  test(
    'pending payment grants nothing until explicit simulated settlement once',
    () async {
      final repo = LocalBillingRepository(MemorySnapshotStore());
      final pending = await repo.purchase(
        superPlan,
        DemoPaymentOutcome.pending,
      );
      expect(pending.selection, isNull);
      expect(pending.receipt!.state, 'PENDING');
      final active = await repo.checkPending();
      final duplicate = await repo.checkPending();
      expect(active.selection, 'monthly');
      expect(active.receipt!.id, pending.receipt!.id);
      expect(duplicate.receipt!.expiresAt, active.receipt!.expiresAt);
    },
  );
  test('declined payment never replaces a valid receipt', () async {
    final repo = LocalBillingRepository(MemorySnapshotStore());
    final old = await repo.purchase(superPlan, DemoPaymentOutcome.success);
    await expectLater(
      repo.purchase(
        BillingProduct.forSelection('max-individual')!,
        DemoPaymentOutcome.declined,
      ),
      throwsA(isA<PaymentDeclined>()),
    );
    expect((await repo.restore()).receipt!.id, old.receipt!.id);
  });
  test('cancel renewal preserves paid expiry through restore and expires at boundary', () async {
    var now = DateTime.utc(2026, 10, 21);
    final store = MemorySnapshotStore();
    final repo = LocalBillingRepository(store, clock: () => now);
    final bought = await repo.purchase(superPlan, DemoPaymentOutcome.success);
    final canceled = await repo.cancelRenewal();
    expect(canceled.selection, 'monthly');
    expect(canceled.receipt!.autoRenew, false);
    expect(canceled.receipt!.expiresAt, bought.receipt!.expiresAt);
    now = bought.receipt!.expiresAt!.subtract(const Duration(milliseconds: 1));
    expect((await repo.restore()).selection, 'monthly');
    now = bought.receipt!.expiresAt!;
    expect((await repo.restore()).selection, isNull);
    expect(
      (await LocalBillingRepository(
        store,
        clock: () => now,
      ).restore()).selection,
      isNull,
    );
  });
  test(
    'controller blocks duplicate checkout and applies verified result',
    () async {
      final repo = SlowBilling();
      final c = ProviderContainer(
        overrides: [billingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      c.read(extendedControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final vm = c.read(billingControllerProvider.notifier);
      final first = vm.purchase(superPlan, DemoPaymentOutcome.success);
      expect(await vm.purchase(superPlan, DemoPaymentOutcome.success), false);
      expect(repo.purchases, 1);
      expect(c.read(extendedControllerProvider).unlimited, false);
      repo.purchaseResult.complete(
        BillingSnapshot(
          selection: 'monthly',
          receipt: BillingReceipt(
            id: 'order',
            productId: superPlan.id,
            state: 'ACTIVE',
            expiresAt: DateTime.now().add(const Duration(days: 30)),
            autoRenew: true,
          ),
        ),
      );
      expect(await first, true);
      expect(c.read(extendedControllerProvider).plan, 'monthly');
    },
  );
  test('repository/account change ignores late purchase result', () async {
    final old = SlowBilling();
    final c = ProviderContainer(
      overrides: [billingRepositoryProvider.overrideWithValue(old)],
    );
    addTearDown(c.dispose);
    c.read(billingControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final work = c
        .read(billingControllerProvider.notifier)
        .purchase(superPlan, DemoPaymentOutcome.success);
    c.updateOverrides([
      billingRepositoryProvider.overrideWithValue(
        LocalBillingRepository(MemorySnapshotStore()),
      ),
    ]);
    c.read(billingControllerProvider);
    await Future<void>.delayed(Duration.zero);
    old.purchaseResult.complete(const BillingSnapshot(selection: 'monthly'));
    expect(await work, false);
    expect(c.read(billingControllerProvider).snapshot.selection, isNull);
  });
  for (final outcome in DemoPaymentOutcome.values) {
    testWidgets(
      'checkout ${outcome.name} requires explicit confirmation at text scale two',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = LocalBillingRepository(MemorySnapshotStore());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [billingRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(body: BillingCheckout(product: superPlan)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect((await repo.restore()).receipt, isNull);
        final label = switch (outcome) {
          DemoPaymentOutcome.success => 'Successful payment',
          DemoPaymentOutcome.pending => 'Pending payment',
          DemoPaymentOutcome.declined => 'Declined payment',
        };
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
        await tester.ensureVisible(find.text('CONFIRM DEMO PAYMENT'));
        await tester.tap(find.text('CONFIRM DEMO PAYMENT'));
        await tester.pumpAndSettle();
        final result = await repo.restore();
        expect(
          result.selection,
          outcome == DemoPaymentOutcome.success ? 'monthly' : null,
        );
        expect(
          result.receipt?.state,
          outcome == DemoPaymentOutcome.success
              ? 'ACTIVE'
              : outcome == DemoPaymentOutcome.pending
              ? 'PENDING'
              : null,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
