import '../../../core/api/client/api_endpoints.g.dart';
import '../domain/league_result.dart';
import '../domain/year_review.dart';

abstract interface class YearReviewRepository {
  Future<YearReviewSnapshot> load();
}

class MockYearReviewRepository implements YearReviewRepository {
  const MockYearReviewRepository();

  @override
  Future<YearReviewSnapshot> load() async => historical2025;
}

/// Server-authoritative Year in Review over `GET /v1/me/year-review/{year}`.
///
/// The contract omits the derived percentile, league-week and English-score
/// fields the presentation needs, so those stay unavailable rather than inventing
/// values the server did not return.
class ApiYearReviewRepository implements YearReviewRepository {
  ApiYearReviewRepository(this.api, {required this.year});

  final ApiEndpoints api;
  final int year;

  @override
  Future<YearReviewSnapshot> load() async {
    final review = await api.getYearReview('$year');
    final tier = review.topLeagueTier;
    return YearReviewSnapshot(
      year: review.year,
      course: _courseLabel(review.courseIds),
      lessons: review.lessonsCompleted,
      totalXp: review.totalXp,
      percentile: null,
      studentTopPercent: null,
      league: tier == null
          ? ''
          : LeagueTier
                .values[tier.clamp(0, LeagueTier.values.length - 1)]
                .label,
      leagueWeeks: null,
      englishScore: null,
      longestStreak: review.longestStreak,
      minutesSpent: review.minutesSpent,
      asOf:
          DateTime.tryParse(review.generatedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static String _courseLabel(List<String> courseIds) {
    final id = courseIds.firstOrNull;
    return switch (id) {
      null => '',
      'vi_en' => 'English',
      _ => id,
    };
  }
}
