/// Streak repair (audit row 13). Gummble has no capture of this flow (iOS and
/// Android searched), so copy and layout are derived from the app's streak
/// screens. Wire contract: `POST /v1/me/streak-repair` (StreakRepairRequest
/// lostStreakDay + payWith GEMS|ITEM).
enum StreakRepairPayment { gems, item }

class StreakRepairOffer {
  const StreakRepairOffer({
    required this.lostDays,
    required this.lostStreakDay,
    this.gemCost = 350,
    this.repairItems = 0,
    this.expiresIn = const Duration(hours: 23, minutes: 40),
  });
  final int lostDays, gemCost, repairItems;

  /// `YYYY-MM-DD`, the day the streak was lost (contract field).
  final String lostStreakDay;
  final Duration expiresIn;
}

class StreakRepairContent {
  const StreakRepairContent({
    this.lostTitle = 'Your streak ended',
    this.lostBodyPrefix = 'Repair your ',
    this.lostBodySuffix = ' day streak before it’s gone for good!',
    this.expiresLabel = 'Offer ends in',
    this.gemsAction = 'REPAIR FOR',
    this.itemAction = 'USE STREAK REPAIR',
    this.itemsOwnedLabel = 'Streak Repairs owned',
    this.decline = 'NO THANKS',
    this.notEnoughGems = 'You don’t have enough gems.',
    this.failed = 'Couldn’t repair your streak. Try again.',
    this.repairedSuffix = ' day streak restored!',
    this.repairedBody = 'Do a lesson today to keep it going.',
    this.continueAction = 'CONTINUE',
    this.bannerTitle = 'Your streak can still be saved',
    this.bannerAction = 'REPAIR',
    this.closeLabel = 'Close streak repair',
  });
  final String lostTitle,
      lostBodyPrefix,
      lostBodySuffix,
      expiresLabel,
      gemsAction,
      itemAction,
      itemsOwnedLabel,
      decline,
      notEnoughGems,
      failed,
      repairedSuffix,
      repairedBody,
      continueAction,
      bannerTitle,
      bannerAction,
      closeLabel;
  String lostBody(int days) => '$lostBodyPrefix$days$lostBodySuffix';
  String repairedTitle(int days) => '$days$repairedSuffix';
  String countdown(Duration d) =>
      '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
}

class StreakRepairState {
  const StreakRepairState({
    this.offer,
    this.repairedDays,
    this.busy = false,
    this.error,
  });
  final StreakRepairOffer? offer;

  /// Set once a repair succeeds: the streak length that was restored.
  final int? repairedDays;
  final bool busy;
  final String? error;
  bool get repaired => repairedDays != null;
}
