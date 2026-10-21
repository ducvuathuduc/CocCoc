import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/api/client/idempotency.dart';
import '../../../core/cache/lesson_journal.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../data/api_learning_repository.dart';
import '../data/learning_repository.dart';
import '../domain/learning_models.dart';
import '../../practice/application/mistake_history_controller.dart';
import '../../practice/data/mistake_history_repository.dart';

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return MockLearningRepository();
  return ApiLearningRepository(
    learning: ref.watch(learningApiProvider),
    progress: ref.watch(progressApiProvider),
    journal: ref.watch(lessonJournalProvider),
  );
});

/// Durable lesson journal, namespaced per signed-in user so one account never
/// sees another's queued answers.
final lessonJournalProvider = Provider<LessonJournal>((ref) {
  final user = ref.watch(authControllerProvider.select((s) => s.user?.id));
  return PreferencesLessonJournal(namespace: user ?? 'anonymous');
});

final learningStateProvider =
    NotifierProvider<LearningStateController, LearningState>(
      LearningStateController.new,
    );

final lessonControllerProvider =
    NotifierProvider<LessonController, LessonState>(LessonController.new);

class LearningStateController extends Notifier<LearningState> {
  @override
  LearningState build() => const LearningState();

  void claim(SessionReceipt receipt) {
    if (state.claimedReceiptIds.contains(receipt.id)) return;
    final claimed = <String>{...state.claimedReceiptIds, receipt.id};
    if (!receipt.firstCompletion || receipt.guest || receipt.placement) {
      state = state.copyWith(claimedReceiptIds: claimed);
      return;
    }
    state = state.copyWith(
      xp: state.xp + receipt.xp,
      streak: state.streak == 0 ? 1 : state.streak,
      score: (state.score + 5).clamp(0, 160),
      gems: state.gems + receipt.gems,
      completedNodes: <String>{...state.completedNodes, receipt.nodeId},
      currentNode: state.currentNode + 1,
      lessonInNode: (state.lessonInNode + 1) % 5,
      completedLessons: state.completedLessons + 1,
      claimedReceiptIds: claimed,
    );
  }
}

class LessonController extends Notifier<LessonState> {
  bool _disposed = false;
  bool _commandActive = false;
  int _revision = 0;
  int _originalTotal = 0;
  List<Exercise> _mistakes = <Exercise>[];
  List<Exercise> _nextRetry = <Exercise>[];
  final Map<String, MistakeEvidence> _firstEvidence = {};
  String _evidenceId = '';
  MistakeHistoryRepository? _historyRepository;

  LearningRepository get _repository => ref.read(learningRepositoryProvider);

  @override
  LessonState build() {
    ref.watch(authControllerProvider.select((s) => s.user?.id));
    _revision++;
    _commandActive = false;
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _revision += 1;
    });
    return const LessonState();
  }

  Future<void> start({
    String nodeId = 'node-0',
    bool guest = false,
    bool placement = false,
    List<Exercise>? exercises,
  }) async {
    if (_commandActive) return;
    _commandActive = true;
    final revision = ++_revision;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final loaded = exercises ?? await _repository.loadLesson(nodeId);
      if (!_isCurrent(revision)) return;
      final restored = nodeId == mistakeReviewNodeId
          ? _repository.loadDraft()
          : null;
      if (restored != null) {
        _originalTotal = restored.originalTotal;
        _mistakes = [...restored.pendingMistakes];
        _nextRetry = [...restored.nextMistakes];
        state = restored;
        return;
      }
      _originalTotal = loaded.length;
      _firstEvidence.clear();
      _evidenceId = UuidV4Generator().next();
      _historyRepository = ref.read(mistakeRepositoryProvider);
      _mistakes = <Exercise>[];
      _nextRetry = <Exercise>[];
      _repository.clearDraft();
      state = LessonState(
        stage: loaded.isEmpty ? LessonStage.idle : LessonStage.answering,
        exercises: loaded,
        nodeId: nodeId,
        guest: guest,
        placement: placement,
        startedAt: DateTime.now(),
        originalTotal: loaded.length,
        heartsEnforced: _repository.enforcesHearts,
      );
    } on LearningFailure catch (error) {
      if (_isCurrent(revision)) {
        state = state.copyWith(busy: false, error: error.message);
      }
    } catch (_) {
      if (_isCurrent(revision)) {
        state = state.copyWith(
          busy: false,
          error: 'This lesson is unavailable. Please try again.',
        );
      }
    } finally {
      if (_isCurrent(revision)) _commandActive = false;
    }
  }

  void select(String id) {
    if (!_editable ||
        state.current?.choices.any((choice) => choice.id == id) != true) {
      return;
    }
    state = state.copyWith(selectedId: id, clearError: true);
  }

  void updateText(String value) {
    if (!_editable) return;
    state = state.copyWith(text: value, clearError: true);
  }

  void toggleToken(String id) {
    if (!_editable ||
        state.current?.tokens.any((token) => token.id == id) != true) {
      return;
    }
    final tokens = <String>[...state.tokenIds];
    final existing = tokens.indexOf(id);
    if (existing >= 0) {
      tokens.removeAt(existing);
    } else {
      tokens.add(id);
    }
    state = state.copyWith(tokenIds: tokens, clearError: true);
  }

  void selectPairLeft(String id) {
    if (!_editable || state.current?.pairs.containsKey(id) != true) return;
    state = state.copyWith(selectedPairLeft: id, clearError: true);
  }

  void selectPairRight(String id) {
    if (!_editable || state.selectedPairLeft == null) return;
    final left = state.selectedPairLeft!;
    if (state.current?.pairs[left] == id) {
      state = state.copyWith(
        matchedPairs: <String, String>{...state.matchedPairs, left: id},
        clearSelectedPairLeft: true,
        clearError: true,
      );
    } else {
      state = state.copyWith(clearSelectedPairLeft: true);
    }
  }

  /// Records that the learner saw the one-time hearts explanation sheet.
  void acknowledgeHeartsIntro() {
    if (state.heartsIntroSeen) return;
    state = state.copyWith(heartsIntroSeen: true);
  }

  /// "CAN'T LISTEN NOW" on audio pairs: skip the exercise without a heart
  /// cost and show the skip notice in the feedback slot.
  void skipListening() {
    final current = state.current;
    if (!_editable || current == null || !current.audioPairs) return;
    state = state.copyWith(
      stage: LessonStage.feedback,
      skipped: true,
      clearCorrect: true,
      clearSelectedPairLeft: true,
      clearError: true,
    );
  }

  void revealHint() {
    if (!_editable || state.current?.hint == null) return;
    state = state.copyWith(assisted: true);
  }

  void substituteMedia() {
    if (!_editable || state.textAlternative) return;
    final current = state.current;
    if (current == null ||
        !<ExerciseKind>{
          ExerciseKind.listenChoice,
          ExerciseKind.dictation,
          ExerciseKind.speakRepeat,
          ExerciseKind.dialogueTurn,
        }.contains(current.kind)) {
      return;
    }
    final replacement = current.kind == ExerciseKind.dialogueTurn
        ? current
        : current.copyWith(
            kind: ExerciseKind.textTranslation,
            title: 'Type the sentence',
            prompt: current.correctText,
            choices: const <ExerciseChoice>[],
            tokens: const <ExerciseChoice>[],
            correctIds: const <String>[],
          );
    final exercises = <Exercise>[...state.exercises];
    exercises[state.index] = replacement;
    state = state.copyWith(
      exercises: exercises,
      assisted: true,
      textAlternative: true,
      clearSelectedId: true,
      tokenIds: const <String>[],
      matchedPairs: const <String, String>{},
      clearSelectedPairLeft: true,
      clearCorrect: true,
      clearError: true,
    );
  }

  Future<void> check() async {
    if (_commandActive || !state.canCheck) return;
    _commandActive = true;
    final revision = ++_revision;
    final exercise = state.current!;
    final answer = LessonAnswer(
      selectedId: state.selectedId,
      tokenIds: state.tokenIds,
      text: state.text,
      matchedPairs: state.matchedPairs,
    );
    state = state.copyWith(
      stage: LessonStage.checking,
      busy: true,
      clearError: true,
    );
    try {
      final repository = _repository;
      final correct = repository is EvidenceLearningRepository
          ? await (repository as EvidenceLearningRepository).gradeWithEvidence(
              exercise,
              answer,
              assisted: state.assisted,
              substituted: state.textAlternative,
            )
          : await repository.grade(exercise, answer);
      if (!_isCurrent(revision)) return;
      if (!state.isRetry) {
        _firstEvidence[exercise.id] = MistakeEvidence(
          exercise,
          correct: correct,
          assisted: state.assisted,
        );
      }
      var originalCorrect = state.originalCorrect;
      var attempted = state.attempted;
      if (state.isRetry) {
        if (!correct) _nextRetry.add(exercise);
      } else {
        attempted += 1;
        if (correct) {
          originalCorrect += 1;
        } else {
          _mistakes.add(exercise);
        }
      }
      state = state.copyWith(
        stage: LessonStage.feedback,
        busy: false,
        correct: correct,
        originalCorrect: originalCorrect,
        attempted: attempted,
        correctStreak: correct ? state.correctStreak + 1 : 0,
        pendingMistakes: _mistakes,
        nextMistakes: _nextRetry,
      );
    } on LearningFailure catch (error) {
      if (_isCurrent(revision)) {
        state = state.copyWith(
          stage: LessonStage.answering,
          busy: false,
          error: error.message,
        );
      }
    } catch (_) {
      if (_isCurrent(revision)) {
        state = state.copyWith(
          stage: LessonStage.answering,
          busy: false,
          error: 'We could not check that answer. Please try again.',
        );
      }
    } finally {
      if (_isCurrent(revision)) _commandActive = false;
    }
  }

  Future<void> next() async {
    if (_commandActive || state.stage != LessonStage.feedback) return;
    if (state.index + 1 < state.exercises.length) {
      _showExercise(state.index + 1);
      return;
    }
    if (!state.isRetry && _mistakes.isNotEmpty) {
      final retry = List<Exercise>.unmodifiable(_mistakes);
      _mistakes = <Exercise>[];
      _nextRetry = <Exercise>[];
      _showPass(retry, 1);
      return;
    }
    if (state.isRetry && _nextRetry.isNotEmpty && state.retryPass < 2) {
      final retry = List<Exercise>.unmodifiable(_nextRetry);
      _nextRetry = <Exercise>[];
      _showPass(retry, state.retryPass + 1);
      return;
    }
    await _complete();
  }

  void pause() {
    if (!{LessonStage.answering, LessonStage.feedback}.contains(state.stage) ||
        state.busy) {
      return;
    }
    state = state.copyWith(stage: LessonStage.paused, resumeStage: state.stage);
    _repository.saveDraft(state);
  }

  void resume() {
    if (!{LessonStage.idle, LessonStage.paused}.contains(state.stage)) return;
    final draft = _repository.loadDraft();
    if (draft == null || draft.current == null) return;
    _originalTotal = draft.originalTotal;
    _mistakes = [...draft.pendingMistakes];
    _nextRetry = [...draft.nextMistakes];
    state = draft.copyWith(stage: draft.resumeStage, busy: false);
  }

  void abandon() {
    _revision += 1;
    _repository.clearDraft();
    _mistakes = <Exercise>[];
    _nextRetry = <Exercise>[];
    state = const LessonState();
  }

  Future<void> claim() async {
    final receipt = state.receipt;
    if (state.stage != LessonStage.completed || receipt == null) return;
    ref.read(learningStateProvider.notifier).claim(receipt);
  }

  void nextResult() {
    if (state.stage != LessonStage.completed) return;
    state = state.copyWith(resultStep: state.resultStep + 1);
  }

  bool get _editable => state.stage == LessonStage.answering && !state.busy;

  bool _isCurrent(int revision) => !_disposed && revision == _revision;

  void _showExercise(int index) {
    state = state.copyWith(
      stage: LessonStage.answering,
      index: index,
      busy: false,
      clearSelectedId: true,
      tokenIds: const <String>[],
      text: '',
      matchedPairs: const <String, String>{},
      clearSelectedPairLeft: true,
      clearCorrect: true,
      assisted: false,
      textAlternative: false,
      skipped: false,
      clearError: true,
    );
  }

  void _showPass(List<Exercise> exercises, int pass) {
    state = state.copyWith(
      stage: LessonStage.answering,
      exercises: exercises,
      index: 0,
      retryPass: pass,
      pendingMistakes: _mistakes,
      nextMistakes: _nextRetry,
      isRetry: true,
      clearSelectedId: true,
      tokenIds: const <String>[],
      text: '',
      matchedPairs: const <String, String>{},
      clearSelectedPairLeft: true,
      clearCorrect: true,
      assisted: false,
      textAlternative: false,
      skipped: false,
      clearError: true,
    );
  }

  Future<void> _complete() async {
    _commandActive = true;
    final revision = ++_revision;
    state = state.copyWith(
      stage: LessonStage.checking,
      busy: true,
      clearError: true,
    );
    try {
      if (_repository is! ApiLearningRepository) {
        await _historyRepository?.record(
          _evidenceId,
          _firstEvidence.values.toList(),
          review: state.nodeId == mistakeReviewNodeId,
        );
        if (!_isCurrent(revision)) return;
      }
      final receipt = await _repository.complete(
        nodeId: state.nodeId,
        originalCorrect: state.originalCorrect,
        originalTotal: _originalTotal,
        elapsed: DateTime.now().difference(state.startedAt ?? DateTime.now()),
        guest: state.guest,
        placement: state.placement,
      );
      if (!_isCurrent(revision)) return;
      ref.invalidate(mistakeHistoryProvider);
      _repository.clearDraft();
      state = state.copyWith(
        stage: LessonStage.completed,
        busy: false,
        receipt: receipt,
        resultStep: 0,
      );
    } on LearningFailure catch (error) {
      if (_isCurrent(revision)) {
        state = state.copyWith(
          stage: LessonStage.feedback,
          busy: false,
          error: error.message,
        );
      }
    } catch (_) {
      if (_isCurrent(revision)) {
        state = state.copyWith(
          stage: LessonStage.feedback,
          busy: false,
          error: 'We could not finish this lesson. Please try again.',
        );
      }
    } finally {
      if (_isCurrent(revision)) _commandActive = false;
    }
  }
}
