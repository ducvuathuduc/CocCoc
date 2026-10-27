import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/features/account/application/course_management_controller.dart';
import 'package:cocenglish/features/account/data/course_management_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_transport.dart';

Map<String, Object?> course(String id, {bool available = true}) => {
  'courseId': id,
  'title': id == 'vi_en' ? 'English for Vietnamese learners' : 'Chinese',
  'sourceLocale': 'vi',
  'targetLocale': id == 'vi_en' ? 'en' : 'zh',
  'publishedVersion': 'v1',
  'available': available,
};

Map<String, Object?> coursePage(List<Map<String, Object?>> items) => {
  'items': items,
  'nextCursor': null,
  'asOf': isoNow,
};

Map<String, Object?> path({int revision = 4}) => {
  'enrollment': {
    'courseId': 'vi_en',
    'courseVersion': 'v1',
    'frontierNodeOrder': 0,
    'completedLessonIds': <String>[],
    'masteredNodeIds': <String>[],
    'revision': revision,
  },
  'nodes': [
    {
      'nodeId': 'u1n1',
      'unitId': 'u1',
      'sectionId': 'sec1',
      'order': 0,
      'title': 'Xin chào',
      'kind': 'lesson',
      'state': 'current',
      'lessonIds': ['u1n1l1'],
    },
  ],
  'asOf': isoNow,
  'nextCursor': null,
};

Map<String, Object?> enrollment({int revision = 5}) => {
  'courseId': 'vi_en',
  'courseVersion': 'v1',
  'frontierNodeOrder': 0,
  'completedLessonIds': <String>[],
  'masteredNodeIds': <String>[],
  'revision': revision,
};

Map<String, Object?> receipt() => {
  'operationId': 'op-1',
  'status': 'accepted',
  'requestId': 'req-1',
};

ManagedCourseRecord record(
  String id,
  String name,
  String courseId, {
  int revision = 4,
  bool active = false,
}) => ManagedCourseRecord(
  id: id,
  name: name,
  courseId: courseId,
  revision: revision,
  active: active,
);

final class _FakeCourseRepository implements CourseManagementRepository {
  _FakeCourseRepository(this.records);

  List<ManagedCourseRecord> records;
  int loads = 0;
  final List<String> switches = [];
  final List<String> resets = [];
  final List<String> removals = [];
  ApiException? removeError;

  @override
  bool get isRemote => true;

  @override
  Future<List<ManagedCourseRecord>> loadCourses() async {
    loads += 1;
    return records;
  }

  @override
  Future<void> removeCourse(ManagedCourseRecord course) async {
    final failure = removeError;
    if (failure != null) throw failure;
    removals.add(course.courseId);
    records = [
      for (final item in records)
        if (item.courseId != course.courseId) item,
    ];
  }

  @override
  Future<void> resetCourse(ManagedCourseRecord course) async {
    resets.add(course.courseId);
  }

  @override
  Future<void> switchCourse(ManagedCourseRecord course) async {
    switches.add(course.courseId);
    records = [
      for (final item in records)
        ManagedCourseRecord(
          id: item.id,
          name: item.name,
          courseId: item.courseId,
          revision: item.revision,
          active: item.courseId == course.courseId,
        ),
    ];
  }
}

ProviderContainer _container(CourseManagementRepository repository) {
  final container = ProviderContainer(
    overrides: [
      courseManagementRepositoryProvider.overrideWithValue(repository),
    ],
  );
  container.listen(courseManagementProvider, (_, _) {}, fireImmediately: true);
  return container;
}

void main() {
  test('mock data layer keeps the local course fixtures', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(courseManagementRepositoryProvider).isRemote,
      isFalse,
    );
    expect(
      container.read(courseManagementProvider).courses.map((c) => c.id),
      ['english', 'chinese', 'indonesian', 'italian'],
    );
  });

  test('API mode loads enrolled courses with the server revision', () async {
    final repository = _FakeCourseRepository([
      record('english', 'English', 'vi_en', revision: 4, active: true),
      record('chinese', 'Chinese', 'zh_en', revision: 2),
    ]);
    final container = _container(repository);
    addTearDown(container.dispose);
    await pumpEventQueue();

    final courses = container.read(courseManagementProvider).courses;
    expect(repository.loads, 1);
    expect(courses.map((c) => c.id), ['english', 'chinese']);
    expect(courses.first.name, 'English');
    expect(courses.first.active, isTrue);
    expect(courses.last.active, isFalse);
  });

  test('switching a course calls the API and reloads state', () async {
    final repository = _FakeCourseRepository([
      record('english', 'English', 'vi_en', active: true),
      record('chinese', 'Chinese', 'zh_en', revision: 2),
    ]);
    final container = _container(repository);
    addTearDown(container.dispose);
    await pumpEventQueue();

    final switched = await container
        .read(courseManagementProvider.notifier)
        .switchCourse('chinese');

    expect(switched, isTrue);
    expect(repository.switches, ['zh_en']);
    expect(repository.loads, 2);
    final courses = container.read(courseManagementProvider).courses;
    expect(courses.firstWhere((c) => c.id == 'chinese').active, isTrue);
    expect(courses.firstWhere((c) => c.id == 'english').active, isFalse);
  });

  test('resetting a course calls the API with the loaded revision', () async {
    final repository = _FakeCourseRepository([
      record('english', 'English', 'vi_en', active: true),
    ]);
    final container = _container(repository);
    addTearDown(container.dispose);
    await pumpEventQueue();

    final reset = await container
        .read(courseManagementProvider.notifier)
        .resetCourse('english');

    expect(reset, isTrue);
    expect(repository.resets, ['vi_en']);
  });

  test('API removal protects the active course and deletes others', () async {
    final repository = _FakeCourseRepository([
      record('english', 'English', 'vi_en', active: true),
      record('chinese', 'Chinese', 'zh_en', revision: 2),
    ]);
    final container = _container(repository);
    addTearDown(container.dispose);
    await pumpEventQueue();
    final controller = container.read(courseManagementProvider.notifier);

    expect(controller.requestRemoval('english'), isFalse);
    expect(
      container.read(courseManagementProvider).protectionMessage,
      'English is your active course and cannot be removed.',
    );

    expect(controller.requestRemoval('chinese'), isTrue);
    expect(await controller.confirmRemoval(), isTrue);
    expect(repository.removals, ['zh_en']);
    expect(
      container.read(courseManagementProvider).courses.map((c) => c.id),
      ['english'],
    );
    expect(
      container.read(courseManagementProvider).phase,
      CourseRemovalPhase.idle,
    );
  });

  test('a failed API removal restores idle state with a safe message', () async {
    final repository = _FakeCourseRepository([
      record('english', 'English', 'vi_en', active: true),
      record('chinese', 'Chinese', 'zh_en', revision: 2),
    ])..removeError = const ApiException(
      code: 'CONFLICT',
      message: 'internal detail',
      statusCode: 409,
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await pumpEventQueue();
    final controller = container.read(courseManagementProvider.notifier);

    controller.requestRemoval('chinese');
    expect(await controller.confirmRemoval(), isFalse);
    final state = container.read(courseManagementProvider);
    expect(state.phase, CourseRemovalPhase.idle);
    expect(state.pendingCourseId, isNull);
    expect(state.courses.map((c) => c.id), contains('chinese'));
    expect(
      state.protectionMessage,
      'That changed on another device. Please try again.',
    );
    expect(state.protectionMessage, isNot(contains('internal detail')));
  });

  test('API repository maps enrolled courses and sends revision commands', () async {
    final transport = FakeApiTransport()
      ..json(
        'GET /v1/courses',
        coursePage([course('vi_en'), course('zh_en')]),
      )
      ..json('GET /v1/courses/vi_en/path', path())
      ..json('POST /v1/enrollments/vi_en/activate', enrollment())
      ..json('POST /v1/enrollments/vi_en/reset', enrollment(revision: 6))
      ..json('DELETE /v1/enrollments/vi_en', receipt());
    final api = ApiEndpoints(fakeClient(transport));
    final repository = ApiCourseManagementRepository(
      api,
      ActiveCourse(api),
      ids: SequenceIds(),
    );

    final courses = await repository.loadCourses();
    expect(courses, hasLength(1));
    expect(courses.single.id, 'english');
    expect(courses.single.name, 'English for Vietnamese learners');
    expect(courses.single.courseId, 'vi_en');
    expect(courses.single.revision, 4);
    expect(courses.single.active, isTrue);
    expect(transport.to('GET /v1/courses/zh_en/path'), hasLength(1));

    await repository.switchCourse(courses.single);
    expect(
      bodyOf(transport.to('POST /v1/enrollments/vi_en/activate').single),
      {'expectedRevision': 4},
    );
    expect(
      transport
          .to('POST /v1/enrollments/vi_en/activate')
          .single
          .headers['Idempotency-Key'],
      isNotEmpty,
    );

    await repository.resetCourse(courses.single);
    expect(
      bodyOf(transport.to('POST /v1/enrollments/vi_en/reset').single),
      {'expectedRevision': 4},
    );

    await repository.removeCourse(courses.single);
    expect(transport.to('DELETE /v1/enrollments/vi_en'), hasLength(1));
  });
}
