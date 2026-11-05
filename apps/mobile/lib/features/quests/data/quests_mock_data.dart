import '../domain/quest_models.dart';

abstract final class QuestsMockData {
  static const defaultMonthlyChallenge = MonthlyChallenge(
    title: 'December Quest',
    daysRemaining: '15 DAYS',
    currentPoints: 15,
    targetPoints: 15,
    badgeName: 'December Badge',
  );

  static const decemberMonthlyChallenge = MonthlyChallenge(
    title: 'December Quest',
    daysRemaining: '15 DAYS',
    currentPoints: 15,
    targetPoints: 15,
    badgeName: 'December Badge',
  );

  static const weekendMonthlyChallenge = MonthlyChallenge(
    title: 'December Quest',
    daysRemaining: '19 DAYS',
    currentPoints: 11,
    targetPoints: 30,
    badgeName: 'December Badge',
  );

  static const inProgressFriendsQuest = FriendsQuest(
    title: 'Complete 25 lessons',
    timeRemaining: '2D',
    target: 25,
    userLessons: 14,
    friendLessons: 2,
    friendName: 'Alex',
    isNudged: false,
    isGifted: false,
    isHighFived: false,
    isOptedIn: true,
  );

  static const completedFriendsQuest = FriendsQuest(
    title: 'Complete 25 lessons',
    timeRemaining: '2D',
    target: 25,
    userLessons: 23,
    friendLessons: 2,
    friendName: 'Alex',
    isNudged: false,
    isGifted: false,
    isHighFived: true,
    isOptedIn: true,
  );

  static const defaultWeekendQuest = WeekendQuest(
    title: 'Earn 100 XP',
    timeRemaining: '2D',
    currentXp: 8,
    targetXp: 100,
  );

  static const defaultDailyQuests = [
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
  ];
}
