import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/api_learning_repository.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/practice/application/mistake_history_controller.dart';
import 'package:cocenglish/features/practice/data/mistake_history_repository.dart';

class ReviewTestAuth extends AuthController {
  @override
  AuthState build() => const AuthState();
  void account(String id) => state = state.copyWith(
    user: AuthUser(id: id, email: '$id@example.test', name: id),
  );
}

class EvidenceMock extends MockLearningRepository
    implements EvidenceLearningRepository {
  EvidenceMock() : super(delay: Duration.zero);
  bool? hinted;
  @override
  Future<bool> gradeWithEvidence(
    Exercise exercise,
    LessonAnswer answer, {
    required bool assisted,
    required bool substituted,
  }) {
    hinted = assisted;
    return grade(exercise, answer);
  }
}

void main() {
  const exercise = Exercise(
    id: 'saved',
    kind: ExerciseKind.textTranslation,
    title: 'Translate',
    prompt: 'Xin chào',
    correctText: 'Hello',
    hint: 'Greeting',
  );
  test('completed lesson saves original mistake even after a correct retry; review resolves with zero XP', () async {
    final store = MemorySnapshotStore();
    final history = MistakeHistoryRepository(store: store);
    final container = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWithValue(
          MockLearningRepository(delay: Duration.zero),
        ),
        mistakeRepositoryProvider.overrideWithValue(history),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(lessonControllerProvider.notifier);
    await controller.start(exercises: const [exercise]);
    controller.updateText('wrong');
    await controller.check();
    await controller.next();
    controller.updateText('Hello');
    await controller.check();
    await controller.next();
    expect(
      container.read(lessonControllerProvider).stage,
      LessonStage.completed,
    );
    expect(
      (await MistakeHistoryRepository(store: store).load()).items.single.count,
      1,
    );
    await controller.start(
      nodeId: mistakeReviewNodeId,
      guest: true,
      exercises: const [exercise],
    );
    controller.updateText('Hello');
    await controller.check();
    await controller.next();
    expect((await history.load()).items, isEmpty);
    expect(container.read(lessonControllerProvider).receipt!.xp, 0);
    expect(
      container.read(lessonControllerProvider).receipt!.firstCompletion,
      false,
    );
  });
  test('hint evidence reaches authoritative grading and cannot resolve demo history', () async {
    final history = MistakeHistoryRepository(store: MemorySnapshotStore());
    await history.record('original', [
      const MistakeEvidence(exercise, correct: false, assisted: false),
    ], review: false);
    final repository = EvidenceMock();
    final container = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWithValue(repository),
        mistakeRepositoryProvider.overrideWithValue(history),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(lessonControllerProvider.notifier);
    await controller.start(
      nodeId: mistakeReviewNodeId,
      guest: true,
      exercises: const [exercise],
    );
    controller.revealHint();
    controller.updateText('Hello');
    await controller.check();
    await controller.next();
    expect(repository.hinted, true);
    expect((await history.load()).items, hasLength(1));
  });
  test(
    'account switch hides history and discards the previous lesson state',
    () async {
      final stores = <String, MemorySnapshotStore>{};
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(ReviewTestAuth.new),
          mistakeStoreProvider.overrideWith(
            (ref, key) => stores.putIfAbsent(key, MemorySnapshotStore.new),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(mistakeHistoryProvider, (_, _) {});
      container.listen(lessonControllerProvider, (_, _) {});
      final auth =
          container.read(authControllerProvider.notifier) as ReviewTestAuth;
      auth.account('alice');
      await container.read(mistakeRepositoryProvider).record('one', [
        const MistakeEvidence(exercise, correct: false, assisted: false),
      ], review: false);
      container.invalidate(mistakeHistoryProvider);
      expect(
        (await container.read(mistakeHistoryProvider.future)).items,
        hasLength(1),
      );
      await container
          .read(lessonControllerProvider.notifier)
          .start(exercises: const [exercise]);
      auth.account('bob');
      expect(
        (await container.read(mistakeHistoryProvider.future)).items,
        isEmpty,
      );
      expect(container.read(lessonControllerProvider).stage, LessonStage.idle);
      auth.account('alice');
      expect(
        (await container.read(mistakeHistoryProvider.future)).items,
        hasLength(1),
      );
    },
  );
}
