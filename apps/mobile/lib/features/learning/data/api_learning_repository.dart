import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/idempotency.dart';
import '../../../core/api/client/service_apis.dart';
import '../../../core/cache/lesson_journal.dart';
import '../domain/learning_models.dart';
import 'learning_repository.dart';
import 'lesson_wire_mapper.dart';
import '../domain/review_resume.dart';
import '../domain/session_mode.dart';
import '../domain/session_outcome.dart';

const mistakeReviewNodeId = 'mistake-review';
const reviewLessonId = 'review_dynamic';
const placementNodeId = 'placement';

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
class ApiLearningRepository
    implements
        LearningRepository,
        EvidenceLearningRepository,
        OfflineLearningSync,
        AbandonableSession {
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
  SessionMode _mode = SessionMode.lesson;
  double? _passThreshold;

  /// Exposed for tests and diagnostics.
  JournalSession? get activeSession => _session;

  @override
  Future<List<Exercise>> loadLesson(String nodeId) async {
    if (nodeId == placementNodeId) return _loadPlacement();
    if (nodeId == mistakeReviewNodeId) return _loadReview();
    _mode = SessionMode.lesson;
    _passThreshold = null;
    await syncPending();
    final journaled = await journal.active();
    if (journaled?.lessonId == reviewLessonId) {
      throw const LearningFailure(
        'Finish your saved review from Practice → Mistakes first.',
      );
    }
    try {
      final course = await _courseId();
      if (journaled != null && journaled.courseId == course) {
        if (journaled.nodeId != nodeId) {
          throw const LearningFailure(
            'Finish your saved lesson before starting another one.',
          );
        }
        final resumed = await _startOrResume(
          course: course,
          lessonId: journaled.lessonId,
          nodeId: nodeId,
          enrollmentRevision: journaled.enrollmentRevision,
          resume: journaled,
        );
        return _activate(resumed);
      }
      final pages = [await learning.getPath(course, limit: 100)];
      final cursors = <String>{};
      while (pages.last.nextCursor != null) {
        final cursor = pages.last.nextCursor!;
        if (!cursors.add(cursor) || pages.length >= 20) {
          throw const LearningFailure(
            'Could not load the complete course path.',
          );
        }
        pages.add(await learning.getPath(course, cursor: cursor, limit: 100));
      }
      final path = wire.Path(
        enrollment: pages.last.enrollment,
        nodes: [for (final page in pages) ...page.nodes],
        asOf: pages.last.asOf,
        nextCursor: null,
      );
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
      if (error.isConflict) {
        final pending = await journal.active();
        if (pending?.sessionId == null) await journal.clearActive();
      }
      if (error.isOffline && journaled != null && journaled.bundle.isNotEmpty) {
        // Offline restart of the journaled lesson: regrade from the bundle.
        return _activate(journaled);
      }
      throw LearningFailure(error.userMessage);
    }
  }

  bool _onlineOnly(JournalSession session) =>
      _mode.isOnlineOnly ||
      session.lessonId == reviewLessonId ||
      session.nodeId == placementNodeId;

  Future<List<Exercise>> _loadPlacement() async {
    _mode = SessionMode.placement;
    _passThreshold = null;
    try {
      var saved = await journal.active();
      final course = await _courseId();
      if (saved != null &&
          (saved.nodeId != placementNodeId || saved.courseId != course)) {
        throw const LearningFailure(
          'Finish your saved lesson before starting a placement test.',
        );
      }
      if (saved?.sessionId case final id?) {
        final server = await learning.getSession(id);
        if (server.mode != 'PLACEMENT' || server.courseId != course) {
          throw const LearningFailure(
            'This saved test does not belong to the current course.',
          );
        }
        if (server.status == 'ACTIVE' || server.status == 'COMPLETED') {
          var current = _reviewJournal(
            server,
            saved!.enrollmentRevision,
            saved.startKey,
            saved.completeKey,
            saved,
          );
          if (server.status == 'ACTIVE') {
            current = await _replayUnsynced(current);
          }
          await _save(current);
          return _activate(current);
        }
        saved = null;
      }
      final replayingStart = saved != null;
      if (saved == null) {
        try {
          await learning.getPath(course);
          throw const LearningFailure(
            'You already have a learning path. Continue your existing course.',
          );
        } on ApiException catch (error) {
          if (!error.isNotFound) rethrow;
        }
        final manifest = await learning.getManifest(course);
        saved = JournalSession(
          nodeId: placementNodeId,
          courseId: course,
          lessonId: manifest.placementBundle.lessonId,
          lessonVersion: manifest.placementBundle.lessonVersion,
          bundleHash: '',
          enrollmentRevision: 0,
          bundle: const {},
          startKey: ids.next(),
          completeKey: ids.next(),
        );
      }
      await _save(saved);
      wire.Session server;
      try {
        server = await learning.startSession(
          wire.SessionRequest(
            courseId: saved.courseId,
            lessonId: saved.lessonId,
            mode: 'PLACEMENT',
            expectedEnrollmentRevision: saved.enrollmentRevision,
          ),
          idempotencyKey: saved.startKey,
        );
      } on ApiException catch (error) {
        final active = error.details['activeSessionId'];
        if (error.code != 'SESSION_CONFLICT' || active is! String) rethrow;
        server = await learning.getSession(active);
      }
      if (replayingStart) {
        server = await learning.getSession(server.sessionId);
      }
      if (server.mode != 'PLACEMENT' ||
          server.courseId != course ||
          server.bundle.exercises.length != 10) {
        throw const LearningFailure(
          'The placement test is unavailable. Please retry.',
        );
      }
      final current = _reviewJournal(
        server,
        saved.enrollmentRevision,
        saved.startKey,
        saved.completeKey,
        saved,
      );
      await _save(current);
      return _activate(current);
    } on ApiException catch (error) {
      throw LearningFailure(error.userMessage);
    }
  }

  Future<List<Exercise>> _loadReview() async {
    _mode = SessionMode.review;
    _passThreshold = null;
    try {
      await syncPending();
      var saved = await journal.active();
      final course = await _courseId();
      if (saved != null &&
          (saved.lessonId != reviewLessonId || saved.courseId != course)) {
        throw const LearningFailure(
          'Finish your current lesson before starting a review.',
        );
      }
      if (saved?.sessionId case final sessionId?) {
        final server = await learning.getSession(sessionId);
        if (server.status == 'ACTIVE' || server.status == 'COMPLETED') {
          var current = _reviewJournal(
            server,
            saved!.enrollmentRevision,
            saved.startKey,
            saved.completeKey,
            saved,
          );
          if (server.status == 'ACTIVE') {
            current = await _replayUnsynced(current);
          }
          await _save(current);
          return _activate(current);
        }
        saved =
            null; // Expired/abandoned reviews start a fresh private snapshot.
      }
      final review = await learning.getReview(courseId: course, limit: 1);
      if (review.items.isEmpty) {
        await journal.clearActive();
        _session = null;
        throw const LearningFailure(
          'Complete a lesson before starting a review.',
        );
      }
      final path = await learning.getPath(course);
      final intent =
          saved ??
          JournalSession(
            nodeId: mistakeReviewNodeId,
            courseId: course,
            lessonId: reviewLessonId,
            lessonVersion: 'review.pending',
            bundleHash: '',
            enrollmentRevision: path.enrollment.revision,
            bundle: const {},
            startKey: ids.next(),
            completeKey: ids.next(),
          );
      // Persist the exact start identity before sending: a killed/lost POST
      // replays the same request rather than creating another active session.
      await _save(intent);
      wire.Session server;
      try {
        server = await learning.startSession(
          wire.SessionRequest(
            courseId: course,
            lessonId: reviewLessonId,
            mode: 'REVIEW',
            expectedEnrollmentRevision: intent.enrollmentRevision,
          ),
          idempotencyKey: intent.startKey,
        );
      } on ApiException catch (error) {
        final active = error.details['activeSessionId'];
        if (error.code != 'SESSION_CONFLICT' || active is! String) rethrow;
        server = await learning.getSession(active);
        if (server.mode != 'REVIEW' || server.courseId != course) {
          await journal.clearActive();
          _session = null;
          throw const LearningFailure(
            'Finish the lesson already open on your account first.',
          );
        }
      }
      final current = _reviewJournal(
        server,
        intent.enrollmentRevision,
        intent.startKey,
        intent.completeKey,
        null,
      );
      await _save(current);
      return _activate(current);
    } on ApiException catch (error) {
      if (error.details['reason'] == 'REVIEW_POOL_EMPTY' ||
          error.code == 'REVISION_CONFLICT') {
        final pending = await journal.active();
        if (pending?.lessonId == reviewLessonId && pending?.sessionId == null) {
          await journal.clearActive();
          _session = null;
        }
      }
      if (error.details['reason'] == 'REVIEW_POOL_EMPTY') {
        throw const LearningFailure(
          'Complete a lesson before starting a review.',
        );
      }
      throw LearningFailure(error.userMessage);
    }
  }

  /// Starts or resumes one of the eight authored session modes. They reuse the
  /// same bundle, answer and completion lifecycle; only their mode, optional
  /// activity hints and gate result differ.
  Future<List<Exercise>> loadAuthored({
    required SessionMode mode,
    required String lessonId,
    String? activityId,
    String? opponentId,
  }) async {
    if (!mode.isAuthored) {
      throw ArgumentError.value(mode, 'mode', 'Not an authored session mode');
    }
    _mode = mode;
    _passThreshold = null;
    try {
      await syncPending();
      final saved = await journal.active();
      final course = await _courseId();
      if (saved != null && saved.courseId == course) {
        if (saved.lessonId != lessonId) {
          throw const LearningFailure(
            'Finish your saved lesson before starting another one.',
          );
        }
        final sessionId = saved.sessionId;
        if (sessionId != null) {
          try {
            final server = await learning.getSession(sessionId);
            if (server.status == 'ACTIVE' || server.status == 'COMPLETED') {
              if (server.mode != mode.wireName ||
                  server.courseId != course ||
                  server.lessonId != lessonId) {
                throw const LearningFailure(
                  'This saved activity no longer matches the session.',
                );
              }
              var current = _reviewJournal(
                server,
                saved.enrollmentRevision,
                saved.startKey,
                saved.completeKey,
                saved,
                nodeId: lessonId,
              );
              if (server.status == 'ACTIVE') {
                current = await _replayUnsynced(current);
              }
              await _save(current);
              return _activate(current);
            }
          } on ApiException catch (error) {
            if (!error.isNotFound) rethrow;
            // Expired or unknown: start a fresh authored attempt below.
          }
        }
      }
      final path = await learning.getPath(course, limit: 1);
      final intent = JournalSession(
        nodeId: lessonId,
        courseId: course,
        lessonId: lessonId,
        lessonVersion: '',
        bundleHash: '',
        enrollmentRevision: path.enrollment.revision,
        bundle: const {},
        startKey: ids.next(),
        completeKey: ids.next(),
      );
      await _save(intent);
      wire.Session server;
      try {
        server = await learning.startSession(
          wire.SessionRequest(
            courseId: course,
            lessonId: lessonId,
            mode: mode.wireName,
            expectedEnrollmentRevision: intent.enrollmentRevision,
            activityId: activityId,
            opponentId: opponentId,
          ),
          idempotencyKey: intent.startKey,
        );
      } on ApiException catch (error) {
        final active = error.details['activeSessionId'];
        if (error.code != 'SESSION_CONFLICT' || active is! String) rethrow;
        server = await learning.getSession(active);
        if (server.mode != mode.wireName ||
            server.courseId != course ||
            server.lessonId != lessonId) {
          throw const LearningFailure(
            'Finish the session already open on your account first.',
          );
        }
      }
      if (server.mode != mode.wireName ||
          server.courseId != course ||
          server.lessonId != lessonId) {
        throw const LearningFailure(
          'This activity is unavailable. Please retry.',
        );
      }
      final current = _reviewJournal(
        server,
        intent.enrollmentRevision,
        intent.startKey,
        intent.completeKey,
        null,
        nodeId: lessonId,
      );
      await _save(current);
      return _activate(current);
    } on ApiException catch (error) {
      throw LearningFailure(error.userMessage);
    }
  }

  JournalSession _reviewJournal(
    wire.Session server,
    int enrollmentRevision,
    String startKey,
    String completeKey,
    JournalSession? saved, {
    String? nodeId,
  }) {
    _passThreshold = server.passThreshold?.toDouble();
    final mapper = LessonWireMapper(
      server.bundle.exercises,
      assets: server.bundle.assets,
    );
    final answers = <JournalAnswer>[];
    for (final history in server.answerHistory) {
      final previous = saved?.answers
          .where(
            (a) =>
                a.exerciseId == history.exerciseId &&
                a.attemptOrdinal == history.attemptOrdinal,
          )
          .firstOrNull;
      answers.add(
        JournalAnswer(
          exerciseId: history.exerciseId,
          attemptOrdinal: history.attemptOrdinal,
          answer: history.answer.toJson(),
          assisted: history.assisted,
          substituted: history.substituted,
          idempotencyKey: previous?.idempotencyKey ?? ids.next(),
          synced: true,
          correct:
              previous?.correct ??
              mapper.gradeLocally(history.exerciseId, history.answer.toJson()),
          expectedRevision: previous?.expectedRevision,
        ),
      );
    }
    for (final answer in saved?.answers ?? <JournalAnswer>[]) {
      if (!answers.any(
        (a) =>
            a.exerciseId == answer.exerciseId &&
            a.attemptOrdinal == answer.attemptOrdinal,
      )) {
        answers.add(answer);
      }
    }
    return JournalSession(
      nodeId: nodeId ?? saved?.nodeId ?? mistakeReviewNodeId,
      courseId: server.courseId,
      lessonId: server.lessonId,
      lessonVersion: server.lessonVersion,
      bundleHash: server.bundle.manifestHash,
      enrollmentRevision: enrollmentRevision,
      bundle: server.bundle.toJson(),
      startKey: startKey,
      completeKey: completeKey,
      sessionId: server.sessionId,
      revision: server.status == 'COMPLETED'
          ? (saved?.revision ?? (server.revision - 1).clamp(0, server.revision))
          : server.revision,
      answers: answers,
    );
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
        if (server.status == 'ACTIVE' || server.status == 'COMPLETED') {
          final restored = _reviewJournal(
            server,
            enrollmentRevision,
            resume!.startKey,
            resume.completeKey,
            resume,
          );
          final replayed = server.status == 'ACTIVE'
              ? await _replayUnsynced(restored)
              : restored;
          await journal.saveActive(replayed);
          return replayed;
        }
      } on ApiException catch (error) {
        if (!error.isNotFound) rethrow;
        // Expired or unknown: start a fresh attempt below.
      }
      resume = null;
    }
    final startKey = resume?.startKey ?? ids.next();
    final intent =
        resume ??
        JournalSession(
          nodeId: nodeId,
          courseId: course,
          lessonId: lessonId,
          lessonVersion: '',
          bundleHash: '',
          enrollmentRevision: enrollmentRevision,
          bundle: const {},
          startKey: startKey,
          completeKey: ids.next(),
        );
    await journal.saveActive(intent);
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
      completeKey: intent.completeKey,
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
          expectedRevision: item.expectedRevision ?? current.revision,
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
    _draft = restoreReviewState(
      session,
      mapper.toDomain(),
      includeProvisional: !_onlineOnly(session),
    );
    if (session.nodeId == placementNodeId) {
      _draft = _draft?.copyWith(placement: true);
    }
    if (session.nodeId == placementNodeId &&
        session.answers
                .where((a) => a.attemptOrdinal == 0 && a.synced)
                .length ==
            bundle.exercises.length) {
      final originals = mapper.toDomain();
      _draft = LessonState(
        stage: LessonStage.feedback,
        exercises: originals,
        index: originals.length - 1,
        nodeId: placementNodeId,
        placement: true,
        attempted: originals.length,
        originalTotal: originals.length,
        originalCorrect: session.answers
            .where((a) => a.attemptOrdinal == 0 && a.correct == true)
            .length,
        correct: session.answers
            .where(
              (a) => a.exerciseId == originals.last.id && a.attemptOrdinal == 0,
            )
            .firstOrNull
            ?.correct,
      );
    }
    _draft = _draft?.copyWith(mode: _mode);
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
    return gradeWithEvidence(
      exercise,
      answer,
      assisted: false,
      substituted: false,
    );
  }

  @override
  Future<bool> gradeWithEvidence(
    Exercise exercise,
    LessonAnswer answer, {
    required bool assisted,
    required bool substituted,
  }) async {
    final session = _session;
    final mapper = _mapper;
    if (session == null || mapper == null) {
      throw const LearningFailure('This lesson isn’t ready yet.');
    }
    final ordinal = (_attempts[exercise.id] ?? 0).clamp(0, 2);
    final wireAnswer = mapper.toWireAnswer(exercise.id, answer);
    final pending = _onlineOnly(session)
        ? session.answers
              .where((a) => a.exerciseId == exercise.id && !a.synced)
              .firstOrNull
        : null;
    final entry =
        pending ??
        JournalAnswer(
          exerciseId: exercise.id,
          attemptOrdinal: ordinal,
          answer: wireAnswer.toJson(),
          assisted: assisted,
          substituted:
              substituted || mapper.substitutedIds.contains(exercise.id),
          idempotencyKey: ids.next(),
          expectedRevision: session.revision,
        );
    _attempts[exercise.id] = entry.attemptOrdinal + 1;
    var journaled = pending == null
        ? session.copyWith(answers: [...session.answers, entry])
        : session;
    await _save(journaled);

    final sessionId = journaled.sessionId;
    if (sessionId != null) {
      try {
        final result = await learning.submitAnswer(
          sessionId,
          wire.AnswerRequest(
            exerciseId: entry.exerciseId,
            attemptOrdinal: entry.attemptOrdinal,
            answer: wire.Answer.fromJson(entry.answer),
            assisted: entry.assisted,
            substituted: entry.substituted,
            expectedRevision: entry.expectedRevision ?? journaled.revision,
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
        if (_onlineOnly(session)) {
          throw LearningFailure(
            error.isOffline
                ? 'Answer saved. Reconnect and retry to send the saved answer.'
                : error.userMessage,
          );
        }
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
  Future<void> abandonSession() async {
    final saved = _session ?? await journal.active();
    if (saved == null) return;
    var current = saved;
    final sessionId = current.sessionId;
    if (sessionId == null) {
      await journal.clearActive();
      _session = null;
      return;
    }
    if (current.abandonKey == null ||
        current.abandonRevision != current.revision) {
      current = current.copyWith(
        abandonKey: ids.next(),
        abandonRevision: current.revision,
      );
      await _save(current);
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await learning.abandonSession(
          sessionId,
          wire.CompleteRequest(expectedRevision: current.abandonRevision!),
          idempotencyKey: current.abandonKey,
        );
        await journal.clearActive();
        _session = null;
        return;
      } on ApiException catch (error) {
        if (error.code == 'SESSION_CONFLICT') {
          // Already completed elsewhere; nothing will resume this journal.
          await journal.clearActive();
          _session = null;
          return;
        }
        if (error.code == 'REVISION_CONFLICT' && attempt == 0) {
          try {
            final server = await learning.getSession(sessionId);
            current = current.copyWith(
              revision: server.revision,
              abandonKey: ids.next(),
              abandonRevision: server.revision,
            );
            await _save(current);
            continue;
          } on ApiException catch (refreshError) {
            throw LearningFailure(refreshError.userMessage);
          }
        }
        // Offline or an unknown outcome: keep the journal so the lesson,
        // including unsent answers, can still resume.
        throw LearningFailure(error.userMessage);
      }
    }
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
    final isPlacement = session.nodeId == placementNodeId;
    final sessionId = session.sessionId;
    if (sessionId != null && session.answers.any((a) => !a.synced)) {
      try {
        session = await _replayUnsynced(session);
        await _save(session);
      } on ApiException catch (error) {
        if (_onlineOnly(session)) {
          throw LearningFailure(error.userMessage);
        }
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
        if (session.nodeId == placementNodeId) {
          await learning.enrollCourse(
            wire.EnrollRequest(
              courseId: session.courseId,
              startPoint: 'placement',
              placementSessionId: wire.JsonPresence.value(sessionId),
            ),
            idempotencyKey: session.startKey,
          );
        }
        await journal.clearActive();
        _session = null;
        final outcomeMode = SessionMode.tryParse(completion.mode) ?? _mode;
        final gate = outcomeMode.isGate;
        final outcome = SessionOutcome(
          mode: outcomeMode,
          passThreshold: _passThreshold,
          passed: completion.passed,
          unlockedNodeId: completion.unlockedNodeId,
        );
        final rewards = isPlacement || gate
            ? null
            : await _creditedRewards(completion);
        return SessionReceipt(
          id: completion.completionId,
          nodeId: nodeId,
          xp: isPlacement || gate ? 0 : rewards?.awardXp ?? 0,
          rewardPending:
              !isPlacement &&
              !gate &&
              completion.rewardStatus == 'pending' &&
              rewards == null,
          accuracy: completion.originalCount == 0
              ? 0
              : completion.originalCorrect / completion.originalCount,
          elapsed: elapsed,
          firstCompletion:
              !isPlacement &&
              !gate &&
              session.lessonId != reviewLessonId &&
              completion.rewardStatus == 'pending',
          guest: guest,
          placement: isPlacement || placement,
          outcome: outcome,
        );
      } on ApiException catch (error) {
        if (!error.isOffline) throw LearningFailure(error.userMessage);
      }
    }
    if (_onlineOnly(session)) {
      throw const LearningFailure(
        'Reconnect to finish this session. Your answers are saved.',
      );
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
    final requestJson = request.toJson();
    final localJournal = journal;
    if (localJournal is AtomicLessonJournal) {
      await localJournal.stageCompletionAndClearActive(requestJson);
    } else {
      await localJournal.enqueueCompletion(requestJson);
      await localJournal.clearActive();
    }
    _session = null;
    return SessionReceipt(
      id: 'offline-$localId',
      rewardPending: true,
      nodeId: nodeId,
      xp: 0,
      accuracy: originalTotal == 0 ? 0 : originalCorrect / originalTotal,
      elapsed: elapsed,
      firstCompletion: false,
      guest: guest,
      placement: placement,
      outcome: SessionOutcome(mode: _mode),
    );
  }

  /// Replays queued offline completions; stops at the first network failure.
  /// Returns how many were accepted (or rejected for good) by the server.
  @override
  Future<int> syncPending() async {
    var settled = 0;
    for (final json in await journal.pendingCompletions()) {
      final operationId = json['operationId']! as String;
      final wire.OfflineCompletionRequest request;
      try {
        request = wire.OfflineCompletionRequest.fromJson(json);
      } on wire.ContractViolation {
        final storage = journal;
        if (storage is! RejectedLessonJournal) break;
        await storage.rejectCompletion(operationId, 'INVALID_LOCAL_COMPLETION');
        settled++;
        continue;
      }
      try {
        await learning.syncOfflineCompletion(
          request,
          idempotencyKey: operationId,
        );
        await journal.removeCompletion(operationId);
        settled++;
      } on ApiException catch (error) {
        if (error.isOffline ||
            error.retryable ||
            error.isUnauthenticated ||
            error.code == 'BAD_RESPONSE' ||
            error.code.startsWith('HTTP_') ||
            error.statusCode == null ||
            error.statusCode == 403 ||
            error.statusCode == 429 ||
            error.statusCode! >= 500) {
          break;
        }
        final storage = journal;
        if (storage is! RejectedLessonJournal) break;
        await storage.rejectCompletion(operationId, error.code);
        settled++;
      } on wire.ContractViolation {
        // A malformed success receipt can follow a committed request. Preserve
        // the operation and retry its original key instead of rejecting it.
        break;
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
      if (node.nodeId == nodeId && node.state != 'locked') return node;
    }
    final unitMatch = RegExp(r'^section-(\d+)-unit-(\d+)-review-(\d+)$')
        .firstMatch(nodeId);
    final sections = <String, Map<String, List<wire.Node>>>{};
    for (final node in nodes) {
      sections
          .putIfAbsent(node.sectionId, () => {})
          .putIfAbsent(node.unitId, () => [])
          .add(node);
    }
    final ordinal = int.tryParse(
      RegExp(r'^node-(\d+)$').firstMatch(nodeId)?.group(1) ?? '',
    );
    final section = unitMatch == null ? 0 : int.parse(unitMatch.group(1)!) - 1;
    final unit = unitMatch == null ? 0 : int.parse(unitMatch.group(2)!) - 1;
    final index = unitMatch == null ? ordinal : int.parse(unitMatch.group(3)!);
    final candidates = section < 0 || unit < 0
        ? null
        : sections.values
              .elementAtOrNull(section)
              ?.values
              .elementAtOrNull(unit);
    if (index != null &&
        index >= 0 &&
        candidates != null &&
        index < candidates.length) {
      final node = candidates[index];
      if (node.state != 'locked' && node.lessonIds.isNotEmpty) return node;
    }
    throw const LearningFailure('This lesson is locked or unavailable.');
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
