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
    this.title = 'December Quest',
    this.daysRemaining = '15 DAYS',
    this.currentPoints = 15,
    this.targetPoints = 15,
    this.badgeName = 'December Badge',
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

  const FriendsQuest({
    this.title = 'Complete 25 lessons',
    this.timeRemaining = '2D',
    this.target = 25,
    this.userLessons = 14,
    this.friendLessons = 2,
    this.friendName = 'Alex',
    this.isNudged = false,
    this.isGifted = false,
    this.isHighFived = false,
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
  );
}

class WeekendQuest {
  final String title;
  final String timeRemaining;
  final int currentXp;
  final int targetXp;

  const WeekendQuest({
    this.title = 'Earn 100 XP',
    this.timeRemaining = '2D',
    this.currentXp = 8,
    this.targetXp = 100,
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
    this.monthlyChallenge = const MonthlyChallenge(),
    this.friendsQuest = const FriendsQuest(),
    this.weekendQuest = const WeekendQuest(),
    this.dailyQuests = const [
      DailyQuest(
        id: 'daily-2',
        title: 'Complete your next 2 lessons',
        current: 0,
        target: 2,
        chestType: QuestChestType.bronze,
      ),
      DailyQuest(
        id: 'daily-score',
        title: 'Score 90% in 1 lesson',
        current: 1,
        target: 1,
        chestType: QuestChestType.silver,
      ),
      DailyQuest(
        id: 'daily-xp',
        title: 'Get 10 in a row in 2 lessons',
        current: 0,
        target: 2,
        chestType: QuestChestType.gold,
      ),
    ],
    this.dailyTimeRemaining = '5H',
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
