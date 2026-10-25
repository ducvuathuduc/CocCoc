import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/idempotency.dart';
import '../data/shop_repository.dart';
import '../../xp_boost/domain/boost.dart';

class ShopOffer {
  const ShopOffer({
    required this.id,
    required this.title,
    this.actionLabel,
    this.price,
    this.popular = false,
    this.rewardGems,
    this.xpBoost,
    this.available = true,
  });
  final String id;
  final String title;
  final String? actionLabel;
  final int? price;
  final bool popular;

  /// Gems granted when a CLAIM offer is opened (mock data until the API).
  final int? rewardGems;
  final BoostReward? xpBoost;
  final bool available;
}

class ShopState {
  const ShopState({
    required this.wallet,
    required this.freezes,
    required this.timerBoosts,
    required this.specialOffers,
    required this.timerBoostOffers,
    required this.freezeOffer,
  });
  final int wallet;
  final int freezes;
  final int timerBoosts;
  final List<ShopOffer> specialOffers;
  final List<ShopOffer> timerBoostOffers;
  final ShopOffer freezeOffer;
}

class ShopController extends Notifier<AsyncValue<ShopState>> {
  final IdGenerator _ids = UuidV4Generator();
  final Map<String, String> _pendingCommands = {};
  int _generation = 0;
  bool _busy = false;
  late ShopRepository _repository;

  @override
  AsyncValue<ShopState> build() {
    _repository = ref.watch(shopRepositoryProvider);
    final repository = _repository;
    final generation = ++_generation;
    _busy = false;
    _pendingCommands.clear();
    Future<void>(() => _load(repository, generation));
    return const AsyncLoading();
  }

  Future<void> _load(
    ShopRepository repository,
    int generation, {
    bool refresh = false,
  }) async {
    final previous = state.value;
    try {
      final next = await repository.loadShop(refresh: refresh);
      if (!ref.mounted ||
          generation != _generation ||
          repository != _repository) {
        return;
      }
      state = AsyncData(next);
    } catch (error, stack) {
      if (!ref.mounted ||
          generation != _generation ||
          repository != _repository) {
        return;
      }
      if (previous == null) state = AsyncError(error, stack);
    }
  }

  Future<void> refresh() async {
    final repository = _repository;
    final generation = _generation;
    if (state.value == null) state = const AsyncLoading();
    await _load(repository, generation, refresh: true);
  }

  Future<bool> buyItem(String id, int displayCost) async {
    if (_busy) return false;
    final s = state.value;
    if (s == null) return false;
    final offers = [...s.timerBoostOffers, s.freezeOffer];
    final offer = offers.where((candidate) => candidate.id == id).firstOrNull;
    final serverPrice = offer?.price;
    if (offer == null ||
        !offer.available ||
        serverPrice == null ||
        s.wallet < serverPrice) {
      return false;
    }
    final repository = _repository;
    final generation = _generation;
    final commandId = _pendingCommands.putIfAbsent(id, _ids.next);
    _busy = true;
    try {
      await repository.buyItem(id, displayCost, commandId: commandId);
      if (!ref.mounted ||
          generation != _generation ||
          repository != _repository) {
        return false;
      }
      _pendingCommands.remove(id);
      await _load(repository, generation);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (generation == _generation && repository == _repository) _busy = false;
    }
  }
}

final shopControllerProvider =
    NotifierProvider<ShopController, AsyncValue<ShopState>>(ShopController.new);
