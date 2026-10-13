enum HeartOption { superTrial, practice, refill }

/// Which lives currency the home stats bar shows. The newer Energy model is
/// the default; Hearts-model learners (every hearts Gummble capture, e.g.
/// sc_12b09a6c, sc_901080ed) see the heart count and its dropdown instead.
enum LivesModel { energy, hearts }

class HeartsContent {
  const HeartsContent({
    this.superLabel = 'SUPER',
    this.lessonTitle = 'You ran out of hearts!',
    this.homeTitle = 'You need hearts to start new lessons!',
    this.nextHeartLabel = 'Next heart in',
    this.unlimitedLabel = 'Unlimited',
    this.trialLabel = 'FREE TRIAL',
    this.practiceTitle = '+1 Heart',
    this.practiceLabel = 'Practice',
    this.refillLabel = 'Refill',
    this.trialAction = 'TRY 1 WEEK FOR FREE',
    this.practiceAction = 'PRACTICE TO EARN HEARTS',
    this.refillAction = 'REFILL HEARTS',
    this.decline = 'NO THANKS',
    this.later = 'NOT NOW',
    this.earnedTitle = 'You gained a heart!',
    this.earnedAdTitle = 'You gained a heart! Watch an ad to gain another.',
    this.earnAction = 'EARN 1 HEART',
    this.continueAction = 'CONTINUE',
    this.practiceError = 'Practice unavailable. Try again.',
    this.unlimitedHeartsAction = 'UNLIMITED HEARTS',
    this.fullHeartsLabel = 'You have full hearts',
    this.closeHeartsLabel = 'Close hearts',
    this.heartsCountJoin = ' of ',
    this.heartsCountSuffix = ' hearts',
    this.homeTrialHearts = 76,
    this.lessonTrialHearts = 88,
    this.homeRefillCost = 500,
    this.lessonRefillCost = 600,
  });
  final String superLabel,
      lessonTitle,
      homeTitle,
      nextHeartLabel,
      unlimitedLabel,
      trialLabel,
      practiceTitle,
      practiceLabel,
      refillLabel,
      trialAction,
      practiceAction,
      refillAction,
      decline,
      later,
      earnedTitle,
      earnedAdTitle,
      earnAction,
      continueAction,
      practiceError,
      unlimitedHeartsAction,
      fullHeartsLabel,
      closeHeartsLabel,
      heartsCountJoin,
      heartsCountSuffix;
  String heartsCount(int balance, int capacity) =>
      '$balance$heartsCountJoin$capacity$heartsCountSuffix';
  final int homeRefillCost,
      lessonRefillCost,
      homeTrialHearts,
      lessonTrialHearts;
}

class HeartsState {
  const HeartsState({
    this.balance = 0,
    this.capacity = 5,
    this.nextHeartIn = const Duration(hours: 4, minutes: 15),
    this.practicePending = false,
    this.claims = const {},
  });
  final int balance, capacity;
  final Duration nextHeartIn;
  final bool practicePending;
  final Set<String> claims;
  String get countdown =>
      '${nextHeartIn.inHours}h ${nextHeartIn.inMinutes % 60}m';
}
