class ProfileSummary {
  const ProfileSummary({
    required this.userId,
    required this.name,
    required this.username,
    required this.joinedYear,
    required this.xp,
    required this.followingCount,
    required this.streak,
    required this.league,
    required this.completedLessons,
    this.followersCount = 0,
    this.topThreeFinishes = 0,
    this.leagueWeek = 1,
  });

  final String userId;
  final String name;
  final String username;
  final int joinedYear;
  final int xp;
  final int followingCount;
  final int streak;
  final String league;
  final int completedLessons;
  final int followersCount;
  final int topThreeFinishes;
  final int leagueWeek;
}
