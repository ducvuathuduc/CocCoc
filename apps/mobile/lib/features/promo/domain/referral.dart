/// Referral invite codes: `GET /v1/me/referral` returns the inviter's code and
/// counters, `POST /v1/referrals/redeem` accepts a friend's code once (the
/// server then grants the 7-day Super trial to both). Codes are 4–16 of
/// `[A-Za-z0-9-]`, compared case-insensitively. No referral screen exists yet,
/// so this is the data layer only.
class ReferralStatus {
  const ReferralStatus({
    required this.code,
    required this.accepted,
    required this.qualified,
    required this.rewarded,
    required this.asOf,
  });
  final String code;
  final int accepted, qualified, rewarded;
  final DateTime asOf;
}

enum ReferralFailure { invalidFormat, notFound, offline, failed }

/// Either an accepted code or a [failure]; the server treats a replay as
/// accepted.
class ReferralRedeemResult {
  const ReferralRedeemResult.success()
    : failure = null;
  const ReferralRedeemResult.failure(ReferralFailure this.failure);
  final ReferralFailure? failure;
  bool get accepted => failure == null;
}

/// Contract shape: 4–16 of `[A-Za-z0-9-]`, compared case-insensitively.
String? normalizeReferralCode(String raw) {
  final code = raw.trim().toUpperCase();
  return RegExp(r'^[A-Z0-9-]{4,16}$').hasMatch(code) ? code : null;
}
