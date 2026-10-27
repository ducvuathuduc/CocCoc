import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../domain/referral.dart';
import 'api_referral_repository.dart';

/// Referral codes (inviter counters + invitee redemption).
abstract interface class ReferralRepository {
  /// `GET /v1/me/referral`; throws [ApiException] when the status is unknown.
  Future<ReferralStatus> load();

  /// `POST /v1/referrals/redeem`; [code] is normalized by the repository.
  Future<ReferralRedeemResult> redeem(String code, {String? idempotencyKey});
}

/// In-memory stand-in: one issued code per learner, own code is not redeemable,
/// a replay of an accepted code stays accepted.
class MockReferralRepository implements ReferralRepository {
  MockReferralRepository({
    this.code = 'COCFRIEND2026',
    this.latency = Duration.zero,
  });

  final String code;
  final Duration latency;
  final Set<String> _accepted = {};

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<ReferralStatus> load() async {
    await _wait();
    return ReferralStatus(
      code: code,
      accepted: _accepted.length,
      qualified: _accepted.length,
      rewarded: _accepted.length,
      asOf: DateTime.now().toUtc(),
    );
  }

  @override
  Future<ReferralRedeemResult> redeem(
    String raw, {
    String? idempotencyKey,
  }) async {
    await _wait();
    final normalized = normalizeReferralCode(raw);
    if (normalized == null) {
      return const ReferralRedeemResult.failure(
        ReferralFailure.invalidFormat,
      );
    }
    // The server resolves the inviter's own ISSUED row only; self is invalid.
    if (normalized == code) {
      return const ReferralRedeemResult.failure(ReferralFailure.notFound);
    }
    _accepted.add(normalized);
    return const ReferralRedeemResult.success();
  }
}

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return MockReferralRepository();
  return ApiReferralRepository(ref.watch(apiEndpointsProvider));
});
