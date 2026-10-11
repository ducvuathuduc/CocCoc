import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shop_repository.dart';

class ShopOffer {
  const ShopOffer({
    required this.id,
    required this.title,
    this.actionLabel,
    this.price,
    this.popular = false,
    this.rewardGems,
  });
  final String id;
  final String title;
  final String? actionLabel;
  final int? price;
  final bool popular;

  /// Gems granted when a CLAIM offer is opened (mock data until the API).
  final int? rewardGems;
}

class ShopState {
  const ShopState({
    required this.wallet,
    required this.freezes,
    required this.timerBoosts,
    required this.specialOffers,
    required this.timerBoostOffers,
  });
  final int wallet;
  final int freezes;
  final int timerBoosts;
  final List<ShopOffer> specialOffers;
  final List<ShopOffer> timerBoostOffers;
}

class ShopController extends Notifier<AsyncValue<ShopState>> {
  @override
  AsyncValue<ShopState> build() {
    _load();
    return const AsyncLoading();
  }

  ShopRepository get repository => ref.read(shopRepositoryProvider);

  Future<void> _load() async {
    final wallet = await repository.getWallet();
    final freezes = await repository.getFreezes();
    final timerBoosts = await repository.getTimerBoosts();
    final specialOffers = await repository.getSpecialOffers();
    final timerBoostOffers = await repository.getTimerBoostOffers();
    state = AsyncData(
      ShopState(
        wallet: wallet,
        freezes: freezes,
        timerBoosts: timerBoosts,
        specialOffers: specialOffers,
        timerBoostOffers: timerBoostOffers,
      ),
    );
  }

  Future<bool> buyItem(String id, int cost) async {
    final s = state.value;
    if (s == null) return false;
    if (s.wallet < cost) return false;
    await repository.buyItem(id, cost);
    await _load();
    return true;
  }
}

final shopControllerProvider =
    NotifierProvider<ShopController, AsyncValue<ShopState>>(ShopController.new);
