import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/api/client/idempotency.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/billing_models.dart';

abstract interface class BillingRepository {
  Future<BillingSnapshot> restore();
  Future<BillingSnapshot> purchase(
    BillingProduct product,
    DemoPaymentOutcome outcome,
  );
  Future<BillingSnapshot> checkPending();
  Future<BillingSnapshot> cancelRenewal();
}

class PaymentDeclined implements Exception {}

class BillingPreferencesStore implements SnapshotStore {
  BillingPreferencesStore(this.namespace);
  final String namespace;
  SharedPreferencesAsync? _storage;
  SharedPreferencesAsync get _preferences =>
      _storage ??= SharedPreferencesAsync();
  @override
  Future<String?> read(String key) =>
      _preferences.getString('billing.v1.$namespace.$key');
  @override
  Future<void> write(String key, String value) =>
      _preferences.setString('billing.v1.$namespace.$key', value);
}

/// Mock receipts are isolated from real entitlements and namespaced by account.
class LocalBillingRepository implements BillingRepository {
  LocalBillingRepository(this.store, {DateTime Function()? clock})
    : now = clock ?? DateTime.now;
  final SnapshotStore store;
  final DateTime Function() now;
  static const key = 'billing.simulation.v1';
  BillingReceipt? _active;

  Future<BillingReceipt?> _read() async {
    final raw = await store.read(key);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _active = json['active'] == null
        ? null
        : BillingReceipt.fromJson(
            Map<String, dynamic>.from(json['active'] as Map),
          );
    return BillingReceipt.fromJson(
      Map<String, dynamic>.from((json['receipt'] ?? json) as Map),
    );
  }

  BillingSnapshot _snapshot(BillingReceipt? receipt) {
    final entitlement = receipt?.state == 'PENDING' ? _active : receipt;
    BillingProduct? product;
    for (final p in BillingProduct.catalog) {
      if (p.id == entitlement?.productId) product = p;
    }
    return BillingSnapshot(
      selection: entitlement != null && entitlement.activeAt(now())
          ? product?.selection
          : null,
      receipt: receipt,
      activeUntil: entitlement?.expiresAt,
    );
  }

  Future<BillingSnapshot> _save(BillingReceipt receipt) async {
    if (receipt.state != 'PENDING') _active = receipt;
    await store.write(
      key,
      jsonEncode({'receipt': receipt.toJson(), 'active': _active?.toJson()}),
    );
    return _snapshot(receipt);
  }

  @override
  Future<BillingSnapshot> restore() async => _snapshot(await _read());
  @override
  Future<BillingSnapshot> purchase(
    BillingProduct product,
    DemoPaymentOutcome outcome,
  ) async {
    final previous = await _read();
    if (previous?.state == 'PENDING') {
      throw StateError('Check the pending purchase first.');
    }
    if (previous?.activeAt(now()) == true) _active = previous;
    if (outcome == DemoPaymentOutcome.declined) throw PaymentDeclined();
    return _save(
      BillingReceipt(
        id: UuidV4Generator().next(),
        productId: product.id,
        state: outcome == DemoPaymentOutcome.pending ? 'PENDING' : 'ACTIVE',
        expiresAt: outcome == DemoPaymentOutcome.pending
            ? null
            : now().toUtc().add(Duration(days: product.days)),
        autoRenew: outcome == DemoPaymentOutcome.success,
      ),
    );
  }

  @override
  Future<BillingSnapshot> checkPending() async {
    final receipt = await _read();
    if (receipt == null || receipt.state != 'PENDING') {
      return _snapshot(receipt);
    }
    final product = BillingProduct.catalog.firstWhere(
      (p) => p.id == receipt.productId,
    );
    return _save(
      BillingReceipt(
        id: receipt.id,
        productId: receipt.productId,
        state: 'ACTIVE',
        expiresAt: now().toUtc().add(Duration(days: product.days)),
        autoRenew: true,
      ),
    );
  }

  @override
  Future<BillingSnapshot> cancelRenewal() async {
    final receipt = await _read();
    if (receipt?.state == 'PENDING' && _active?.activeAt(now()) == true) {
      final old = _active!;
      _active = BillingReceipt(
        id: old.id,
        productId: old.productId,
        state: 'CANCELED',
        expiresAt: old.expiresAt,
        autoRenew: false,
      );
      return _save(receipt!);
    }
    if (receipt == null ||
        !receipt.activeAt(now()) ||
        receipt.state == 'CANCELED') {
      return _snapshot(receipt);
    }
    return _save(
      BillingReceipt(
        id: receipt.id,
        productId: receipt.productId,
        state: 'CANCELED',
        expiresAt: receipt.expiresAt,
        autoRenew: false,
      ),
    );
  }
}

/// API purchases remain SIMULATION; no store or payment credential is sent.
class ApiBillingRepository implements BillingRepository {
  ApiBillingRepository(this.api, this.store);
  final ApiEndpoints api;
  final SnapshotStore store;
  static const intentKey = 'billing.api.intent.v1';
  static const receiptKey = 'billing.api.receipt.v1';

  BillingSnapshot _snapshot(wire.Entitlement ent, [BillingReceipt? receipt]) {
    String? selection;
    final expires = DateTime.tryParse(ent.expiresAt ?? '');
    if (ent.unlimitedEnergy &&
        (expires == null || DateTime.now().isBefore(expires))) {
      selection = ent.plan == 'MAX' ? 'max-individual' : 'individual';
      for (final product in BillingProduct.catalog) {
        if (product.id == receipt?.productId &&
            receipt?.state != 'PENDING' &&
            product.isMax == (ent.plan == 'MAX')) {
          selection = product.selection;
        }
      }
    }
    return BillingSnapshot(
      selection: selection,
      receipt: receipt,
      activeUntil: DateTime.tryParse(ent.expiresAt ?? ''),
    );
  }

  BillingReceipt _receipt(wire.Purchase p) => BillingReceipt(
    id: p.purchaseId,
    productId: p.productId,
    state: p.state,
    expiresAt: DateTime.tryParse(p.entitlement.expiresAt ?? ''),
    autoRenew: p.entitlement.autoRenew,
  );
  Future<BillingSnapshot> _remember(wire.Purchase p) async {
    final receipt = _receipt(p);
    await store.write(receiptKey, jsonEncode(receipt.toJson()));
    await store.write(intentKey, '');
    return _snapshot(p.entitlement, receipt);
  }

  @override
  Future<BillingSnapshot> restore() async {
    final intent = await store.read(intentKey);
    if (intent != null && intent.isNotEmpty) {
      final data = jsonDecode(intent) as Map<String, dynamic>;
      final replay = await api.verifyPurchase(
        wire.PurchaseRequest.fromJson(data['body']),
        idempotencyKey: data['key'] as String,
      );
      return _remember(await api.getPurchase(replay.purchaseId));
    }
    final raw = await store.read(receiptKey);
    if (raw != null && raw.isNotEmpty) {
      final previous = BillingReceipt.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final purchase = await api.getPurchase(previous.id);
      return _remember(purchase);
    }
    return _snapshot(await api.getEntitlement());
  }

  @override
  Future<BillingSnapshot> purchase(
    BillingProduct product,
    DemoPaymentOutcome outcome,
  ) async {
    final unresolved = await store.read(intentKey);
    if (unresolved != null && unresolved.isNotEmpty) return restore();
    final existing = await store.read(receiptKey);
    if (existing != null &&
        existing.isNotEmpty &&
        BillingReceipt.fromJson(jsonDecode(existing) as Map<String, dynamic>)
                .state ==
            'PENDING') {
      return restore();
    }
    if (outcome == DemoPaymentOutcome.declined) throw PaymentDeclined();
    final body = wire.PurchaseRequest(
      productId: product.id,
      kind: 'SUBSCRIPTION',
      simulationOutcome: outcome == DemoPaymentOutcome.pending
          ? 'PENDING'
          : 'ACTIVE',
    );
    final key = api.client.ids.next();
    await store.write(
      intentKey,
      jsonEncode({'key': key, 'body': body.toJson()}),
    );
    return _remember(await api.verifyPurchase(body, idempotencyKey: key));
  }

  @override
  Future<BillingSnapshot> checkPending() => restore();
  @override
  Future<BillingSnapshot> cancelRenewal() async {
    final ent = await api.cancelSubscription(
      idempotencyKey: api.client.ids.next(),
    );
    final raw = await store.read(receiptKey);
    final old = raw == null || raw.isEmpty
        ? null
        : BillingReceipt.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final receipt = old == null
        ? null
        : BillingReceipt(
            id: old.id,
            productId: old.productId,
            state: ent.status,
            expiresAt: DateTime.tryParse(ent.expiresAt ?? ''),
            autoRenew: ent.autoRenew,
          );
    if (receipt != null) return _remember(await api.getPurchase(receipt.id));
    return _snapshot(ent);
  }
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  final user = ref.watch(authControllerProvider.select((s) => s.user));
  final config = ref.watch(appConfigProvider);
  final store = BillingPreferencesStore(
    '${config.isApi ? 'api' : 'demo'}.${user?.id ?? 'guest'}',
  );
  if (config.isApi) {
    return ApiBillingRepository(ref.watch(apiEndpointsProvider), store);
  }
  // Anonymous mock demonstrations share a clearly simulation-only namespace.
  return LocalBillingRepository(store);
});
