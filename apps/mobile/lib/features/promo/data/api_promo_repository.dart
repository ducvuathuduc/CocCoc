import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../domain/promo.dart';
import 'promo_repository.dart';

/// `redeemPromoCode` (P10-PROMO-001).
class ApiPromoRepository implements PromoRepository {
  ApiPromoRepository(this.api);
  final ApiEndpoints api;
  @override
  PromoContent get content => const PromoContent();

  @override
  Future<PromoResult> redeem(String code, String idempotencyKey) async {
    try {
      final r = await api.redeemPromoCode(
        wire.PromoRedeemRequest(code: code),
        idempotencyKey: idempotencyKey,
      );
      return PromoResult.success(
        PromoReward(
          promoId: r.promoId,
          type: switch (r.rewardType) {
            'SUPER_DAYS' => PromoRewardType.superDays,
            'GEMS' => PromoRewardType.gems,
            _ => PromoRewardType.item,
          },
          superDays: r.superDays,
          gems: r.gems,
          itemId: r.itemId,
          itemQuantity: r.itemQuantity,
        ),
      );
    } on ApiException catch (e) {
      if (e.code == 'PROMO_ALREADY_REDEEMED') {
        return const PromoResult.failure(PromoFailure.alreadyRedeemed);
      }
      if (e.isNotFound || e.code == 'NOT_FOUND') {
        return const PromoResult.failure(PromoFailure.notFound);
      }
      if (e.code == 'VALIDATION_FAILED' || e.statusCode == 400) {
        return const PromoResult.failure(PromoFailure.invalidFormat);
      }
      return PromoResult.failure(
        e.isOffline ? PromoFailure.offline : PromoFailure.failed,
      );
    }
  }
}
