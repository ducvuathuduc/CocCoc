import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/idempotency.dart';

/// One course row as the courses screen shows it.
///
/// [id] is the screen/flag vocabulary (`english`, `chinese`, ...); [courseId]
/// is the OpenAPI course id (`vi_en`, ...). [revision] is the enrollment
/// revision the server commands must carry, and [active] marks the course the
/// app currently studies (the last switched course, else the resolved
/// active course).
class ManagedCourseRecord {
  const ManagedCourseRecord({
    required this.id,
    required this.name,
    required this.courseId,
    required this.revision,
    this.active = false,
  });

  final String id;
  final String name;
  final String courseId;
  final int revision;
  final bool active;
}

/// Course enrollment reads/commands behind the courses screen (P4-LEARN-003).
abstract interface class CourseManagementRepository {
  /// True when the repository talks to the Learning service. Mock and guest
  /// mode keep the local fixtures and never issue server commands.
  bool get isRemote;

  Future<List<ManagedCourseRecord>> loadCourses();

  Future<void> switchCourse(ManagedCourseRecord course);

  Future<void> resetCourse(ManagedCourseRecord course);

  Future<void> removeCourse(ManagedCourseRecord course);
}

/// Guest/mock data layer: the controller keeps its local fixture list and
/// never calls these commands.
class MockCourseManagementRepository implements CourseManagementRepository {
  const MockCourseManagementRepository();

  @override
  bool get isRemote => false;

  @override
  Future<List<ManagedCourseRecord>> loadCourses() async =>
      const <ManagedCourseRecord>[];

  @override
  Future<void> removeCourse(ManagedCourseRecord course) =>
      throw UnsupportedError('Mock courses are removed locally.');

  @override
  Future<void> resetCourse(ManagedCourseRecord course) =>
      throw UnsupportedError('Mock courses are reset locally.');

  @override
  Future<void> switchCourse(ManagedCourseRecord course) =>
      throw UnsupportedError('Mock courses are switched locally.');
}

/// [CourseManagementRepository] over the Learning enrollment operations.
///
/// * Enrolled courses are the catalog courses whose `GET .../path` resolves;
///   the path carries the enrollment revision used by switch/reset.
/// * The active course is the last successful switch, else the course the
///   learning path resolves, else the first enrolled course.
class ApiCourseManagementRepository implements CourseManagementRepository {
  ApiCourseManagementRepository(this.api, this.activeCourse, {IdGenerator? ids})
    : _ids = ids ?? UuidV4Generator();

  final ApiEndpoints api;
  final ActiveCourse activeCourse;
  final IdGenerator _ids;
  String? _activeCourseId;

  @override
  bool get isRemote => true;

  @override
  Future<List<ManagedCourseRecord>> loadCourses() async {
    final catalog = <wire.Course>[];
    String? cursor;
    do {
      final page = await api.listCourses(cursor: cursor, limit: 100);
      catalog.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null && catalog.length < 200);

    final enrolled = <wire.Course>[];
    final revisions = <String, int>{};
    for (final course in catalog) {
      if (!course.available) continue;
      try {
        final path = await api.getPath(course.courseId, limit: 1);
        enrolled.add(course);
        revisions[course.courseId] = path.enrollment.revision;
      } on ApiException catch (error) {
        // A 404 on the path means the account is not enrolled in that course.
        if (!error.isNotFound) rethrow;
      }
    }

    final activeId = await _resolveActive(enrolled.map((c) => c.courseId));
    return List.unmodifiable([
      for (final course in enrolled)
        ManagedCourseRecord(
          id: _screenId(course),
          name: course.title,
          courseId: course.courseId,
          revision: revisions[course.courseId] ?? 0,
          active: course.courseId == activeId,
        ),
    ]);
  }

  Future<String?> _resolveActive(Iterable<String> enrolled) async {
    final ids = enrolled.toList(growable: false);
    if (ids.isEmpty) return null;
    final tracked = _activeCourseId;
    if (tracked != null && ids.contains(tracked)) return tracked;
    try {
      final resolved = await activeCourse.id();
      if (ids.contains(resolved)) return resolved;
    } on ApiException {
      // No available course: fall back to the first enrolled course.
    }
    return ids.first;
  }

  static String _screenId(wire.Course course) {
    final locale = course.targetLocale.toLowerCase();
    if (locale.startsWith('en')) return 'english';
    if (locale.startsWith('zh')) return 'chinese';
    if (locale.startsWith('id')) return 'indonesian';
    if (locale.startsWith('it')) return 'italian';
    return course.courseId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  @override
  Future<void> switchCourse(ManagedCourseRecord course) async {
    await api.switchCourse(
      course.courseId,
      wire.EnrollmentCommandRequest(expectedRevision: course.revision),
      idempotencyKey: _ids.next(),
    );
    _activeCourseId = course.courseId;
  }

  @override
  Future<void> resetCourse(ManagedCourseRecord course) async {
    await api.resetCourse(
      course.courseId,
      wire.EnrollmentCommandRequest(expectedRevision: course.revision),
      idempotencyKey: _ids.next(),
    );
  }

  @override
  Future<void> removeCourse(ManagedCourseRecord course) async {
    await api.removeCourse(course.courseId, idempotencyKey: _ids.next());
    if (_activeCourseId == course.courseId) _activeCourseId = null;
  }
}
