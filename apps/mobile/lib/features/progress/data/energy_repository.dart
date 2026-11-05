import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/idempotency.dart';
import '../domain/energy_offer.dart';

abstract class EnergyRepository {
  List<EnergyOffer> get offers;
  int get capacity;
  String get fullMessage;
  String get partialMessage;
  String get retryLabel;
  Future<int> readBalance(int previewBalance);
  Future<int> refill(EnergyOffer offer, int balance);
}

class MockEnergyRepository implements EnergyRepository {
  @override
  int get capacity => 25;
  @override
  String get fullMessage => 'Your energy is full.';
  @override
  String get partialMessage => 'Recharge your energy to keep learning.';
  @override
  String get retryLabel => 'TRY AGAIN';
  @override
  List<EnergyOffer> get offers => const [
    EnergyOffer(EnergyRefillKind.recharge, 25, 'Recharge', '500', cost: 500),
    EnergyOffer(EnergyRefillKind.ad, 5, '+5 energy', 'WATCH AD'),
    EnergyOffer(EnergyRefillKind.free, 2, '+2 energy', 'FREE'),
  ];
  @override
  Future<int> readBalance(int previewBalance) async => previewBalance;
  @override
  Future<int> refill(EnergyOffer offer, int balance) async =>
      (offer.kind == EnergyRefillKind.recharge
              ? capacity
              : balance + offer.amount)
          .clamp(0, capacity);
}

/// Server-authoritative energy reads and refills.
///
/// Recharge buys the server's `ENERGY_REFILL` shop item; ads and free offers
/// grant through their own server flows. Every refill waits for the server
/// balance to rise instead of echoing the requested amount.
class ApiEnergyRepository extends MockEnergyRepository {
  ApiEnergyRepository(
    this.api, {
    this.pollInterval = const Duration(milliseconds: 400),
    this.polls = 5,
    IdGenerator? ids,
  }) : _ids = ids ?? UuidV4Generator();

  final ApiEndpoints api;
  final Duration pollInterval;
  final int polls;
  final IdGenerator _ids;

  @override
  Future<int> readBalance(int previewBalance) async =>
      (await api.getEnergy()).balance;

  @override
  Future<int> refill(EnergyOffer offer, int balance) async {
    if (offer.kind == EnergyRefillKind.recharge) {
      final shop = await api.listShop();
      final item = shop.items
          .where((candidate) => candidate.kind == 'ENERGY_REFILL')
          .firstOrNull;
      if (item == null || !item.available) return balance;
      await api.buyItem(
        wire.ShopPurchaseRequest(
          itemId: item.itemId,
          quantity: 1,
          catalogVersion: shop.catalogVersion,
        ),
        idempotencyKey: _ids.next(),
      );
    }
    return _awaitIncrease(balance);
  }

  Future<int> _awaitIncrease(int balance) async {
    var current = balance;
    for (var poll = 0; poll < polls; poll++) {
      current = await readBalance(current);
      if (current > balance) return current;
      if (poll + 1 < polls && pollInterval > Duration.zero) {
        await Future<void>.delayed(pollInterval);
      }
    }
    return current;
  }
}
