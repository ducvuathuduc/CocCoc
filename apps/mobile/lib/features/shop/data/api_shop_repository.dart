import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../application/shop_controller.dart';
import 'shop_repository.dart';

/// [ShopRepository] backed by `GET /v1/shop` and `POST /v1/shop/purchases`.
/// Gems, freezes and inventory are server-authoritative; offer copy (titles,
/// pack sizes) stays the UI catalog from [catalog].
class ApiShopRepository implements ShopRepository {
  ApiShopRepository(this.api, {ShopRepository? catalog})
    : catalog = catalog ?? MockShopRepository();

  final ApiEndpoints api;
  final ShopRepository catalog;
  wire.Shop? _shop;

  Future<wire.Shop> _load({bool refresh = false}) async {
    final cached = _shop;
    if (cached != null && !refresh) return cached;
    return _shop = await api.listShop();
  }

  @override
  Future<int> getWallet() async => (await _load()).gems;

  @override
  Future<int> getFreezes() async => (await _load()).freezeSlots;

  @override
  Future<int> getTimerBoosts() async {
    final shop = await _load();
    final ids = shop.items
        .where((item) => item.kind == 'TIMER_BOOST')
        .map((item) => item.itemId)
        .toSet();
    return shop.inventory
        .where((item) => ids.contains(item.itemId))
        .fold<int>(0, (sum, item) => sum + item.quantity);
  }

  /// UI offer id -> (server item kind, quantity).
  static (String, int) _resolve(String id) {
    if (id.startsWith('freeze')) return ('FREEZE', 1);
    if (id.startsWith('timer-15')) return ('TIMER_BOOST', 15);
    if (id.startsWith('timer-5')) return ('TIMER_BOOST', 5);
    if (id.startsWith('timer')) return ('TIMER_BOOST', 1);
    if (id.contains('repair')) return ('STREAK_REPAIR', 1);
    if (id.contains('amulet')) return ('WEEKEND_AMULET', 1);
    if (id.contains('energy') || id.contains('refill')) {
      return ('ENERGY_REFILL', 1);
    }
    if (id.contains('xp') || id.contains('boost')) return ('XP_BOOST', 1);
    throw ApiException(
      code: 'ITEM_UNAVAILABLE',
      message: 'No catalog item for $id',
    );
  }

  /// [cost] is ignored: the server prices the item from its catalog.
  @override
  Future<void> buyItem(String id, int cost) async {
    final shop = await _load();
    final (kind, quantity) = _resolve(id);
    final item = shop.items.where((i) => i.kind == kind).firstOrNull;
    if (item == null) {
      throw ApiException(code: 'ITEM_UNAVAILABLE', message: kind);
    }
    var remaining = quantity;
    while (remaining > 0) {
      final batch = remaining > 10 ? 10 : remaining;
      await api.buyItem(
        wire.ShopPurchaseRequest(
          itemId: item.itemId,
          quantity: batch,
          catalogVersion: shop.catalogVersion,
        ),
      );
      remaining -= batch;
    }
    await _load(refresh: true);
  }

  @override
  Future<List<ShopOffer>> getSpecialOffers() => catalog.getSpecialOffers();

  @override
  Future<List<ShopOffer>> getTimerBoostOffers() =>
      catalog.getTimerBoostOffers();
}
