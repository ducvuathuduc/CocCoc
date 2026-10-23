import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/practice/data/mistake_history_repository.dart';

import 'support/fake_api_transport.dart';

class BrokenMistakeStore implements SnapshotStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('disk full');
}

void main() {
  final at = DateTime.utc(2026, 10, 21);
  const exercise = Exercise(
    id: 'one',
    kind: ExerciseKind.textTranslation,
    title: 'Translate',
    prompt: 'Xin chào',
    correctText: 'Hello',
    hint: 'A greeting',
  );
  MistakeEvidence wrong(Exercise e) =>
      MistakeEvidence(e, correct: false, assisted: false);
  test(
    'demo history survives a new repository; duplicate completion counts once',
    () async {
      final store = MemorySnapshotStore();
      var repo = MistakeHistoryRepository(store: store, clock: () => at);
      await repo.record('lesson-1', [wrong(exercise)], review: false);
      repo = MistakeHistoryRepository(store: store);
      await repo.record('lesson-1', [wrong(exercise)], review: false);
      final value = (await repo.load()).items.single;
      expect(value.count, 1);
      expect(value.exercise!.prompt, 'Xin chào');
      expect(value.at, at);
    },
  );
  test(
    'only unassisted first correct review resolves; lesson and hint do not',
    () async {
      final repo = MistakeHistoryRepository(store: MemorySnapshotStore());
      await repo.record('lesson', [wrong(exercise)], review: false);
      await repo.record('regular-correct', [
        const MistakeEvidence(exercise, correct: true, assisted: false),
      ], review: false);
      expect((await repo.load()).items, hasLength(1));
      await repo.record('hinted-review', [
        const MistakeEvidence(exercise, correct: true, assisted: true),
      ], review: true);
      expect((await repo.load()).items, hasLength(1));
      await repo.record('wrong-review', [wrong(exercise)], review: true);
      expect((await repo.load()).items.single.count, 2);
      await repo.record('correct-review', [
        const MistakeEvidence(exercise, correct: true, assisted: false),
      ], review: true);
      expect((await repo.load()).items, isEmpty);
    },
  );
  test(
    'history caps at 100 and concurrent writes preserve both sessions',
    () async {
      final repo = MistakeHistoryRepository(store: MemorySnapshotStore());
      await Future.wait([
        repo.record('a', [wrong(exercise)], review: false),
        repo.record('b', [
          wrong(
            const Exercise(
              id: 'two',
              kind: ExerciseKind.fillBlank,
              title: '',
              prompt: '',
              correctText: 'cat',
            ),
          ),
        ], review: false),
      ]);
      expect((await repo.load()).items, hasLength(2));
      await repo.record('many', [
        for (var i = 0; i < 105; i++)
          wrong(
            Exercise(
              id: 'item-$i',
              kind: ExerciseKind.textTranslation,
              title: '',
              prompt: '',
              correctText: '',
            ),
          ),
      ], review: false);
      expect((await repo.load()).items, hasLength(100));
    },
  );
  test(
    'exercise codec preserves every authored exercise type and media fields',
    () {
      for (final e in [
        ...mockEnglishExercises,
        ...mockPracticeExercises,
        mockListeningPairsExercise,
      ]) {
        final restored = decodeMistakeExercise(
          Map<String, dynamic>.from(encodeMistakeExercise(e)),
        );
        expect(encodeMistakeExercise(restored), encodeMistakeExercise(e));
      }
    },
  );
  test(
    'failed storage never reports saved; corrupt history is not overwritten',
    () async {
      await expectLater(
        MistakeHistoryRepository(store: BrokenMistakeStore())
            .record('a', [wrong(exercise)], review: false),
        throwsStateError,
      );
      final store = MemorySnapshotStore()..values['mistakes'] = '{broken';
      await expectLater(
        MistakeHistoryRepository(store: store)
            .record('a', [wrong(exercise)], review: false),
        throwsFormatException,
      );
      expect(store.values['mistakes'], '{broken');
    },
  );
  test('API reads only mistakes, restores offline cache and removes resolved server rows', () async {
    final transport = FakeApiTransport();
    Map<String, Object?> page({bool resolved = false}) => {
      'items': [
        {
          'courseId': 'vi_en',
          'exerciseId': 'u1n1l1-e1',
          'lessonVersion': 'v1.u1n1l1',
          'skillId': 'greeting',
          'mistakeCount': 2,
          'lastMistakeAt': isoNow,
          'resolvedAt': resolved ? isoNow : null,
        },
      ],
      'nextCursor': null,
      'asOf': isoNow,
    };
    transport.json('GET /v1/mistakes', page());
    final store = MemorySnapshotStore();
    final api = ApiEndpoints(fakeClient(transport));
    var repo = MistakeHistoryRepository(
      store: store,
      api: api,
      course: () async => 'vi_en',
    );
    expect((await repo.load()).items.single.count, 2);
    expect(transport.requests.single.uri.queryParameters['courseId'], 'vi_en');
    transport.offline = true;
    repo = MistakeHistoryRepository(
      store: store,
      api: api,
      course: () async => 'vi_en',
    );
    final restored = await repo.load();
    expect(restored.offline, true);
    expect(restored.items.single.id, 'u1n1l1-e1');
    transport.offline = false;
    transport.json('GET /v1/mistakes', page(resolved: true));
    expect((await repo.load()).items, isEmpty);
    expect(transport.requests.every((r) => r.uri.path == '/v1/mistakes'), true);
  });
  test(
    'API offline without cache and expired auth are errors, not empty history',
    () async {
      final transport = FakeApiTransport()..offline = true;
      final repo = MistakeHistoryRepository(
        store: MemorySnapshotStore(),
        api: ApiEndpoints(fakeClient(transport)),
        course: () async => 'vi_en',
      );
      await expectLater(repo.load(), throwsA(isA<ApiException>()));
      transport.offline = false;
      transport.json(
        'GET /v1/mistakes',
        errorEnvelope('UNAUTHENTICATED'),
        status: 401,
      );
      await expectLater(
        repo.load(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isUnauthenticated,
            'expired auth',
            true,
          ),
        ),
      );
    },
  );
}
