class YearReviewSnapshot {
  const YearReviewSnapshot({
    required this.year,
    required this.course,
    required this.lessons,
    required this.totalXp,
    required this.percentile,
    required this.studentTopPercent,
    required this.league,
    required this.leagueWeeks,
    required this.englishScore,
    required this.longestStreak,
    required this.minutesSpent,
    required this.asOf,
  });

  final int year;
  final String course;
  final int lessons;
  final int totalXp;
  final int percentile;
  final int studentTopPercent;
  final String league;
  final int leagueWeeks;
  final int englishScore;
  final int longestStreak;
  final int minutesSpent;
  final DateTime asOf;
}

final historical2025 = YearReviewSnapshot(
  year: 2025,
  course: 'English',
  lessons: 400,
  totalXp: 12949,
  percentile: 93,
  studentTopPercent: 8,
  league: 'Pearl',
  leagueWeeks: 2,
  englishScore: 19,
  longestStreak: 837,
  minutesSpent: 1374,
  asOf: DateTime(2025, 11, 30),
);
