import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../domain/referral.dart';
import 'referral_repository.dart';

/// `getReferral` (`GET /v1/me/referral`) and `redeemReferral`
/// (`POST /v1/referrals/redeem`).
class ApiReferralRepository implements ReferralRepository {
  ApiReferralRepository(this.api);
  final ApiEndpoints api;

  @override
  Future<ReferralStatus> load() async {
    final r = await api.getReferral();
    return ReferralStatus(
      code: r.code,
      accepted: r.accepted,
      qualified: r.qualified,
      rewarded: r.rewarded,
      asOf: DateTime.parse(r.asOf),
    );
  }

  @override
  Future<ReferralRedeemResult> redeem(
    String raw, {
    String? idempotencyKey,
  }) async {
    final code = normalizeReferralCode(raw);
    if (code == null) {
      return const ReferralRedeemResult.failure(ReferralFailure.invalidFormat);
    }
    try {
      await api.redeemReferral(
        wire.ReferralRedeemRequest(code: code),
        idempotencyKey: idempotencyKey,
      );
      return const ReferralRedeemResult.success();
    } on ApiException catch (error) {
      if (error.isOffline) {
        return const ReferralRedeemResult.failure(ReferralFailure.offline);
      }
      if (error.isNotFound || error.code == 'NOT_FOUND') {
        return const ReferralRedeemResult.failure(ReferralFailure.notFound);
      }
      return const ReferralRedeemResult.failure(ReferralFailure.failed);
    }
  }
}
