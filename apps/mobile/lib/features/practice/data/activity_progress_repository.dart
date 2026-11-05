import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';

/// Library progress for one story/adventure/radio/side-quest activity.
class ActivityProgressEntry {
  const ActivityProgressEntry({
    required this.kind,
    required this.activityId,
    required this.completions,
    required this.bestScore,
    required this.stars,
    this.firstCompletedAt,
    this.lastCompletedAt,
  });

  final String kind;
  final String activityId;
  final int completions;
  final int bestScore;
  final int stars;
  final String? firstCompletedAt;
  final String? lastCompletedAt;

  bool get completed => completions > 0;
}

/// Library progress reads (`GET /v1/activities`) for the practice library.
abstract interface class ActivityProgressRepository {
  bool get isRemote;

  Future<List<ActivityProgressEntry>> load({String? kind});
}

/// Mock mode has no server activity ledger; it reports no invented progress.
class MockActivityProgressRepository implements ActivityProgressRepository {
  const MockActivityProgressRepository();

  @override
  bool get isRemote => false;

  @override
  Future<List<ActivityProgressEntry>> load({String? kind}) async =>
      const <ActivityProgressEntry>[];
}

class ApiActivityProgressRepository implements ActivityProgressRepository {
  ApiActivityProgressRepository(this.api, this.course);

  final ApiEndpoints api;
  final ActiveCourse course;

  static const _maxEntries = 500;

  @override
  bool get isRemote => true;

  @override
  Future<List<ActivityProgressEntry>> load({String? kind}) async {
    final courseId = await course.id();
    final entries = <ActivityProgressEntry>[];
    String? cursor;
    do {
      final page = await api.listActivityProgress(
        courseId: courseId,
        kind: kind,
        cursor: cursor,
        limit: 100,
      );
      entries.addAll([
        for (final item in page.items)
          ActivityProgressEntry(
            kind: item.kind,
            activityId: item.activityId,
            completions: item.completions,
            bestScore: item.bestScore,
            stars: item.stars,
            firstCompletedAt: item.firstCompletedAt,
            lastCompletedAt: item.lastCompletedAt,
          ),
      ]);
      cursor = page.nextCursor;
    } while (cursor != null && entries.length < _maxEntries);
    return List.unmodifiable(entries);
  }
}
