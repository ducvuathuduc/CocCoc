import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/api/client/active_course.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/practice/data/activity_progress_repository.dart';
import 'package:cocenglish/features/practice/data/practice_content_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api_transport.dart';

final Map<String, Object?> bundle = jsonDecode(
  File('test/fixtures/api/lesson_bundle_u1n1l1.json').readAsStringSync(),
) as Map<String, Object?>;

Map<String, Object?> path() => {
  'enrollment': {
    'courseId': 'vi_en',
    'courseVersion': 'v1',
    'frontierNodeOrder': 0,
    'completedLessonIds': <String>[],
    'masteredNodeIds': <String>[],
    'revision': 4,
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

Map<String, Object?> reviewPage() => {
  'items': [
    {
      'vocabularyId': 'vocab-coffee',
      'skillId': 'u1.vocab',
      'dueAt': isoNow,
      'stage': 2,
      'mastery': 0.5,
    },
  ],
  'nextCursor': null,
  'asOf': isoNow,
};

Map<String, Object?> activityPage() => {
  'items': [
    {
      'courseId': 'vi_en',
      'kind': 'STORY',
      'activityId': 'story-morning',
      'completions': 2,
      'bestScore': 9,
      'stars': 3,
      'firstCompletedAt': isoNow,
      'lastCompletedAt': isoNow,
    },
  ],
  'nextCursor': null,
  'asOf': isoNow,
};

void main() {
  group('practice content', () {
    late FakeApiTransport transport;
    late ApiPracticeContentRepository repository;

    setUp(() {
      transport = FakeApiTransport()
        ..json('GET /v1/courses/vi_en/path', path())
        ..json('GET /v1/lessons/u1n1l1/bundle', bundle)
        ..json('GET /v1/review', reviewPage());
      final api = ApiEndpoints(fakeClient(transport));
      repository = ApiPracticeContentRepository(
        api,
        ActiveCourse(api, fixed: 'vi_en'),
      );
    });

    test('typed practice loads the server lesson bundle', () async {
      final exercises = await repository.practiceExercises(
        ExerciseKind.dictation,
      );

      expect(exercises, hasLength(1));
      expect(exercises.single.kind, ExerciseKind.dictation);
      expect(transport.to('GET /v1/lessons/u1n1l1/bundle'), hasLength(1));

      await repository.practiceExercises(ExerciseKind.dictation);
      expect(transport.to('GET /v1/lessons/u1n1l1/bundle'), hasLength(1));
    });

    test('offline typed practice keeps the mock fixture', () async {
      transport.offline = true;
      final exercises = await repository.practiceExercises(
        ExerciseKind.dictation,
      );

      expect(exercises.single.id, 'english-practice-dictation');
    });

    test('review index comes from GET /v1/review', () async {
      final items = await repository.reviewItems();

      expect(items, hasLength(1));
      expect(items.single.vocabularyId, 'vocab-coffee');
      expect(items.single.skillId, 'u1.vocab');
      expect(items.single.stage, 2);
      expect(transport.to('GET /v1/review'), hasLength(1));
      expect(transport.to('GET /v1/review').single.uri.queryParameters, {
        'courseId': 'vi_en',
        'limit': '100',
      });
    });

    test('offline review index is empty, not invented', () async {
      transport.offline = true;
      expect(await repository.reviewItems(), isEmpty);
    });

    test('mock data layer keeps the local practice fixtures', () {
      final mock = MockPracticeContentRepository();
      expect(mock.isRemote, isFalse);
      expect(
        mock.practiceExercises(ExerciseKind.speakRepeat).single.id,
        'english-practice-speak',
      );
    });
  });

  group('activity progress', () {
    late FakeApiTransport transport;

    setUp(() {
      transport = FakeApiTransport()..json('GET /v1/activities', activityPage());
    });

    test('maps library progress without inventing values', () async {
      final api = ApiEndpoints(fakeClient(transport));
      final repository = ApiActivityProgressRepository(
        api,
        ActiveCourse(api, fixed: 'vi_en'),
      );

      final items = await repository.load(kind: 'STORY');

      expect(items, hasLength(1));
      expect(items.single.activityId, 'story-morning');
      expect(items.single.completions, 2);
      expect(items.single.stars, 3);
      expect(items.single.bestScore, 9);
      expect(transport.to('GET /v1/activities').single.uri.queryParameters, {
        'courseId': 'vi_en',
        'kind': 'STORY',
        'limit': '100',
      });
    });

    test('mock data layer reports no library progress', () async {
      final mock = MockActivityProgressRepository();
      expect(mock.isRemote, isFalse);
      expect(await mock.load(), isEmpty);
    });
  });
}
