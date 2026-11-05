import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/idempotency.dart';
import '../application/shop_controller.dart';
import '../../xp_boost/domain/boost.dart';
import 'shop_repository.dart';

/// Server-authoritative shop projection and purchase commands.
///
/// Titles and artwork IDs come from the immutable mock catalog. Availability,
/// prices, balances and inventory always come from `GET /v1/shop`.
class ApiShopRepository implements ShopRepository {
  ApiShopRepository(this.api, {IdGenerator? ids})
    : _ids = ids ?? UuidV4Generator();

  final ApiEndpoints api;
  final IdGenerator _ids;
  final Map<String, _PendingPurchase> _pendingPurchases = {};
  wire.Shop? _shop;

  Future<wire.Shop> _load({bool refresh = false}) async {
    final cached = _shop;
    if (cached != null && !refresh) return cached;
    return _shop = await api.listShop();
  }

  @override
  Future<ShopState> loadShop({bool refresh = false}) async {
    final shop = await _load(refresh: refresh);
    final timerItem = shop.items
        .where((item) => item.kind == 'TIMER_BOOST')
        .firstOrNull;
    final freezeItem = shop.items
        .where((item) => item.kind == 'FREEZE')
        .firstOrNull;
    final boostItem = shop.items
        .where((item) => item.kind == 'XP_BOOST')
        .firstOrNull;
    final boostQuantity = boostItem == null
        ? 0
        : shop.inventory
              .where((item) => item.itemId == boostItem.itemId)
              .fold<int>(0, (sum, item) => sum + item.quantity);
    final chestAvailable =
        boostItem != null && boostItem.available && boostQuantity > 0;
    final timerBoosts = timerItem == null
        ? 0
        : shop.inventory
              .where((item) => item.itemId == timerItem.itemId)
              .fold<int>(0, (sum, item) => sum + item.quantity);
    final timerOffers = timerItem == null
        ? const <ShopOffer>[]
        : [
            for (final offer in ShopPresentationCatalog.timerBoostOffers)
              ShopOffer(
                id: offer.id,
                title: offer.title,
                price: timerItem.priceGems * _quantityFor(offer.id),
                popular: offer.popular,
                available:
                    timerItem.available &&
                    timerItem.owned + _quantityFor(offer.id) <=
                        timerItem.maxOwned,
              ),
          ];
    return ShopState(
      wallet: shop.gems,
      freezes: shop.freezeSlots,
      timerBoosts: timerBoosts,
      specialOffers: [
        for (final offer in ShopPresentationCatalog.specialOffers)
          if (offer.id == 'friends-chest' && boostItem != null)
            ShopOffer(
              id: offer.id,
              title: offer.title,
              actionLabel: chestAvailable ? 'CLAIM' : 'LOCKED',
              available: chestAvailable,
              // The activated item comes from the server inventory, never the
              // presentation catalog.
              xpBoost: BoostReward(
                itemId: boostItem.itemId,
                multiplier: offer.xpBoost?.multiplier ?? 2,
                minutes:
                    boostItem.durationMinutes ?? offer.xpBoost?.minutes ?? 15,
              ),
            )
          else
            ShopOffer(
              id: offer.id,
              title: offer.title,
              actionLabel: 'LOCKED',
              available: false,
            ),
      ],
      timerBoostOffers: timerOffers,
      freezeOffer: ShopOffer(
        id: 'freeze',
        title: '1-day',
        price: freezeItem?.priceGems,
        available:
            freezeItem != null &&
            freezeItem.available &&
            freezeItem.owned < freezeItem.maxOwned,
      ),
    );
  }

  static int _quantityFor(String id) => switch (id) {
    'timer-15' => 15,
    'timer-5' => 5,
    _ => 1,
  };

  static (String, int) _resolve(String id) {
    if (id.startsWith('freeze')) return ('FREEZE', 1);
    if (id.startsWith('timer')) return ('TIMER_BOOST', _quantityFor(id));
    throw ApiException(code: 'ITEM_UNAVAILABLE', message: 'Item unavailable.');
  }

  @override
  Future<void> buyItem(
    String id,
    int displayCost, {
    required String commandId,
  }) async {
    final pending = _pendingPurchases[commandId];
    if (pending != null) {
      await _submit(pending);
      await _load(refresh: true);
      _pendingPurchases.remove(commandId);
      return;
    }
    final shop = await _load();
    final (kind, quantity) = _resolve(id);
    final item = shop.items
        .where((candidate) => candidate.kind == kind)
        .firstOrNull;
    if (item == null ||
        !item.available ||
        item.owned + quantity > item.maxOwned) {
      throw ApiException(
        code: 'ITEM_UNAVAILABLE',
        message: 'Item unavailable.',
      );
    }
    final batches = <int>[];
    for (var remaining = quantity; remaining > 0; remaining -= batches.last) {
      batches.add(remaining > 10 ? 10 : remaining);
    }
    final created = _PendingPurchase(
      requests: [
        for (final batch in batches)
          wire.ShopPurchaseRequest(
            itemId: item.itemId,
            quantity: batch,
            catalogVersion: shop.catalogVersion,
          ),
      ],
      keys: [
        commandId,
        for (var index = 1; index < batches.length; index++) _ids.next(),
      ],
    );
    _pendingPurchases[commandId] = created;
    await _submit(created);
    await _load(refresh: true);
    _pendingPurchases.remove(commandId);
  }

  Future<void> _submit(_PendingPurchase pending) async {
    for (var index = 0; index < pending.requests.length; index++) {
      await api.buyItem(
        pending.requests[index],
        idempotencyKey: pending.keys[index],
      );
    }
  }
}

final class _PendingPurchase {
  const _PendingPurchase({required this.requests, required this.keys});

  final List<wire.ShopPurchaseRequest> requests;
  final List<String> keys;
}
