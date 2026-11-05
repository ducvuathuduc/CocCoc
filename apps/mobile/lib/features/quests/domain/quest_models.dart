enum QuestChestType { bronze, silver, gold }

enum QuestSectionType { friends, weekend }

class DailyQuest {
  final String id;
  final String title;
  final int current;
  final int target;
  final QuestChestType chestType;
  final bool isClaimed;
  final bool isClaiming;
  final int rewardGems;

  const DailyQuest({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    this.chestType = QuestChestType.bronze,
    this.isClaimed = false,
    this.isClaiming = false,
    this.rewardGems = 10,
  });

  bool get isCompleted => current >= target;
  bool get canClaim => isCompleted && !isClaimed && !isClaiming;

  DailyQuest copyWith({
    String? id,
    String? title,
    int? current,
    int? target,
    QuestChestType? chestType,
    bool? isClaimed,
    bool? isClaiming,
    int? rewardGems,
  }) => DailyQuest(
    id: id ?? this.id,
    title: title ?? this.title,
    current: current ?? this.current,
    target: target ?? this.target,
    chestType: chestType ?? this.chestType,
    isClaimed: isClaimed ?? this.isClaimed,
    isClaiming: isClaiming ?? this.isClaiming,
    rewardGems: rewardGems ?? this.rewardGems,
  );
}

class MonthlyChallenge {
  final String title;
  final String daysRemaining;
  final int currentPoints;
  final int targetPoints;
  final String badgeName;

  const MonthlyChallenge({
    required this.title,
    required this.daysRemaining,
    required this.currentPoints,
    required this.targetPoints,
    required this.badgeName,
  });

  bool get isCompleted => currentPoints >= targetPoints;

  MonthlyChallenge copyWith({
    String? title,
    String? daysRemaining,
    int? currentPoints,
    int? targetPoints,
    String? badgeName,
  }) => MonthlyChallenge(
    title: title ?? this.title,
    daysRemaining: daysRemaining ?? this.daysRemaining,
    currentPoints: currentPoints ?? this.currentPoints,
    targetPoints: targetPoints ?? this.targetPoints,
    badgeName: badgeName ?? this.badgeName,
  );
}

class FriendsQuest {
  final String title;
  final String timeRemaining;
  final int target;
  final int userLessons;
  final int friendLessons;
  final String friendName;
  final bool isNudged;
  final bool isGifted;
  final bool isHighFived;
  final bool isOptedIn;

  const FriendsQuest({
    required this.title,
    required this.timeRemaining,
    required this.target,
    required this.userLessons,
    required this.friendLessons,
    required this.friendName,
    this.isNudged = false,
    this.isGifted = false,
    this.isHighFived = false,
    this.isOptedIn = false,
  });

  int get currentLessons => userLessons + friendLessons;
  bool get isCompleted => currentLessons >= target;

  FriendsQuest copyWith({
    String? title,
    String? timeRemaining,
    int? target,
    int? userLessons,
    int? friendLessons,
    String? friendName,
    bool? isNudged,
    bool? isGifted,
    bool? isHighFived,
    bool? isOptedIn,
  }) => FriendsQuest(
    title: title ?? this.title,
    timeRemaining: timeRemaining ?? this.timeRemaining,
    target: target ?? this.target,
    userLessons: userLessons ?? this.userLessons,
    friendLessons: friendLessons ?? this.friendLessons,
    friendName: friendName ?? this.friendName,
    isNudged: isNudged ?? this.isNudged,
    isGifted: isGifted ?? this.isGifted,
    isHighFived: isHighFived ?? this.isHighFived,
    isOptedIn: isOptedIn ?? this.isOptedIn,
  );
}

class WeekendQuest {
  final String title;
  final String timeRemaining;
  final int currentXp;
  final int targetXp;

  const WeekendQuest({
    required this.title,
    required this.timeRemaining,
    required this.currentXp,
    required this.targetXp,
  });

  bool get isCompleted => currentXp >= targetXp;

  WeekendQuest copyWith({
    String? title,
    String? timeRemaining,
    int? currentXp,
    int? targetXp,
  }) => WeekendQuest(
    title: title ?? this.title,
    timeRemaining: timeRemaining ?? this.timeRemaining,
    currentXp: currentXp ?? this.currentXp,
    targetXp: targetXp ?? this.targetXp,
  );
}

class QuestsTabState {
  final bool introSeen;
  final QuestSectionType sectionType;
  final MonthlyChallenge monthlyChallenge;
  final FriendsQuest friendsQuest;
  final WeekendQuest weekendQuest;
  final List<DailyQuest> dailyQuests;
  final String dailyTimeRemaining;
  final String? feedbackMessage;

  const QuestsTabState({
    this.introSeen = false,
    this.sectionType = QuestSectionType.friends,
    required this.monthlyChallenge,
    required this.friendsQuest,
    required this.weekendQuest,
    required this.dailyQuests,
    required this.dailyTimeRemaining,
    this.feedbackMessage,
  });

  QuestsTabState copyWith({
    bool? introSeen,
    QuestSectionType? sectionType,
    MonthlyChallenge? monthlyChallenge,
    FriendsQuest? friendsQuest,
    WeekendQuest? weekendQuest,
    List<DailyQuest>? dailyQuests,
    String? dailyTimeRemaining,
    String? feedbackMessage,
  }) => QuestsTabState(
    introSeen: introSeen ?? this.introSeen,
    sectionType: sectionType ?? this.sectionType,
    monthlyChallenge: monthlyChallenge ?? this.monthlyChallenge,
    friendsQuest: friendsQuest ?? this.friendsQuest,
    weekendQuest: weekendQuest ?? this.weekendQuest,
    dailyQuests: dailyQuests ?? this.dailyQuests,
    dailyTimeRemaining: dailyTimeRemaining ?? this.dailyTimeRemaining,
    feedbackMessage: feedbackMessage ?? this.feedbackMessage,
  );
}

/// Copy for the daily-quest chest opening (audit row 17).
class ChestRewardCopy {
  const ChestRewardCopy({
    this.amountPrefix = '+',
    this.earnedPrefix = 'You earned ',
    this.earnedSuffix = ' gems!',
    this.continueAction = 'CONTINUE',
  });
  final String amountPrefix, earnedPrefix, earnedSuffix, continueAction;
  String amount(int gems) => '$amountPrefix$gems';
  String earned(int gems) => '$earnedPrefix$gems$earnedSuffix';
}
