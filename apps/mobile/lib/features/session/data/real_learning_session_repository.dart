import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/idempotency.dart';
import '../../../core/api/client/active_course.dart';
import '../../../core/cache/lesson_journal.dart';

class PreparedLearningSession {
  const PreparedLearningSession({
    required this.profile,
    required this.paths,
    required this.rewards,
    this.hasSavedPlacement = false,
  });
  final wire.Profile profile;
  final List<wire.Path> paths;
  final wire.Rewards rewards;
  final bool hasSavedPlacement;
  bool get needsEnrollment => paths.isEmpty;
}

/// Prepares only missing server resources. Existing nickname, timezone and
/// enrollment are preserved. A failed service never falls back to fixtures.
class RealLearningSessionRepository {
  RealLearningSessionRepository(
    this.api,
    this.course, {
    IdGenerator? ids,
    this.journal,
  }) : ids = ids ?? UuidV4Generator();
  final ApiEndpoints api;
  final ActiveCourse course;
  final IdGenerator ids;
  final LessonJournal? journal;
  String? _profileKey, _enrollKey;

  Future<PreparedLearningSession> prepare(String userId, String name) async {
    wire.Profile profile;
    var created = false;
    try {
      profile = await api.getMe();
    } on ApiException catch (error) {
      if (!error.isNotFound) rethrow;
      profile = await api.initializeProfile(
        idempotencyKey: _profileKey ??= ids.next(),
      );
      created = true;
    }
    if (profile.userId != userId) {
      throw const ApiException(
        code: 'BAD_RESPONSE',
        message: 'Profile identity mismatch',
      );
    }
    if (created && name.trim().isNotEmpty) {
      final nickname = name.trim();
      profile = await api.updateMe(
        wire.ProfilePatch(
          nickname: nickname.length > 40 ? nickname.substring(0, 40) : nickname,
          expectedRevision: profile.revision,
        ),
      );
    }
    final courseId = await course.id();
    List<wire.Path> paths;
    try {
      paths = await readPathPages(api, courseId);
    } on ApiException catch (error) {
      if (!error.isNotFound) rethrow;
      paths = const [];
    }
    final rewards = await api.getRewards();
    final saved = await journal?.active();
    return PreparedLearningSession(
      profile: profile,
      paths: paths,
      rewards: rewards,
      hasSavedPlacement:
          saved?.nodeId == 'placement' && saved?.courseId == courseId,
    );
  }

  Future<void> enrollBeginner() async {
    await api.enrollCourse(
      wire.EnrollRequest(courseId: await course.id(), startPoint: 'beginner'),
      idempotencyKey: _enrollKey ??= ids.next(),
    );
  }
}

Future<List<wire.Path>> readPathPages(ApiEndpoints api, String courseId) async {
  final pages = <wire.Path>[];
  final cursors = <String>{};
  String? cursor;
  do {
    final page = await api.getPath(courseId, cursor: cursor, limit: 100);
    if (page.enrollment.courseId != courseId) {
      throw const ApiException(
        code: 'BAD_RESPONSE',
        message: 'Course identity mismatch',
      );
    }
    pages.add(page);
    cursor = page.nextCursor;
    if (cursor != null && (!cursors.add(cursor) || pages.length >= 20)) {
      throw const ApiException(
        code: 'BAD_RESPONSE',
        message: 'Invalid path pagination',
      );
    }
  } while (cursor != null);
  if (pages.expand((p) => p.nodes).isEmpty) {
    throw const ApiException(
      code: 'NO_COURSE',
      message: 'No published lessons',
      statusCode: 404,
    );
  }
  return pages;
}
