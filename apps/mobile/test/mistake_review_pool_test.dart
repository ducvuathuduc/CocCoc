import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/core/cache/lesson_journal.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/learning/api_learning_repository_test.dart' as fixtures;
import 'support/fake_api_transport.dart';

Map<String, Object?> reviewPage(List<Map<String, Object?>> items) => {
  'items': items,
  'nextCursor': null,
  'asOf': isoNow,
};

Map<String, Object?> reviewItem() => {
  'vocabularyId': 'vocab-coffee',
  'skillId': 'u1.vocab',
  'dueAt': isoNow,
  'stage': 2,
  'mastery': 0.5,
};

void main() {
  late FakeApiTransport transport;
  late InMemoryLessonJournal journal;
  late ApiLearningRepository repo;

  setUp(() {
    transport = FakeApiTransport()
      ..json('GET /v1/courses/vi_en/path', fixtures.path())
      ..json('GET /v1/review', reviewPage([reviewItem()]))
      ..json('POST /v1/sessions', {
        ...fixtures.session(),
        'mode': 'REVIEW',
        'lessonId': 'review_dynamic',
        'bundle': {...fixtures.bundle, 'lessonId': 'review_dynamic'},
      });
    journal = InMemoryLessonJournal();
    repo = ApiLearningRepository(
      learning: LearningApi(fakeClient(transport)),
      journal: journal,
      courseId: 'vi_en',
      ids: SequenceIds(),
    );
  });

  test('an empty review index fails before starting a server session', () async {
    transport.json('GET /v1/review', reviewPage([]));

    await expectLater(
      repo.loadLesson('mistake-review'),
      throwsA(
        isA<LearningFailure>().having(
          (e) => e.message,
          'message',
          contains('Complete a lesson'),
        ),
      ),
    );
    expect(transport.to('POST /v1/sessions'), isEmpty);
    expect(await journal.active(), isNull);
  });

  test('a non-empty review index starts the private review session', () async {
    await repo.loadLesson('mistake-review');

    expect(transport.to('GET /v1/review').single.uri.queryParameters, {
      'courseId': 'vi_en',
      'limit': '1',
    });
    expect(transport.to('POST /v1/sessions'), hasLength(1));
    expect((await journal.active())!.lessonId, 'review_dynamic');
  });
}
