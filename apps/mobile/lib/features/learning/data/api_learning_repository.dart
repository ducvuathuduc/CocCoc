import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/idempotency.dart';
import '../../../core/api/client/service_apis.dart';
import '../../../core/cache/lesson_journal.dart';
import '../domain/learning_models.dart';
import 'learning_repository.dart';
import 'lesson_wire_mapper.dart';

/// [LearningRepository] backed by the Learning service (P4-FE-001,
/// P5-FE-001, P6-FE-001).
///
/// * `loadLesson` resolves the node on the server path, starts (or resumes) a
///   session and renders its bundle.
/// * `grade` journals the answer with its idempotency key before sending it;
///   the server's verdict is authoritative. Offline, the bundle's grading rule
///   gives a provisional verdict and the lesson continues.
/// * `complete` commits online, or queues an `OfflineCompletionRequest` that
///   [syncPending] replays with the same `operationId`.
/// * XP is never computed on the client: the receipt carries the reward the
///   Progress service credited (0 while it is still pending).
class ApiLearningRepository implements LearningRepository {
  ApiLearningRepository({
    required this.learning,
    required this.journal,
    this.progress,
    IdGenerator? ids,
    this.courseId,
    this.rewardPollDelay = const Duration(milliseconds: 400),
    this.rewardPolls = 2,
  }) : ids = ids ?? UuidV4Generator();

  final LearningApi learning;
  final ProgressApi? progress;
  final LessonJournal journal;
  final IdGenerator ids;

  /// Fixed course; null picks the first available course from the catalog.
  final String? courseId;
  final Duration rewardPollDelay;
  final int rewardPolls;

  @override
  bool get enforcesHearts => false;

  String? _resolvedCourseId;
  JournalSession? _session;
  LessonWireMapper? _mapper;
  final Map<String, int> _attempts = {};
  LessonState? _draft;

  /// Exposed for tests and diagnostics.
  JournalSession? get activeSession => _session;

  @override
  Future<List<Exercise>> loadLesson(String nodeId) async {
    await syncPending();
    final journaled = await journal.active();
    try {
      final course = await _courseId();
      final path = await learning.getPath(course);
      final node = _pickNode(path, nodeId);
      final lessonId = _pickLesson(node, path.enrollment);
      final resume =
          journaled != null &&
              journaled.courseId == course &&
              journaled.lessonId == lessonId
          ? journaled
          : null;
      final session = await _startOrResume(
        course: course,
        lessonId: lessonId,
        nodeId: nodeId,
        enrollmentRevision: path.enrollment.revision,
        resume: resume,
      );
      return _activate(session);
    } on ApiException catch (error) {
      if (error.isOffline && journaled != null) {
        // Offline restart of the journaled lesson: regrade from the bundle.
        return _activate(journaled);
      }
      throw LearningFailure(error.userMessage);
    }
  }

  Future<JournalSession> _startOrResume({
    required String course,
    required String lessonId,
    required String nodeId,
    required int enrollmentRevision,
    JournalSession? resume,
  }) async {
    if (resume?.sessionId case final sessionId?) {
      try {
        final server = await learning.getSession(sessionId);
        if (server.status == 'ACTIVE') {
          final replayed = await _replayUnsynced(
            resume!.copyWith(revision: server.revision),
          );
          await journal.saveActive(replayed);
          return replayed;
        }
      } on ApiException catch (error) {
        if (error.isOffline) rethrow;
        // Expired or unknown: start a fresh attempt below.
      }
    }
    final startKey = resume?.startKey ?? ids.next();
    final session = await learning.startSession(
      wire.SessionRequest(
        courseId: course,
        lessonId: lessonId,
        mode: 'LESSON',
        expectedEnrollmentRevision: enrollmentRevision,
      ),
      idempotencyKey: startKey,
    );
    final journaled = JournalSession(
      nodeId: nodeId,
      courseId: course,
      lessonId: session.lessonId,
      lessonVersion: session.lessonVersion,
      bundleHash: session.bundle.manifestHash,
      enrollmentRevision: enrollmentRevision,
      bundle: session.bundle.toJson(),
      startKey: startKey,
      completeKey: ids.next(),
      sessionId: session.sessionId,
      revision: session.revision,
    );
    await journal.saveActive(journaled);
    return journaled;
  }

  /// Replays answers journaled before a crash, reusing their keys.
  Future<JournalSession> _replayUnsynced(JournalSession session) async {
    var current = session;
    final answers = [...session.answers];
    for (var i = 0; i < answers.length; i++) {
      final item = answers[i];
      if (item.synced) continue;
      final result = await learning.submitAnswer(
        current.sessionId!,
        wire.AnswerRequest(
          exerciseId: item.exerciseId,
          attemptOrdinal: item.attemptOrdinal,
          answer: wire.Answer.fromJson(item.answer),
          assisted: item.assisted,
          substituted: item.substituted,
          expectedRevision: current.revision,
        ),
        idempotencyKey: item.idempotencyKey,
      );
      answers[i] = item.copyWith(synced: true, correct: result.correct);
      current = current.copyWith(
        revision: result.sessionRevision,
        answers: answers,
      );
    }
    return current;
  }

  List<Exercise> _activate(JournalSession session) {
    _session = session;
    final bundle = wire.LessonBundle.fromJson(session.bundle);
    final mapper = LessonWireMapper(bundle.exercises, assets: bundle.assets);
    _mapper = mapper;
    _attempts
      ..clear()
      ..addAll({
        for (final answer in session.answers)
          answer.exerciseId: answer.attemptOrdinal + 1,
      });
    return mapper.toDomain();
  }

  @override
  Future<bool> grade(Exercise exercise, LessonAnswer answer) async {
    final session = _session;
    final mapper = _mapper;
    if (session == null || mapper == null) {
      throw const LearningFailure('This lesson isn’t ready yet.');
    }
    final ordinal = (_attempts[exercise.id] ?? 0).clamp(0, 2);
    _attempts[exercise.id] = ordinal + 1;
    final wireAnswer = mapper.toWireAnswer(exercise.id, answer);
    final entry = JournalAnswer(
      exerciseId: exercise.id,
      attemptOrdinal: ordinal,
      answer: wireAnswer.toJson(),
      assisted: false,
      substituted: mapper.substitutedIds.contains(exercise.id),
      idempotencyKey: ids.next(),
    );
    var journaled = session.copyWith(answers: [...session.answers, entry]);
    await _save(journaled);

    final sessionId = journaled.sessionId;
    if (sessionId != null) {
      try {
        final result = await learning.submitAnswer(
          sessionId,
          wire.AnswerRequest(
            exerciseId: entry.exerciseId,
            attemptOrdinal: entry.attemptOrdinal,
            answer: wireAnswer,
            assisted: entry.assisted,
            substituted: entry.substituted,
            expectedRevision: journaled.revision,
          ),
          idempotencyKey: entry.idempotencyKey,
        );
        journaled = _markAnswer(
          journaled,
          entry,
          correct: result.correct,
          synced: true,
        ).copyWith(revision: result.sessionRevision);
        await _save(journaled);
        return result.correct;
      } on ApiException catch (error) {
        if (!error.isOffline) throw LearningFailure(error.userMessage);
        // Fall through to provisional offline grading.
      }
    }
    final correct = mapper.gradeLocally(exercise.id, entry.answer);
    await _save(_markAnswer(journaled, entry, correct: correct, synced: false));
    return correct;
  }

  JournalSession _markAnswer(
    JournalSession session,
    JournalAnswer entry, {
    required bool correct,
    required bool synced,
  }) => session.copyWith(
    answers: [
      for (final answer in session.answers)
        if (answer.idempotencyKey == entry.idempotencyKey)
          answer.copyWith(correct: correct, synced: synced)
        else
          answer,
    ],
  );

  Future<void> _save(JournalSession session) async {
    _session = session;
    await journal.saveActive(session);
  }

  @override
  Future<SessionReceipt> complete({
    required String nodeId,
    required int originalCorrect,
    required int originalTotal,
    required Duration elapsed,
    required bool guest,
    required bool placement,
  }) async {
    final initial = _session;
    if (initial == null) {
      throw const LearningFailure('This lesson isn’t ready yet.');
    }
    var session = initial;
    final sessionId = session.sessionId;
    if (sessionId != null && session.answers.any((a) => !a.synced)) {
      try {
        session = await _replayUnsynced(session);
        await _save(session);
      } on ApiException {
        // Still offline (or rejected): the completion is queued below.
      }
    }
    final allSynced = session.answers.every((answer) => answer.synced);
    if (sessionId != null && allSynced) {
      try {
        final completion = await learning.completeSession(
          sessionId,
          wire.CompleteRequest(expectedRevision: session.revision),
          idempotencyKey: session.completeKey,
        );
        await journal.clearActive();
        _session = null;
        final rewards = await _creditedRewards(completion);
        return SessionReceipt(
          id: completion.completionId,
          nodeId: nodeId,
          xp: rewards?.awardXp ?? 0,
          accuracy: completion.originalCount == 0
              ? 0
              : completion.originalCorrect / completion.originalCount,
          elapsed: elapsed,
          firstCompletion: completion.rewardStatus == 'pending',
          guest: guest,
          placement: placement,
        );
      } on ApiException catch (error) {
        if (!error.isOffline) throw LearningFailure(error.userMessage);
      }
    }
    return _queueOffline(
      session,
      nodeId: nodeId,
      originalCorrect: originalCorrect,
      originalTotal: originalTotal,
      elapsed: elapsed,
      guest: guest,
      placement: placement,
    );
  }

  Future<wire.Rewards?> _creditedRewards(wire.Completion completion) async {
    final api = progress;
    if (api == null || completion.rewardStatus != 'pending') return null;
    for (var poll = 0; poll <= rewardPolls; poll++) {
      try {
        final rewards = await api.getRewards(
          completionId: completion.completionId,
        );
        if (rewards.status != 'pending') return rewards;
      } on ApiException {
        return null;
      }
      if (poll < rewardPolls) await Future<void>.delayed(rewardPollDelay);
    }
    return null;
  }

  Future<SessionReceipt> _queueOffline(
    JournalSession session, {
    required String nodeId,
    required int originalCorrect,
    required int originalTotal,
    required Duration elapsed,
    required bool guest,
    required bool placement,
  }) async {
    final localId = ids.next();
    final request = wire.OfflineCompletionRequest(
      operationId: session.completeKey,
      localCompletionId: localId,
      courseId: session.courseId,
      lessonId: session.lessonId,
      lessonVersion: session.lessonVersion,
      bundleHash: session.bundleHash,
      expectedEnrollmentRevision: session.enrollmentRevision,
      answers: [
        for (final answer in session.answers)
          wire.OfflineAnswer.fromJson(answer.toOfflineAnswerJson()),
      ],
    );
    await journal.enqueueCompletion(request.toJson());
    await journal.clearActive();
    _session = null;
    return SessionReceipt(
      id: 'offline-$localId',
      nodeId: nodeId,
      xp: 0,
      accuracy: originalTotal == 0 ? 0 : originalCorrect / originalTotal,
      elapsed: elapsed,
      firstCompletion: false,
      guest: guest,
      placement: placement,
    );
  }

  /// Replays queued offline completions; stops at the first network failure.
  /// Returns how many were accepted (or rejected for good) by the server.
  Future<int> syncPending() async {
    var settled = 0;
    for (final json in await journal.pendingCompletions()) {
      final operationId = json['operationId']! as String;
      try {
        await learning.syncOfflineCompletion(
          wire.OfflineCompletionRequest.fromJson(json),
          idempotencyKey: operationId,
        );
        await journal.removeCompletion(operationId);
        settled++;
      } on ApiException catch (error) {
        if (error.isOffline || error.retryable || error.isUnauthenticated) {
          break;
        }
        // Permanently rejected (stale bundle, conflict): drop it, the server
        // stays authoritative and grants nothing for it.
        await journal.removeCompletion(operationId);
        settled++;
      } on wire.ContractViolation {
        await journal.removeCompletion(operationId);
      }
    }
    return settled;
  }

  Future<String> _courseId() async {
    final fixed = courseId ?? _resolvedCourseId;
    if (fixed != null) return fixed;
    final page = await learning.listCourses();
    final course = page.items.where((c) => c.available).firstOrNull;
    if (course == null) {
      throw const ApiException(
        code: 'NO_COURSE',
        message: 'No available course',
        statusCode: 404,
      );
    }
    return _resolvedCourseId = course.courseId;
  }

  /// Exact node id, else the UI's `node-<n>` ordinal, else the frontier.
  static wire.Node _pickNode(wire.Path path, String nodeId) {
    final nodes = [...path.nodes]..sort((a, b) => a.order.compareTo(b.order));
    if (nodes.isEmpty) {
      throw const ApiException(
        code: 'EMPTY_PATH',
        message: 'Path has no nodes',
        statusCode: 404,
      );
    }
    for (final node in nodes) {
      if (node.nodeId == nodeId) return node;
    }
    final ordinal = int.tryParse(
      RegExp(r'(\d+)$').firstMatch(nodeId)?.group(1) ?? '',
    );
    if (ordinal != null && ordinal < nodes.length) {
      final node = nodes[ordinal];
      if (node.state != 'locked' && node.lessonIds.isNotEmpty) return node;
    }
    return nodes.firstWhere(
      (node) => node.state == 'current' && node.lessonIds.isNotEmpty,
      orElse: () => nodes.firstWhere(
        (node) => node.state != 'locked' && node.lessonIds.isNotEmpty,
        orElse: () => nodes.first,
      ),
    );
  }

  static String _pickLesson(wire.Node node, wire.Enrollment enrollment) {
    if (node.lessonIds.isEmpty) {
      throw const ApiException(
        code: 'NO_LESSON',
        message: 'Node has no lessons',
        statusCode: 404,
      );
    }
    return node.lessonIds.firstWhere(
      (id) => !enrollment.completedLessonIds.contains(id),
      orElse: () => node.lessonIds.first,
    );
  }

  @override
  void saveDraft(LessonState state) => _draft = state;

  @override
  LessonState? loadDraft() => _draft;

  @override
  void clearDraft() => _draft = null;
}
