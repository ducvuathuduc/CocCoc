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
