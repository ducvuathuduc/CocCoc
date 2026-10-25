import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/shop_controller.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import 'api_shop_repository.dart';
import '../../xp_boost/domain/boost.dart';

abstract class ShopRepository {
  Future<ShopState> loadShop({bool refresh = false});
  Future<void> buyItem(String id, int displayCost, {required String commandId});
}

abstract final class ShopPresentationCatalog {
  static const specialOffers = [
    ShopOffer(
      id: 'friends-chest',
      title: 'Friends Chest',
      actionLabel: 'CLAIM',
      rewardGems: 20,
      xpBoost: BoostReward(itemId: 'xp-boost', multiplier: 2, minutes: 15),
    ),
    ShopOffer(
      id: 'widget-reward',
      title: 'Widget Reward',
      actionLabel: 'CLAIM',
    ),
    ShopOffer(
      id: 'genshin-reward',
      title: 'Genshin Impact\nReward',
      actionLabel: 'CLAIM',
      rewardGems: 50,
    ),
    ShopOffer(
      id: 'early-bird',
      title: 'Early Bird Chest',
      actionLabel: 'LOCKED',
    ),
    ShopOffer(id: 'night-owl', title: 'Night Owl Chest', actionLabel: 'LOCKED'),
  ];

  static const timerBoostOffers = [
    ShopOffer(id: 'timer-single', title: 'Single', price: 450),
    ShopOffer(id: 'timer-5', title: '5 pack', price: 1800, popular: true),
    ShopOffer(id: 'timer-15', title: '15 pack', price: 4500, popular: true),
  ];

  static const freezeOffer = ShopOffer(
    id: 'freeze',
    title: '1-day',
    price: 425,
  );
}

class MockShopRepository implements ShopRepository {
  int _wallet = 1035;
  int _freezes = 2;
  int _timerBoosts = 0;

  @override
  Future<void> buyItem(
    String id,
    int displayCost, {
    required String commandId,
  }) async {
    if (_wallet >= displayCost) {
      _wallet -= displayCost;
      if (id.startsWith('freeze')) _freezes++;
      if (id.startsWith('timer-single')) _timerBoosts += 1;
      if (id.startsWith('timer-5')) _timerBoosts += 5;
      if (id.startsWith('timer-15')) _timerBoosts += 15;
    }
  }

  @override
  Future<ShopState> loadShop({bool refresh = false}) async => ShopState(
    wallet: _wallet,
    freezes: _freezes,
    timerBoosts: _timerBoosts,
    specialOffers: ShopPresentationCatalog.specialOffers,
    timerBoostOffers: ShopPresentationCatalog.timerBoostOffers,
    freezeOffer: ShopPresentationCatalog.freezeOffer,
  );
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  if (ref.watch(appConfigProvider).isApi) {
    return ApiShopRepository(ref.watch(apiEndpointsProvider));
  }
  return MockShopRepository();
});
