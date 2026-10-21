import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/session/application/real_learning_session.dart';

import 'support/fake_api_transport.dart';
import 'features/learning/api_learning_repository_test.dart' as f;
import 'features/api_snapshot_repositories_test.dart' as snapshots;

import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/features/session/data/real_learning_session_repository.dart';

void main() {
  test(
    'returning account preserves profile and enrollment without writes',
    () async {
      final transport = FakeApiTransport()
        ..json('GET /base/v1/me', snapshots.profile())
        ..json('GET /base/v1/me/rewards', snapshots.rewards())
        ..json('GET /v1/courses/vi_en/path', f.path());
      final api = ApiEndpoints(fakeClient(transport));
      final result = await RealLearningSessionRepository(
        api,
        ActiveCourse(api, fixed: 'vi_en'),
      ).prepare('me', 'Different name');
      expect(result.profile.nickname, 'Thanh');
      expect(result.paths.single.enrollment.revision, 4);
      expect(result.rewards.studyXp, 300);
      expect(transport.requests.every((r) => r.method == 'GET'), true);
    },
  );
  test(
    'new account initializes profile and enrolls only after missing reads',
    () async {
      final transport = FakeApiTransport()
        ..json('POST /base/v1/me/initialize', snapshots.profile())
        ..json('PATCH /base/v1/me', snapshots.profile())
        ..json('GET /base/v1/me/rewards', snapshots.rewards())
        ..json('POST /v1/enrollments', f.path()['enrollment']);
      transport.once(
        'GET /v1/courses/vi_en/path',
        (_) => jsonResponse(errorEnvelope('NOT_FOUND'), status: 404),
      );
      transport.json('GET /v1/courses/vi_en/path', f.path());
      final api = ApiEndpoints(fakeClient(transport));
      await RealLearningSessionRepository(
        api,
        ActiveCourse(api, fixed: 'vi_en'),
        ids: SequenceIds(),
      ).prepare('me', 'New learner');
      expect(
        bodyOf(transport.to('PATCH /base/v1/me').single)['nickname'],
        'New learner',
      );
      final enrollment = transport.to('POST /v1/enrollments').single;
      expect(bodyOf(enrollment)['startPoint'], 'beginner');
      expect(enrollment.headers['Idempotency-Key'], isNotEmpty);
    },
  );
  test(
    'preparation refuses another account profile and does not enroll',
    () async {
      final transport = FakeApiTransport()
        ..json('GET /base/v1/me', snapshots.profile());
      final api = ApiEndpoints(fakeClient(transport));
      await expectLater(
        RealLearningSessionRepository(
          api,
          ActiveCourse(api, fixed: 'vi_en'),
        ).prepare('other', ''),
        throwsA(isA<ApiException>()),
      );
      expect(transport.requests, hasLength(1));
    },
  );
  test('real route guard blocks protected routes until server preparation', () {
    String? route({
      bool signed = false,
      bool restoring = false,
      bool ready = false,
      String path = '/home',
    }) => realLearningRedirect(
      path: path,
      api: true,
      restoring: restoring,
      signedIn: signed,
      ready: ready,
    );
    expect(route(), '/login');
    expect(route(restoring: true), '/connecting');
    expect(route(signed: true), '/connecting');
    expect(route(signed: true, ready: true), isNull);
    expect(route(signed: true, ready: true, path: '/connecting'), '/home');
    expect(route(path: '/reset-password'), isNull);
    expect(route(path: '/auth/register'), isNull);
  });
  test(
    'a later unit starts its own server lesson instead of unit one',
    () async {
      final transport = FakeApiTransport();
      final path = f.path();
      final original = (path['nodes'] as List).first as Map;
      path['nodes'] = [
        original,
        {
          ...original,
          'nodeId': 'u2n1',
          'unitId': 'u2',
          'order': 8,
          'lessonIds': ['u2n1l1'],
          'state': 'available',
        },
      ];
      transport.json('GET /v1/courses/vi_en/path', path);
      transport.json('POST /v1/sessions', {
        ...f.session(),
        'lessonId': 'u2n1l1',
      });
      final repo = ApiLearningRepository(
        learning: LearningApi(fakeClient(transport)),
        journal: InMemoryLessonJournal(),
        courseId: 'vi_en',
      );
      await repo.loadLesson('section-1-unit-2-review-0');
      expect(
        bodyOf(transport.to('POST /v1/sessions').single)['lessonId'],
        'u2n1l1',
      );
    },
  );
  test(
    'ordinary lesson restart restores the next unanswered exercise',
    () async {
      final transport = FakeApiTransport()
        ..json('GET /v1/courses/vi_en/path', f.path())
        ..json('POST /v1/sessions', f.session())
        ..json('POST /v1/sessions/sess-1/answers', f.answerResult('x', true, 1))
        ..json('GET /v1/sessions/sess-1', f.session(revision: 1));
      final journal = InMemoryLessonJournal();
      ApiLearningRepository build() => ApiLearningRepository(
        learning: LearningApi(fakeClient(transport)),
        journal: journal,
        courseId: 'vi_en',
      );
      final first = build();
      final exercises = await first.loadLesson('node-0');
      await first.grade(
        exercises.first,
        LessonAnswer(selectedId: exercises.first.correctIds.single),
      );
      final second = build();
      await second.loadLesson('node-0');
      expect(second.loadDraft()?.index, 1);
      expect(second.loadDraft()?.attempted, 1);
      expect(transport.to('POST /v1/sessions'), hasLength(1));
    },
  );
  test(
    'offline lesson restart retains provisionally answered questions',
    () async {
      final transport = FakeApiTransport()
        ..json('GET /v1/courses/vi_en/path', f.path())
        ..json('POST /v1/sessions', f.session());
      final journal = InMemoryLessonJournal();
      ApiLearningRepository build() => ApiLearningRepository(
        learning: LearningApi(fakeClient(transport)),
        journal: journal,
        courseId: 'vi_en',
      );
      final first = build();
      final exercises = await first.loadLesson('node-0');
      transport.offline = true;
      await first.grade(
        exercises.first,
        LessonAnswer(selectedId: exercises.first.correctIds.single),
      );
      final second = build();
      await second.loadLesson('node-0');
      expect(second.loadDraft()?.index, 1);
      expect(second.activeSession!.answers.single.synced, false);
    },
  );
}
