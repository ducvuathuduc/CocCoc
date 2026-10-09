// Profile tab mock data (study clone, local fixtures only).
//
// Ground truth: docs/design/references/profile/04.png (new user),
// 05.png (lower sections, empty), 06-08.png (rich user).
// Values are authored English-learning fixtures, not archived identity.

import 'package:flutter/material.dart';

/// One friend-streak cell.
class FriendStreakMock {
  const FriendStreakMock({
    required this.name,
    required this.color,
    required this.days,
    this.active = false,
  });

  final String name;
  final Color color;
  final int days;
  final bool active;
}

/// One monthly badge cell.
class MonthlyBadgeMock {
  const MonthlyBadgeMock({
    required this.label,
    required this.color,
    required this.icon,
    this.earned = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool earned;
}

/// One achievement cell.
class AchievementMock {
  const AchievementMock({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    this.earned = false,
    this.isNew = false,
  });

  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final bool earned;
  final bool isNew;
}

/// One Max Family member silhouette/cell.
class FamilyMemberMock {
  const FamilyMemberMock({required this.name, required this.color});

  final String name;
  final Color color;
}

/// Full profile tab fixture.
class ProfileMock {
  const ProfileMock({
    required this.displayName,
    required this.handle,
    required this.joinedYear,
    required this.heroColor,
    required this.hasAvatar,
    required this.avatarInitial,
    required this.avatarColor,
    required this.following,
    required this.followers,
    required this.extraCourses,
    required this.streakLabel,
    required this.xpLabel,
    required this.leagueLabel,
    required this.leagueActive,
    required this.topFinishesLabel,
    required this.topFinishesActive,
    required this.showFinishCard,
    required this.friendStreaks,
    required this.monthlyBadges,
    required this.achievements,
    this.showMaxBadge = false,
    this.showFamily = false,
    this.familyMembers = const [],
  });

  final String displayName;
  final String handle;
  final int joinedYear;
  final Color heroColor;
  final bool hasAvatar;
  final String avatarInitial;
  final Color avatarColor;
  final int following;
  final int followers;
  final int extraCourses;
  final String streakLabel;
  final String xpLabel;
  final String leagueLabel;
  final bool leagueActive;
  final String topFinishesLabel;
  final bool topFinishesActive;
  final bool showFinishCard;
  final List<FriendStreakMock> friendStreaks;
  final List<MonthlyBadgeMock> monthlyBadges;
  final List<AchievementMock> achievements;
  final bool showMaxBadge;
  final bool showFamily;
  final List<FamilyMemberMock> familyMembers;

  String get identity => '@$handle · JOINED $joinedYear';
}

/// New-user fixture: refs 04.png / 05.png.
const profileMockNew = ProfileMock(
  displayName: 'Sam Lee',
  handle: 'SAMLEE782112',
  joinedYear: 2025,
  heroColor: Color(0xFFE1F4FF),
  hasAvatar: false,
  avatarInitial: 'S',
  avatarColor: Color(0xFF1CB0F6),
  following: 2,
  followers: 0,
  extraCourses: 0,
  streakLabel: '1 day',
  xpLabel: '24 XP',
  leagueLabel: 'No current',
  leagueActive: false,
  topFinishesLabel: '0 top finishes',
  topFinishesActive: false,
  showFinishCard: true,
  friendStreaks: [],
  monthlyBadges: [
    MonthlyBadgeMock(
      label: 'October 2025, earned',
      color: Color(0xFF1CB0F6),
      icon: Icons.mic_rounded,
      earned: true,
    ),
    MonthlyBadgeMock(label: 'November 2025, locked', color: Color(0xFFE5E5E5), icon: Icons.lock_rounded),
    MonthlyBadgeMock(label: 'December 2025, locked', color: Color(0xFFE5E5E5), icon: Icons.lock_rounded),
    MonthlyBadgeMock(label: 'January 2026, locked', color: Color(0xFFE5E5E5), icon: Icons.lock_rounded),
  ],
  achievements: [
    AchievementMock(title: 'Comeback, locked', count: 100, color: Color(0xFFFFC800), icon: Icons.sports_mma_rounded),
    AchievementMock(title: 'Painter, locked', count: 10, color: Color(0xFFFF9600), icon: Icons.brush_rounded),
    AchievementMock(title: 'Early bird, locked', count: 1, color: Color(0xFF1CB0F6), icon: Icons.wb_sunny_rounded),
    AchievementMock(title: 'Chatterbox, locked', count: 5, color: Color(0xFFCE82AF), icon: Icons.chat_bubble_rounded),
  ],
);

/// Rich-user fixture: refs 06.png / 07.png / 08.png.
const profileMockRich = ProfileMock(
  displayName: 'Sam Lee',
  handle: 'SLMOBBIN',
  joinedYear: 2025,
  heroColor: Color(0xFFFFDFDF),
  hasAvatar: true,
  avatarInitial: 'S',
  avatarColor: Color(0xFFCE82AF),
  following: 13,
  followers: 36,
  extraCourses: 7,
  streakLabel: '847 days',
  xpLabel: '55474 XP',
  leagueLabel: 'Sapphire',
  leagueActive: true,
  topFinishesLabel: '10 top finishes',
  topFinishesActive: true,
  showFinishCard: false,
  showMaxBadge: true,
  showFamily: true,
  familyMembers: [
    FamilyMemberMock(name: 'Mia', color: Color(0xFFFF86C2)),
  ],
  friendStreaks: [
    FriendStreakMock(name: 'Alex', color: Color(0xFFCE82AF), days: 342, active: true),
    FriendStreakMock(name: 'Maria', color: Color(0xFF1CB0F6), days: 458),
    FriendStreakMock(name: 'Lucas', color: Color(0xFF58CC02), days: 106),
    FriendStreakMock(name: 'Anna', color: Color(0xFFB0AEB0), days: 38),
  ],
  monthlyBadges: [
    MonthlyBadgeMock(label: 'September 2025, earned', color: Color(0xFF00C2A8), icon: Icons.campaign_rounded, earned: true),
    MonthlyBadgeMock(label: 'October 2025, earned', color: Color(0xFFFF86C2), icon: Icons.fastfood_rounded, earned: true),
    MonthlyBadgeMock(label: 'November 2025, earned', color: Color(0xFF9861FF), icon: Icons.sports_esports_rounded, earned: true),
    MonthlyBadgeMock(label: 'December 2025, earned', color: Color(0xFF4D4B4E), icon: Icons.mic_rounded, earned: true),
  ],
  achievements: [
    AchievementMock(title: 'Comeback, earned', count: 30, color: Color(0xFFFFC800), icon: Icons.sports_mma_rounded, earned: true, isNew: true),
    AchievementMock(title: 'Painter, earned', count: 750, color: Color(0xFFFF9600), icon: Icons.brush_rounded, earned: true),
    AchievementMock(title: 'Early bird, earned', count: 200, color: Color(0xFF1CB0F6), icon: Icons.wb_sunny_rounded, earned: true),
    AchievementMock(title: 'Chatterbox, earned', count: 200, color: Color(0xFFCE82AF), icon: Icons.chat_bubble_rounded, earned: true),
  ],
);

/// Local share URL for a profile id (mock only, never networked).
String profileShareUrl(String userId) => 'https://cocenglish.test/profile/$userId';
