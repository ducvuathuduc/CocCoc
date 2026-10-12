import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/shop_controller.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import 'api_shop_repository.dart';

abstract class ShopRepository {
  Future<int> getWallet();
  Future<void> buyItem(String id, int cost);
  Future<int> getFreezes();
  Future<int> getTimerBoosts();
  Future<List<ShopOffer>> getSpecialOffers();
  Future<List<ShopOffer>> getTimerBoostOffers();
}

class MockShopRepository implements ShopRepository {
  int _wallet = 1035;
  int _freezes = 2;
  int _timerBoosts = 0;

  @override
  Future<int> getWallet() async => _wallet;

  @override
  Future<void> buyItem(String id, int cost) async {
    if (_wallet >= cost) {
      _wallet -= cost;
      if (id.startsWith('freeze')) _freezes++;
      if (id.startsWith('timer-single')) _timerBoosts += 1;
      if (id.startsWith('timer-5')) _timerBoosts += 5;
      if (id.startsWith('timer-15')) _timerBoosts += 15;
    }
  }

  @override
  Future<int> getFreezes() async => _freezes;

  @override
  Future<int> getTimerBoosts() async => _timerBoosts;

  @override
  Future<List<ShopOffer>> getSpecialOffers() async {
    return const [
      ShopOffer(
        id: 'friends-chest',
        title: 'Friends Chest',
        actionLabel: 'CLAIM',
        rewardGems: 20,
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
      ShopOffer(
        id: 'night-owl',
        title: 'Night Owl Chest',
        actionLabel: 'LOCKED',
      ),
    ];
  }

  @override
  Future<List<ShopOffer>> getTimerBoostOffers() async {
    return const [
      ShopOffer(id: 'timer-single', title: 'Single', price: 450),
      ShopOffer(id: 'timer-5', title: '5 pack', price: 1800, popular: true),
      ShopOffer(id: 'timer-15', title: '15 pack', price: 4500, popular: true),
    ];
  }
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  if (ref.watch(appConfigProvider).isApi) {
    return ApiShopRepository(ref.watch(apiEndpointsProvider));
  }
  return MockShopRepository();
});
