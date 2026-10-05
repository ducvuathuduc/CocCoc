import 'dart:ui';

import '../../../core/design/reference_art.dart';
import '../domain/achievement_models.dart';

abstract interface class AchievementsRepository {
  List<AchievementDefinition> loadAchievements();
  List<MonthlyBadge> loadMonthlyBadges();
}

class MockAchievementsRepository implements AchievementsRepository {
  @override
  List<AchievementDefinition> loadAchievements() => const [
    AchievementDefinition(
      id: 'perfect-week',
      title: 'Perfect Week',
      art: AchievementArt.perfectWeek,
      detailArt: AchievementArt.perfectWeekDetail,
      progress: 30,
      goal: 30,
      earnedOn: 'DEC 6, 2025',
      description: 'You earned the Perfect Week achievement by completing 30 perfect weeks!',
      claimAvailable: true,
    ),
    AchievementDefinition(
      id: 'mistake-mechanic',
      title: 'Mistake Mechanic',
      art: AchievementArt.mistakeMechanic,
      progress: 9,
      goal: 10,
    ),
    AchievementDefinition(
      id: 'early-riser',
      title: 'Early Riser',
      art: AchievementArt.earlyRiser,
      progress: 10,
      goal: 10,
      earnedOn: 'ARCHIVED FIXTURE',
    ),
    AchievementDefinition(
      id: 'sleepwalker',
      title: 'Sleepwalker',
      art: AchievementArt.sleepwalker,
      progress: 10,
      goal: 10,
      earnedOn: 'ARCHIVED FIXTURE',
    ),
    AchievementDefinition(
      id: 'quest-explorer',
      title: 'Quest Explorer',
      art: AchievementArt.questExplorer,
      progress: 9,
      goal: 10,
    ),
    AchievementDefinition(
      id: 'cheerleader',
      title: 'Cheerleader',
      art: AchievementArt.cheerleader,
      progress: 5,
      goal: 5,
      earnedOn: 'ARCHIVED FIXTURE',
    ),
    AchievementDefinition(
      id: 'xp-olympian',
      title: 'XP Olympian',
      art: AchievementArt.xpOlympian,
      detailArt: AchievementArt.xpDetail,
      progress: 0,
      goal: 100,
      kind: AchievementProgressKind.currentXp,
      description: 'Reach 100 XP to unlock this achievement.',
    ),
    AchievementDefinition(
      id: 'legend',
      title: 'Legend',
      art: AchievementArt.legend,
      progress: 7,
      goal: 10,
    ),
    AchievementDefinition(
      id: 'flawless-finisher',
      title: 'Flawless Finisher',
      art: AchievementArt.flawlessFinisher,
      progress: 5,
      goal: 5,
      earnedOn: 'ARCHIVED FIXTURE',
    ),
    AchievementDefinition(
      id: 'speed-racer',
      title: 'Speed Racer',
      art: AchievementArt.speedRacer,
      progress: 4,
      goal: 5,
    ),
    AchievementDefinition(
      id: 'social-butterfly',
      title: 'Social Butterfly',
      art: AchievementArt.socialButterfly,
      progress: 1,
      goal: 1,
      earnedOn: 'ARCHIVED FIXTURE',
    ),
    AchievementDefinition(
      id: 'league-mvp',
      title: 'League MVP',
      art: AchievementArt.leagueMvp,
      progress: 1,
      goal: 1,
      earnedOn: 'ARCHIVED FIXTURE',
    ),
    AchievementDefinition(
      id: 'rarest-diamond',
      title: 'Rarest Diamond',
      art: AchievementArt.rarestDiamond,
      progress: 1,
      goal: 1,
      earnedOn: 'ARCHIVED FIXTURE',
    ),
  ];

  @override
  List<MonthlyBadge> loadMonthlyBadges() => List.unmodifiable([
    ..._year(2025, 'achievement-monthly-2025', 403, const {
      'January',
      'May',
      'June',
      'October',
    }),
    ..._year(2024, 'achievement-monthly-history', 145, const {
      'January',
      'February',
      'July',
      'December',
    }),
    ..._visible2023(),
  ]);

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static List<MonthlyBadge> _year(
    int year,
    String file,
    double firstY,
    Set<String> earned,
  ) => [
    for (var index = 0; index < 12; index++)
      MonthlyBadge(
        year: year,
        month: _months[index],
        art: ArtRegion(
          file,
          Rect.fromLTWH(
            (year == 2025 ? _monthly2025 : _monthly2024)[index][0] - 4,
            (year == 2025 ? _monthly2025 : _monthly2024)[index][1] - 4,
            (year == 2025 ? _monthly2025 : _monthly2024)[index][2] + 8,
            (year == 2025 ? _monthly2025 : _monthly2024)[index][3] + 8,
          ),
        ),
        earned: earned.contains(_months[index]),
      ),
  ];

  static List<MonthlyBadge> _visible2023() => [
    for (var index = 0; index < 3; index++)
      MonthlyBadge(
        year: 2023,
        month: _months[index],
        art: ArtRegion(
          'achievement-monthly-history',
          Rect.fromLTWH(const [96.0, 457.0, 818.0][index], 2273, 265, 283),
        ),
        earned: false,
      ),
  ];

  static const _monthly2025 = <List<double>>[
    [104, 541, 250, 263],
    [465, 542, 255, 263],
    [795, 530, 287, 275],
    [104, 898, 250, 297],
    [465, 905, 250, 290],
    [813, 911, 263, 284],
    [66, 1302, 288, 283],
    [460, 1321, 260, 264],
    [826, 1322, 250, 263],
    [95, 1694, 259, 281],
    [465, 1619, 250, 356],
    [815, 1689, 272, 286],
  ];
  static const _monthly2024 = <List<double>>[
    [94, 513, 270, 270],
    [463, 518, 252, 264],
    [824, 519, 252, 264],
    [100, 905, 256, 268],
    [461, 905, 256, 268],
    [822, 904, 256, 268],
    [99, 1293, 257, 270],
    [460, 1293, 257, 269],
    [821, 1293, 257, 269],
    [101, 1684, 254, 268],
    [460, 1683, 259, 270],
    [824, 1687, 250, 265],
  ];
}
