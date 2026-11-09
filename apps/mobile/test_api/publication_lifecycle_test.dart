// API-mode lane: what the app sees while a maintainer publishes, supersedes, rolls back and
// unpublishes a second course, whose lesson ids collide with the shipped course's. The steps share
// one backend and run in order; each ends in a state the next one expects. Run through
// `node tools/scripts/mobile-api-lane.mjs`, which starts a fresh backend per run.
import 'package:cocenglish/core/api/client/access_token.dart';
import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/features/learning/data/lesson_wire_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/lane.dart';

const _shipped = 'vi_en';
const _mini = 'vi_en_mini';
const _sharedLesson = 'u1n1l1';

Matcher _apiError(String code, int status, {bool? retryable}) =>
    isA<ApiException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.statusCode, 'statusCode', status)
        .having((e) => e.retryable, 'retryable', retryable ?? anything);

void main() {
  final lane = laneState();
  final client = laneClient(lane);
  final app = LearningApi(client);
  final admin = LaneAdmin(
    laneClient(lane, tokens: StaticTokenProvider(lane.maintainerToken)),
  );
  final v1 = lane.publication('v1');
  final v2 = lane.publication('v2');

  Future<Map<String, String>> published() async {
    final page = await app.listCourses();
    return {for (final c in page.items) c.courseId: c.publishedVersion};
  }

  tearDown(() => lane.setFaults(missingMedia: false, storageOutage: false));

  test(
    'before anything is published the app sees only the shipped course',
    () async {
      expect(await published(), {_shipped: 'v2'});
      await expectLater(
        app.getManifest(_mini),
        throwsA(_apiError('NOT_FOUND', 404)),
      );
    },
  );

  test('a learner cannot publish', () async {
    final learnerAsAdmin = LaneAdmin(client);

    await expectLater(
      learnerAsAdmin.publish(v1, expected: null),
      throwsA(_apiError('MAINTAINER_REQUIRED', 403)),
    );
    expect(await published(), {_shipped: 'v2'});
  });

  test(
    'media missing from Storage refuses the publish and changes nothing',
    () async {
      await lane.setFaults(missingMedia: true);

      await expectLater(
        admin.publish(v1, expected: null),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'VALIDATION_ERROR')
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => (e.details['problems']! as List).map(
                  (p) => (p as Map)['problem'],
                ),
                'problems',
                contains('MEDIA_MISSING'),
              ),
        ),
      );

      expect(await published(), {_shipped: 'v2'});
    },
  );

  test(
    'a Storage outage while publishing is a retryable 503, never a success',
    () async {
      await lane.setFaults(storageOutage: true);

      await expectLater(
        admin.publish(v1, expected: null),
        throwsA(_apiError('STORAGE_UNAVAILABLE', 503, retryable: true)),
      );

      expect(await published(), {_shipped: 'v2'});
    },
  );

  test('once the media is back the same version publishes, and the lesson ids collide', () async {
    final receipt = await admin.publish(v1, expected: null);
    expect(receipt['status'], 'accepted');

    expect(await published(), {_shipped: 'v2', _mini: 'v1'});
    // The app still studies the first course in the catalog.
    expect(await ActiveCourse(ApiEndpoints(client)).id(), _shipped);

    // The course-less read cannot say which course owns u1n1l1, so it refuses to guess.
    await expectLater(
      app.getBundle(_sharedLesson),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'LESSON_AMBIGUOUS')
            .having((e) => e.isConflict, 'isConflict', isTrue)
            .having(
              (e) => (e.details['courseIds']! as List).toSet(),
              'courseIds',
              {_shipped, _mini},
            ),
      ),
    );

    // The course-scoped read is exact, and both bundles parse and map.
    final big = await app.getCourseBundle(_shipped, _sharedLesson);
    final small = await app.getCourseBundle(_mini, _sharedLesson);
    expect(big.courseId, _shipped);
    expect(small.courseId, _mini);
    expect(small.manifestHash, isNot(big.manifestHash));
    for (final bundle in [big, small]) {
      expect(
        LessonWireMapper(bundle.exercises, assets: bundle.assets).toDomain(),
        hasLength(bundle.exercises.length),
      );
    }
  });

  test('a newer version supersedes the old one; the old one stays readable by version', () async {
    // The publish pointer is a compare-and-set: a stale view is refused.
    await expectLater(
      admin.publish(v2, expected: null),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'REVISION_CONFLICT')
            .having((e) => e.isConflict, 'isConflict', isTrue)
            .having(
              (e) => e.details['publishedVersion'],
              'publishedVersion',
              'v1',
            ),
      ),
    );

    await admin.publish(v2, expected: 'v1');

    expect(await published(), {_shipped: 'v2', _mini: 'v2'});
    expect((await app.getManifest(_mini)).courseVersion, 'v2');
    expect((await app.getManifest(_mini, version: 'v1')).courseVersion, 'v1');
    expect(
      (await app.getCourseBundle(_mini, _sharedLesson)).courseVersion,
      'v2',
    );
    expect(
      (await app.getCourseBundle(
        _mini,
        _sharedLesson,
        version: 'v1',
      )).courseVersion,
      'v1',
    );
    expect(await admin.statuses(_mini), {'v1': 'SUPERSEDED', 'v2': 'LIVE'});
  });

  test('rolling back moves the app to the older version without deleting the newer', () async {
    await expectLater(
      admin.rollback(_mini, target: 'v1', expected: 'v1'),
      throwsA(_apiError('REVISION_CONFLICT', 409)),
    );

    await admin.rollback(_mini, target: 'v1', expected: 'v2');

    expect(await published(), {_shipped: 'v2', _mini: 'v1'});
    expect((await app.getManifest(_mini)).courseVersion, 'v1');
    expect(await admin.statuses(_mini), {'v1': 'LIVE', 'v2': 'SUPERSEDED'});
  });

  test('a rollback onto a version whose media is gone is refused', () async {
    await lane.setFaults(missingMedia: true);

    await expectLater(
      admin.rollback(_mini, target: 'v2', expected: 'v1'),
      throwsA(_apiError('VALIDATION_ERROR', 400)),
    );

    expect((await app.getManifest(_mini)).courseVersion, 'v1');
  });

  test(
    'unpublishing takes the course away from the app and keeps the shipped one',
    () async {
      await admin.unpublish(_mini, expected: 'v1');

      expect(await published(), {_shipped: 'v2'});
      await expectLater(
        app.getManifest(_mini),
        throwsA(_apiError('NOT_FOUND', 404)),
      );
      await expectLater(
        app.getCourseBundle(_mini, _sharedLesson),
        throwsA(_apiError('NOT_FOUND', 404)),
      );
      // The shipped course is untouched, and the course-less read is unambiguous again.
      expect((await app.getManifest(_shipped)).courseVersion, 'v2');
      expect((await app.getBundle(_sharedLesson)).courseId, _shipped);
      expect(await ActiveCourse(ApiEndpoints(client)).id(), _shipped);
      // History is kept; nothing is live.
      expect(await admin.statuses(_mini), {
        'v1': 'SUPERSEDED',
        'v2': 'SUPERSEDED',
      });
    },
  );
}
