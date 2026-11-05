import 'dart:ui';

import '../../../core/design/reference_art.dart';

enum AchievementProgressKind { archivedFixture, currentXp }

enum AchievementClaimResult { claimed, alreadyClaimed, locked, notFound }

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.art,
    required this.progress,
    required this.goal,
    this.kind = AchievementProgressKind.archivedFixture,
    this.earnedOn,
    this.detailArt,
    this.description,
    this.claimAvailable = false,
  });

  final String id;
  final String title;
  final ArtRegion art;
  final int progress;
  final int goal;
  final AchievementProgressKind kind;
  final String? earnedOn;
  final ArtRegion? detailArt;
  final String? description;
  final bool claimAvailable;

  int progressFor(int currentXp) => kind == AchievementProgressKind.currentXp
      ? currentXp.clamp(0, goal)
      : progress;

  bool isEarned(int currentXp) => progressFor(currentXp) >= goal;
}

class AchievementState {
  const AchievementState({
    this.achievements = const <AchievementDefinition>[],
    this.claimedIds = const <String>{},
  });

  final List<AchievementDefinition> achievements;
  final Set<String> claimedIds;

  AchievementState copyWith({Set<String>? claimedIds}) => AchievementState(
    achievements: achievements,
    claimedIds: Set<String>.unmodifiable(claimedIds ?? this.claimedIds),
  );
}

class MonthlyBadge {
  const MonthlyBadge({
    required this.year,
    required this.month,
    required this.art,
    required this.earned,
  });

  final int year;
  final String month;
  final ArtRegion art;
  final bool earned;
}

/// Month labels and reference art for monthly badges.
///
/// The bundled sheets only contain 2025 and 2024 frames. Later years (for
/// example 2026) reuse the 2025 sheet and earlier years reuse the 2024 history
/// sheet, so new seasons render with existing art instead of a new asset.
abstract final class MonthlyBadgeCatalog {
  static const months = <String>[
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

  /// One-based month number to its English label.
  static String monthName(int month) => months[month - 1];

  /// Art for [year] [month] (one-based), inset like the mock fixtures.
  static ArtRegion artFor(int year, int month) {
    final frames = year >= 2025 ? _frames2025 : _frames2024;
    final frame = frames[month - 1];
    return ArtRegion(
      year >= 2025 ? 'achievement-monthly-2025' : 'achievement-monthly-history',
      Rect.fromLTWH(frame[0] - 4, frame[1] - 4, frame[2] + 8, frame[3] + 8),
    );
  }

  static const _frames2025 = <List<double>>[
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
    [465, 1673, 250, 302],
    [815, 1689, 272, 286],
  ];
  static const _frames2024 = <List<double>>[
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

abstract final class AchievementArt {
  static const longestStreak = ArtRegion(
    'achievement-awards-top',
    Rect.fromLTWH(138, 562, 250, 235),
  );
  static const mostXp = ArtRegion(
    'achievement-awards-top',
    Rect.fromLTWH(581, 564, 290, 232),
  );
  static const perfectLessons = ArtRegion(
    'achievement-awards-top',
    Rect.fromLTWH(1049, 577, 130, 222),
  );
  static const perfectWeek = ArtRegion(
    'achievement-perfect-week-detail',
    Rect.fromLTWH(236, 635, 710, 779),
  );
  static const mistakeMechanic = ArtRegion(
    'achievement-awards-top',
    Rect.fromLTWH(435, 1297, 288, 335),
  );
  static const earlyRiser = ArtRegion(
    'achievement-awards-top',
    Rect.fromLTWH(821, 1284, 301, 348),
  );
  static const sleepwalker = ArtRegion(
    'achievement-awards-top',
    Rect.fromLTWH(75, 1896, 262, 348),
  );
  static const questExplorer = ArtRegion(
    'achievement-awards-top',
    Rect.fromLTWH(435, 1923, 288, 321),
  );
  static const cheerleader = ArtRegion(
    'achievement-awards-top',
    Rect.fromLTWH(831, 1897, 291, 347),
  );
  static const xpOlympian = ArtRegion(
    'achievement-awards-bottom',
    Rect.fromLTWH(75, 653, 262, 346),
  );
  static const legend = ArtRegion(
    'achievement-awards-bottom',
    Rect.fromLTWH(435, 651, 288, 348),
  );
  static const flawlessFinisher = ArtRegion(
    'achievement-awards-bottom',
    Rect.fromLTWH(846, 650, 284, 349),
  );
  static const speedRacer = ArtRegion(
    'achievement-awards-bottom',
    Rect.fromLTWH(75, 1276, 278, 335),
  );
  static const socialButterfly = ArtRegion(
    'achievement-awards-bottom',
    Rect.fromLTWH(448, 1267, 298, 313),
  );
  static const leagueMvp = ArtRegion(
    'achievement-awards-bottom',
    Rect.fromLTWH(830, 1276, 286, 304),
  );
  static const rarestDiamond = ArtRegion(
    'achievement-awards-bottom',
    Rect.fromLTWH(72, 1894, 261, 298),
  );
  static const xpDetail = ArtRegion(
    'achievement-xp-detail',
    Rect.fromLTWH(293, 631, 600, 789),
  );
  static const perfectWeekDetail = ArtRegion(
    'achievement-perfect-week-detail',
    Rect.fromLTWH(236, 635, 710, 779),
  );
}
