import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/features/billing/data/billing_repository.dart';
import 'package:cocenglish/features/billing/domain/billing_models.dart';

import 'support/fake_api_transport.dart';

Map<String, Object?> entitlement({
  String plan = 'SUPER',
  String status = 'ACTIVE',
}) => {
  'plan': plan,
  'status': status,
  'source': 'PURCHASE',
  'expiresAt': '2026-12-21T00:00:00.000Z',
  'autoRenew': status == 'ACTIVE',
  'familyGroupId': null,
  'unlimitedEnergy': plan != 'FREE',
  'adFree': plan != 'FREE',
  'conversations': plan == 'MAX',
  'revision': 1,
  'asOf': isoNow,
};
Map<String, Object?> purchase({
  String state = 'ACTIVE',
  String product = 'super_monthly',
  String plan = 'SUPER',
}) => {
  'purchaseId': '11111111-1111-4111-8111-111111111111',
  'productId': product,
  'kind': 'SUBSCRIPTION',
  'platform': 'SIMULATION',
  'state': state,
  'verifiedAt': state == 'PENDING' ? null : isoNow,
  'gems': null,
  'entitlement': entitlement(plan: plan),
};

class FailingStore implements SnapshotStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('disk full');
}

void main() {
  final product = BillingProduct.forSelection('monthly')!;
  test(
    'API submits SIMULATION with bearer and caller idempotency key',
    () async {
      final transport = FakeApiTransport()
        ..json('POST /base/v1/billing/purchases', purchase());
      final repo = ApiBillingRepository(
        ApiEndpoints(fakeClient(transport)),
        MemorySnapshotStore(),
      );
      final result = await repo.purchase(product, DemoPaymentOutcome.success);
      final request = transport.requests.single;
      expect(request.headers['Authorization'], 'Bearer jwt-test');
      expect(request.headers['Idempotency-Key'], isNotEmpty);
      expect(bodyOf(request), {
        'productId': 'super_monthly',
        'kind': 'SUBSCRIPTION',
        'platform': 'SIMULATION',
        'simulationOutcome': 'ACTIVE',
      });
      expect(result.selection, 'monthly');
    },
  );
  test('lost response retains durable intent and retries same key after recreation', () async {
    final transport = FakeApiTransport()..offline = true;
    final store = MemorySnapshotStore();
    final api = ApiEndpoints(fakeClient(transport));
    final repo = ApiBillingRepository(api, store);
    await expectLater(
      repo.purchase(product, DemoPaymentOutcome.success),
      throwsA(isA<Exception>()),
    );
    final first = transport.requests.first;
    transport.offline = false;
    transport.json('POST /base/v1/billing/purchases', purchase());
    transport.json(
      'GET /base/v1/billing/purchases/11111111-1111-4111-8111-111111111111',
      purchase(),
    );
    final restored = await ApiBillingRepository(api, store).restore();
    expect(restored.selection, 'monthly');
    expect(
      transport.to('POST /base/v1/billing/purchases').last.body,
      first.body,
    );
    expect(
      transport
          .to('POST /base/v1/billing/purchases')
          .last
          .headers['Idempotency-Key'],
      first.headers['Idempotency-Key'],
    );
    expect(await store.read(ApiBillingRepository.intentKey), '');
  });
  test('intent storage failure prevents a purchase request', () async {
    final transport = FakeApiTransport();
    final repo = ApiBillingRepository(
      ApiEndpoints(fakeClient(transport)),
      FailingStore(),
    );
    await expectLater(
      repo.purchase(product, DemoPaymentOutcome.success),
      throwsStateError,
    );
    expect(transport.requests, isEmpty);
  });
  test(
    'restore checks owned receipt instead of creating a second purchase',
    () async {
      final transport = FakeApiTransport();
      final store = MemorySnapshotStore();
      transport.json('POST /base/v1/billing/purchases', purchase());
      final repo = ApiBillingRepository(
        ApiEndpoints(fakeClient(transport)),
        store,
      );
      await repo.purchase(product, DemoPaymentOutcome.success);
      transport.json(
        'GET /base/v1/billing/purchases/11111111-1111-4111-8111-111111111111',
        purchase(state: 'CANCELED'),
      );
      final result = await repo.restore();
      expect(result.receipt!.state, 'CANCELED');
      expect(transport.to('POST /base/v1/billing/purchases'), hasLength(1));
    },
  );
  test(
    'pending Max upgrade cannot grant Max while current entitlement is Super',
    () async {
      final transport = FakeApiTransport()
        ..json(
          'POST /base/v1/billing/purchases',
          purchase(state: 'PENDING', product: 'max_family'),
        );
      final repo = ApiBillingRepository(
        ApiEndpoints(fakeClient(transport)),
        MemorySnapshotStore(),
      );
      final result = await repo.purchase(
        BillingProduct.forSelection('max-family')!,
        DemoPaymentOutcome.pending,
      );
      expect(result.selection, 'individual');
      expect(result.receipt!.state, 'PENDING');
    },
  );
  test(
    'API cancel renewal uses server expiry and does not revoke paid access',
    () async {
      final transport = FakeApiTransport();
      final store = MemorySnapshotStore();
      transport.json('POST /base/v1/billing/purchases', purchase());
      final repo = ApiBillingRepository(
        ApiEndpoints(fakeClient(transport)),
        store,
      );
      await repo.purchase(product, DemoPaymentOutcome.success);
      transport.json(
        'POST /base/v1/billing/subscription/cancel',
        entitlement(status: 'CANCELED'),
      );
      transport.json(
        'GET /base/v1/billing/purchases/11111111-1111-4111-8111-111111111111',
        {
          ...purchase(state: 'CANCELED'),
          'entitlement': entitlement(status: 'CANCELED'),
        },
      );
      final result = await repo.cancelRenewal();
      expect(result.selection, 'monthly');
      expect(result.receipt!.autoRenew, false);
      expect(result.receipt!.expiresAt, DateTime.utc(2026, 12, 21));
    },
  );
}
