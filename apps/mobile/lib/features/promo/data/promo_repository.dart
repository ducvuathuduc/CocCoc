import '../domain/promo.dart';

abstract class PromoRepository {
  PromoContent get content;

  /// [code] is already normalized by [normalizePromoCode].
  Future<PromoResult> redeem(String code, String idempotencyKey);
}

/// In-memory stand-in for P10-PROMO-001: one redemption per code per learner,
/// unknown codes indistinguishable from expired ones.
class MockPromoRepository implements PromoRepository {
  MockPromoRepository({
    this.content = const PromoContent(),
    Map<String, PromoReward>? codes,
  }) : codes = codes ?? defaultCodes;

  static const defaultCodes = {
    'COCSUPER7': PromoReward(
      promoId: 'promo-super-7',
      type: PromoRewardType.superDays,
      superDays: 7,
    ),
    'GEMS500': PromoReward(
      promoId: 'promo-gems-500',
      type: PromoRewardType.gems,
      gems: 500,
    ),
    'FREEZE-2': PromoReward(
      promoId: 'promo-freeze-2',
      type: PromoRewardType.item,
      itemId: 'streak_freeze',
      itemQuantity: 2,
    ),
  };

  @override
  final PromoContent content;
  final Map<String, PromoReward> codes;
  final redeemed = <String>{};
  final _receipts = <String, PromoResult>{};

  @override
  Future<PromoResult> redeem(String code, String idempotencyKey) async {
    final replay = _receipts[idempotencyKey];
    if (replay != null) return replay;
    final reward = codes[code];
    final result = reward == null
        ? const PromoResult.failure(PromoFailure.notFound)
        : redeemed.contains(reward.promoId)
        ? const PromoResult.failure(PromoFailure.alreadyRedeemed)
        : PromoResult.success(reward);
    if (result.reward != null) redeemed.add(reward!.promoId);
    return _receipts[idempotencyKey] = result;
  }
}
