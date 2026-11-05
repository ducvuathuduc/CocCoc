import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/api/client/idempotency.dart';
import '../../../core/config/app_config.dart';
import '../../progress/application/preview_controller.dart';
import '../data/api_promo_repository.dart';
import '../data/promo_repository.dart';
import '../domain/promo.dart';

final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return MockPromoRepository();
  return ApiPromoRepository(ref.watch(apiEndpointsProvider));
});
final promoContentProvider = Provider<PromoContent>(
  (ref) => ref.watch(promoRepositoryProvider).content,
);
final promoControllerProvider =
    NotifierProvider.autoDispose<PromoController, PromoState>(
      PromoController.new,
    );

class PromoController extends Notifier<PromoState> {
  final _keys = <String, String>{};
  int _epoch = 0;
  @override
  PromoState build() {
    _epoch++;
    ref.onDispose(() => _epoch++);
    return const PromoState();
  }

  /// Clears a shown error once the learner edits the code.
  void edited() {
    if (state.failure != null) state = const PromoState();
  }

  Future<bool> redeem(String raw) async {
    if (state.busy || state.reward != null) return false;
    final code = normalizePromoCode(raw);
    if (code == null) {
      state = const PromoState(failure: PromoFailure.invalidFormat);
      return false;
    }
    state = const PromoState(busy: true);
    // One key per code, so a retry after a lost response replays the receipt.
    final key = _keys.putIfAbsent(code, UuidV4Generator().next);
    final epoch = _epoch;
    final result = await ref.read(promoRepositoryProvider).redeem(code, key);
    if (!ref.mounted || epoch != _epoch) return false;
    final reward = result.reward;
    if (reward == null) {
      state = PromoState(failure: result.failure);
      return false;
    }
    // Mock preview wallet only; the API credits gems server-side.
    if (reward.type == PromoRewardType.gems &&
        !ref.read(appConfigProvider).isApi) {
      ref
          .read(previewControllerProvider.notifier)
          .claimShopReward('promo-${reward.promoId}', reward.gems ?? 0);
    }
    state = PromoState(reward: reward);
    return true;
  }
}
