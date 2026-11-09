// API-mode lane: the app's real generated clients, transport and parsers against a running
// Learning service (tools/scripts/api-lane-backend.mjs). Nothing here is mocked. The mock-mode
// suite in test/ stays the undeclared build; this lane is compiled with DATA_SOURCE=api.
//
// Run with `node tools/scripts/mobile-api-lane.mjs`, which starts the backend and passes the
// defines. These tests only read vi_en, the course a fresh install sees, so file order is free.
import 'dart:io';

import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/core/api/client/access_token.dart';
import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/api/client/api_operation.dart';
import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/core/config/real_profile_validation.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/learning/data/lesson_wire_mapper.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/lane.dart';

const _course = 'vi_en';
const _exerciseTypes = {
  'textTranslation',
  'choice',
  'wordBank',
  'sentenceOrder',
  'fillBlank',
  'matchPairs',
  'imageChoice',
  'listenChoice',
  'dictation',
  'speakRepeat',
  'dialogueTurn',
  'storyQuestion',
};

Matcher _apiError(String code, int status, {bool? retryable}) =>
    isA<ApiException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.statusCode, 'statusCode', status)
        .having((e) => e.retryable, 'retryable', retryable ?? anything);

void main() {
  final lane = laneState();
  final client = laneClient(lane);
  final learning = LearningApi(client);

  group('configuration', () {
    test('the lane is compiled as an API build aimed at the lane backend', () {
      final config = AppConfig.current;

      expect(
        config.declaredDataSource,
        isTrue,
        reason: 'DATA_SOURCE must be declared; this is not the mock lane',
      );
      expect(config.dataSource, DataSource.api);
      expect(config.isApi, isTrue);
      expect(config.useMockAuth, isFalse);
      expect(config.buildProblem, isNull);
      expect(config.baseUrl(ApiService.learning), lane.uri);
    });

    test('the app admits that profile as a local native profile', () {
      expect(
        validateRealProfile(
          AppConfig.current,
          target: RealProfileTarget.localNative,
        ),
        isEmpty,
      );
    });
  });

  group('authentication', () {
    test('a signed-in learner reads the catalog', () async {
      final page = await learning.listCourses();

      expect(page.items, isNotEmpty);
      expect(page.asOf, isNotEmpty);
    });

    test(
      'with no session the app fails locally and never calls the network',
      () async {
        var signedOut = 0;
        // A closed port: any request that left the client would surface as NETWORK instead.
        final unreachable = laneClient(
          lane,
          baseUrl: Uri.parse('http://127.0.0.1:1'),
          tokens: const StaticTokenProvider(null),
          onUnauthenticated: () => signedOut++,
        );

        await expectLater(
          LearningApi(unreachable).listCourses(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', 'UNAUTHENTICATED')
                .having(
                  (e) => e.isUnauthenticated,
                  'isUnauthenticated',
                  isTrue,
                ),
          ),
        );
        expect(signedOut, 1);
      },
    );

    test(
      'a token the server rejects ends the session after one re-auth',
      () async {
        var signedOut = 0;
        final rejected = laneClient(
          lane,
          tokens: const StaticTokenProvider('not-a-valid-token'),
          onUnauthenticated: () => signedOut++,
        );

        await expectLater(
          LearningApi(rejected).listCourses(),
          throwsA(_apiError('AUTH_REQUIRED', 401)),
        );
        expect(signedOut, 1);
      },
    );

    test('a learner is refused the maintainer routes', () async {
      await expectLater(
        LaneAdmin(client).statuses(_course),
        throwsA(_apiError('MAINTAINER_REQUIRED', 403)),
      );
    });
  });

  group('course catalog and manifest', () {
    test('listCourses parses and offers the shipped course', () async {
      final page = await learning.listCourses();

      final course = page.items.firstWhere((c) => c.courseId == _course);
      expect(course.available, isTrue);
      expect(course.publishedVersion, 'v2');
      expect(course.sourceLocale, isNotEmpty);
      expect(course.targetLocale, isNotEmpty);
    });

    test('the active course resolves to the first available course', () async {
      final active = ActiveCourse(ApiEndpoints(client));

      expect(await active.id(), _course);
    });

    test(
      'the manifest parses and a pinned read returns the same version',
      () async {
        final live = await learning.getManifest(_course);
        final pinned = await learning.getManifest(_course, version: 'v2');

        expect(live.courseId, _course);
        expect(live.courseVersion, 'v2');
        expect(live.bundles, isNotEmpty);
        expect(live.units, isNotEmpty);
        expect(live.nodes, isNotEmpty);
        expect(live.manifestHash, matches(RegExp(r'^[a-f0-9]{64}$')));
        for (final index in [...live.bundles, live.placementBundle]) {
          expect(index.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
        }
        expect(pinned.toJson(), live.toJson());
      },
    );
  });

  group('API errors', () {
    test('an unknown course is a 404 the app can show safely', () async {
      await expectLater(
        learning.getManifest('no_such_course'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'NOT_FOUND')
              .having((e) => e.isNotFound, 'isNotFound', isTrue)
              .having((e) => e.retryable, 'retryable', isFalse)
              .having((e) => e.requestId, 'requestId', isNotEmpty)
              .having(
                (e) => e.userMessage,
                'userMessage',
                'We couldn’t complete that request. Please try again.',
              ),
        ),
      );
    });

    test('an unknown version and an unknown lesson are 404s', () async {
      await expectLater(
        learning.getManifest(_course, version: 'v404'),
        throwsA(_apiError('NOT_FOUND', 404)),
      );
      await expectLater(
        learning.getCourseBundle(_course, 'no_such_lesson'),
        throwsA(_apiError('NOT_FOUND', 404)),
      );
    });

    test('a malformed cursor is a 400 validation error', () async {
      await expectLater(
        learning.listCourses(cursor: '!!not-a-cursor!!'),
        throwsA(_apiError('VALIDATION_ERROR', 400, retryable: false)),
      );
    });

    test('an unreachable service is an offline NETWORK error', () async {
      final unreachable = LearningApi(
        laneClient(lane, baseUrl: Uri.parse('http://127.0.0.1:1')),
      );

      await expectLater(
        unreachable.listCourses(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'NETWORK')
              .having((e) => e.isOffline, 'isOffline', isTrue)
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('a service that never answers times out', () async {
      final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final held = <Socket>[];
      silent.listen(held.add);
      addTearDown(() async {
        for (final socket in held) {
          socket.destroy();
        }
        await silent.close();
      });
      final slow = LearningApi(
        laneClient(
          lane,
          baseUrl: Uri.parse('http://127.0.0.1:${silent.port}'),
          timeout: const Duration(milliseconds: 300),
        ),
      );

      await expectLater(
        slow.listCourses(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'TIMEOUT')
              .having((e) => e.isOffline, 'isOffline', isTrue),
        ),
      );
    });

    test('a Storage outage reaches the app as a retryable 503', () async {
      // The last lesson is read by no other test, so the service has not cached it yet.
      final manifest = await learning.getManifest(_course);
      final lessonId = manifest.bundles.last.lessonId;
      addTearDown(() => lane.setFaults(storageOutage: false));
      await lane.setFaults(storageOutage: true);

      await expectLater(
        learning.getCourseBundle(_course, lessonId),
        throwsA(_apiError('STORAGE_UNAVAILABLE', 503, retryable: true)),
      );

      await lane.setFaults(storageOutage: false);
      final recovered = await learning.getCourseBundle(_course, lessonId);
      expect(recovered.lessonId, lessonId);
    });
  });

  group('lesson bundles and the mobile parser', () {
    test(
      'every published bundle parses and maps; all 12 exercise types occur',
      () async {
        final manifest = await learning.getManifest(_course);
        final indexes = [...manifest.bundles, manifest.placementBundle];
        final seen = <String>{};
        var exercises = 0;

        for (final index in indexes) {
          final bundle = await learning.getCourseBundle(
            _course,
            index.lessonId,
          );

          expect(bundle.courseId, _course, reason: index.lessonId);
          expect(bundle.lessonId, index.lessonId);
          expect(bundle.lessonVersion, index.lessonVersion);
          expect(bundle.manifestHash, manifest.manifestHash);
          expect(bundle.exercises, isNotEmpty, reason: index.lessonId);
          for (final asset in bundle.assets) {
            expect(asset.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
            expect(asset.bytes, greaterThan(0), reason: asset.fileId);
          }
          final mapped = LessonWireMapper(
            bundle.exercises,
            assets: bundle.assets,
          ).toDomain();
          expect(
            mapped,
            hasLength(bundle.exercises.length),
            reason: index.lessonId,
          );
          for (final exercise in bundle.exercises) {
            seen.add(exercise.toJson()['type']! as String);
          }
          exercises += bundle.exercises.length;
        }

        expect(seen, _exerciseTypes);
        expect(exercises, greaterThan(indexes.length));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'a lesson runs end to end: enroll, path, session, answers, completion',
      () async {
        // A fresh learner, so the path starts at the beginning.
        final learner = LearningApi(
          laneClient(
            lane,
            tokens: StaticTokenProvider(
              'user-lane-e2e-${DateTime.now().microsecondsSinceEpoch}',
            ),
          ),
        );
        final enrollment = await learner.enrollCourse(
          const wire.EnrollRequest(courseId: _course, startPoint: 'beginner'),
        );
        expect(enrollment.courseId, _course);
        final path = await learner.getPath(_course, limit: 100);
        final node = path.nodes.firstWhere(
          (n) => const {'available', 'current'}.contains(n.state),
        );

        final repository = ApiLearningRepository(
          learning: learner,
          journal: InMemoryLessonJournal(),
          courseId: _course,
        );
        final exercises = await repository.loadLesson(node.nodeId);
        expect(exercises, isNotEmpty);
        var correct = 0;
        for (final exercise in exercises) {
          if (await repository.grade(exercise, _correctAnswer(exercise))) {
            correct++;
          }
        }
        expect(
          correct,
          exercises.length,
          reason: 'server regrades authored keys',
        );
        final receipt = await repository.complete(
          nodeId: node.nodeId,
          originalCorrect: correct,
          originalTotal: exercises.length,
          elapsed: const Duration(minutes: 2),
          guest: false,
          placement: false,
        );

        expect(receipt.id, isNotEmpty);
        expect(receipt.id, isNot(startsWith('offline-')));
        final after = await learner.getPath(_course, limit: 100);
        expect(
          after.enrollment.completedLessonIds.length,
          greaterThan(path.enrollment.completedLessonIds.length),
        );
      },
    );
  });
}

LessonAnswer _correctAnswer(Exercise exercise) => switch (exercise.kind) {
  ExerciseKind.choice ||
  ExerciseKind.imageChoice ||
  ExerciseKind.listenChoice => LessonAnswer(
    selectedId: exercise.correctIds.single,
  ),
  ExerciseKind.wordBank ||
  ExerciseKind.sentenceOrder => LessonAnswer(tokenIds: exercise.correctIds),
  ExerciseKind.matchPairs => LessonAnswer(matchedPairs: exercise.pairs),
  ExerciseKind.textTranslation ||
  ExerciseKind.fillBlank ||
  ExerciseKind.dictation ||
  ExerciseKind.speakRepeat ||
  ExerciseKind.dialogueTurn ||
  ExerciseKind.storyQuestion => LessonAnswer(text: exercise.correctText),
};
