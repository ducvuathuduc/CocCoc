/// Promo code redemption (audit row 32, P10-PROMO-001). Gummble lists an
/// Android "Redeem a promo code" flow with no screens captured, so this UI is
/// derived from the app's settings pages. Contract: `POST
/// /v1/promo-codes/redeem` → PromoRedemption; unknown, expired and exhausted
/// codes share NOT_FOUND; a second redemption is PROMO_ALREADY_REDEEMED.
enum PromoRewardType { superDays, gems, item }

class PromoReward {
  const PromoReward({
    required this.promoId,
    required this.type,
    this.superDays,
    this.gems,
    this.itemId,
    this.itemQuantity,
  });
  final String promoId;
  final PromoRewardType type;
  final int? superDays, gems, itemQuantity;
  final String? itemId;
}

enum PromoFailure { invalidFormat, notFound, alreadyRedeemed, offline, failed }

/// Either [reward] or [failure] is set.
class PromoResult {
  const PromoResult.success(PromoReward this.reward) : failure = null;
  const PromoResult.failure(PromoFailure this.failure) : reward = null;
  final PromoReward? reward;
  final PromoFailure? failure;
}

class PromoContent {
  const PromoContent({
    this.pageTitle = 'Promo code',
    this.title = 'Redeem a promo code',
    this.body = 'Enter your code to unlock Super, gems or items.',
    this.hint = 'Enter code',
    this.action = 'REDEEM',
    this.invalidFormat = 'Codes use 4–32 letters, numbers or dashes.',
    this.notFound = 'That code isn’t valid or has expired.',
    this.alreadyRedeemed = 'You’ve already redeemed this code.',
    this.offline = 'You’re offline. Connect and try again.',
    this.failed = 'Something went wrong. Try again.',
    this.successTitle = 'Code redeemed!',
    this.superDaysPrefix = 'You got ',
    this.superDaysSuffix = ' days of Super Duolingo.',
    this.gemsSuffix = ' gems were added to your account.',
    this.itemsSuffix = ' added to your inventory.',
    this.itemNames = const {
      'streak_freeze': 'Streak Freeze',
      'streak_repair': 'Streak Repair',
      'xp_boost': 'XP Boost',
    },
    this.continueAction = 'CONTINUE',
  });
  final String pageTitle,
      title,
      body,
      hint,
      action,
      invalidFormat,
      notFound,
      alreadyRedeemed,
      offline,
      failed,
      successTitle,
      superDaysPrefix,
      superDaysSuffix,
      gemsSuffix,
      itemsSuffix,
      continueAction;
  final Map<String, String> itemNames;

  String error(PromoFailure f) => switch (f) {
    PromoFailure.invalidFormat => invalidFormat,
    PromoFailure.notFound => notFound,
    PromoFailure.alreadyRedeemed => alreadyRedeemed,
    PromoFailure.offline => offline,
    PromoFailure.failed => failed,
  };

  String reward(PromoReward r) => switch (r.type) {
    PromoRewardType.superDays =>
      '$superDaysPrefix${r.superDays}$superDaysSuffix',
    PromoRewardType.gems => '${r.gems}$gemsSuffix',
    PromoRewardType.item =>
      '${r.itemQuantity ?? 1}× ${itemNames[r.itemId] ?? r.itemId}$itemsSuffix',
  };
}

/// Contract shape: 4–32 of `[A-Za-z0-9-]`, compared case-insensitively.
String? normalizePromoCode(String raw) {
  final code = raw.trim().toUpperCase();
  return RegExp(r'^[A-Z0-9-]{4,32}$').hasMatch(code) ? code : null;
}

class PromoState {
  const PromoState({this.busy = false, this.failure, this.reward});
  final bool busy;
  final PromoFailure? failure;
  final PromoReward? reward;
}
