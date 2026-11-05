import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One answer recorded in the local lesson journal (P5-FE-001).
///
/// [idempotencyKey] is generated once when the learner checks the answer and
/// reused for every replay, so a crash between send and acknowledgement never
/// double-submits. [synced] flips when the server acknowledged it.
final class JournalAnswer {
  const JournalAnswer({
    required this.exerciseId,
    required this.attemptOrdinal,
    required this.answer,
    required this.assisted,
    required this.substituted,
    required this.idempotencyKey,
    this.synced = false,
    this.correct,
    this.expectedRevision,
  });

  factory JournalAnswer.fromJson(Map<String, Object?> json) => JournalAnswer(
    exerciseId: json['exerciseId']! as String,
    attemptOrdinal: (json['attemptOrdinal']! as num).toInt(),
    answer: Map<String, Object?>.from(json['answer']! as Map),
    assisted: json['assisted']! as bool,
    substituted: json['substituted']! as bool,
    idempotencyKey: json['idempotencyKey']! as String,
    synced: json['synced'] as bool? ?? false,
    correct: json['correct'] as bool?,
    expectedRevision: (json['expectedRevision'] as num?)?.toInt(),
  );

  final String exerciseId;
  final int attemptOrdinal;

  /// Wire `Answer` JSON (OpenAPI union, discriminated by `kind`).
  final Map<String, Object?> answer;
  final bool assisted;
  final bool substituted;
  final String idempotencyKey;
  final bool synced;

  /// Last known grade (provisional when graded offline).
  final bool? correct;
  final int? expectedRevision;

  JournalAnswer copyWith({bool? synced, bool? correct}) => JournalAnswer(
    exerciseId: exerciseId,
    attemptOrdinal: attemptOrdinal,
    answer: answer,
    assisted: assisted,
    substituted: substituted,
    idempotencyKey: idempotencyKey,
    synced: synced ?? this.synced,
    correct: correct ?? this.correct,
    expectedRevision: expectedRevision,
  );

  /// Wire `OfflineAnswer` JSON.
  Map<String, Object?> toOfflineAnswerJson() => <String, Object?>{
    'exerciseId': exerciseId,
    'attemptOrdinal': attemptOrdinal,
    'answer': answer,
    'assisted': assisted,
    'substituted': substituted,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    ...toOfflineAnswerJson(),
    'idempotencyKey': idempotencyKey,
    'synced': synced,
    'correct': correct,
    'expectedRevision': expectedRevision,
  };
}

/// The lesson currently in progress, persisted after every state change so an
/// app kill can resume (server session) or regrade offline (cached bundle).
final class JournalSession {
  const JournalSession({
    required this.nodeId,
    required this.courseId,
    required this.lessonId,
    required this.lessonVersion,
    required this.bundleHash,
    required this.enrollmentRevision,
    required this.bundle,
    required this.startKey,
    required this.completeKey,
    this.sessionId,
    this.revision = 0,
    this.abandonKey,
    this.abandonRevision,
    this.answers = const <JournalAnswer>[],
  });

  factory JournalSession.fromJson(Map<String, Object?> json) => JournalSession(
    nodeId: json['nodeId']! as String,
    courseId: json['courseId']! as String,
    lessonId: json['lessonId']! as String,
    lessonVersion: json['lessonVersion']! as String,
    bundleHash: json['bundleHash']! as String,
    enrollmentRevision: (json['enrollmentRevision']! as num).toInt(),
    bundle: Map<String, Object?>.from(json['bundle']! as Map),
    startKey: json['startKey']! as String,
    completeKey: json['completeKey']! as String,
    sessionId: json['sessionId'] as String?,
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    abandonKey: json['abandonKey'] as String?,
    abandonRevision: (json['abandonRevision'] as num?)?.toInt(),
    answers: [
      for (final item in (json['answers'] as List<Object?>? ?? const []))
        JournalAnswer.fromJson(Map<String, Object?>.from(item! as Map)),
    ],
  );

  final String nodeId;
  final String courseId;
  final String lessonId;
  final String lessonVersion;

  /// `manifestHash` of the bundle (offline completions must name it).
  final String bundleHash;
  final int enrollmentRevision;

  /// Wire `LessonBundle` JSON kept for offline regrade.
  final Map<String, Object?> bundle;

  /// Idempotency key of `startSession` for this lesson attempt.
  final String startKey;

  /// Idempotency key of `completeSession` / offline `operationId`.
  final String completeKey;

  /// Server session; null when the lesson started offline.
  final String? sessionId;
  final int revision;
  final String? abandonKey;
  final int? abandonRevision;
  final List<JournalAnswer> answers;

  bool get offline => sessionId == null;

  JournalSession copyWith({
    String? sessionId,
    int? revision,
    String? abandonKey,
    int? abandonRevision,
    List<JournalAnswer>? answers,
  }) => JournalSession(
    nodeId: nodeId,
    courseId: courseId,
    lessonId: lessonId,
    lessonVersion: lessonVersion,
    bundleHash: bundleHash,
    enrollmentRevision: enrollmentRevision,
    bundle: bundle,
    startKey: startKey,
    completeKey: completeKey,
    sessionId: sessionId ?? this.sessionId,
    revision: revision ?? this.revision,
    abandonKey: abandonKey ?? this.abandonKey,
    abandonRevision: abandonRevision ?? this.abandonRevision,
    answers: answers ?? this.answers,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'nodeId': nodeId,
    'courseId': courseId,
    'lessonId': lessonId,
    'lessonVersion': lessonVersion,
    'bundleHash': bundleHash,
    'enrollmentRevision': enrollmentRevision,
    'bundle': bundle,
    'startKey': startKey,
    'completeKey': completeKey,
    'sessionId': sessionId,
    'revision': revision,
    if (abandonKey != null) 'abandonKey': abandonKey,
    if (abandonRevision != null) 'abandonRevision': abandonRevision,
    'answers': [for (final answer in answers) answer.toJson()],
  };
}

/// Durable local journal for lessons and queued offline completions.
///
/// API mode uses the account-scoped Drift adapter. Preview keeps its existing
/// preferences adapter; repositories depend only on this port.
abstract interface class LessonJournal {
  Future<JournalSession?> active();
  Future<void> saveActive(JournalSession session);
  Future<void> clearActive();

  /// Queued wire `OfflineCompletionRequest` JSON objects, oldest first.
  Future<List<Map<String, Object?>>> pendingCompletions();
  Future<void> enqueueCompletion(Map<String, Object?> request);
  Future<void> removeCompletion(String operationId);

  /// Wipes everything (sign-out / account switch: no cross-user leakage).
  Future<void> clear();
}

abstract interface class AtomicLessonJournal implements LessonJournal {
  Future<void> stageCompletionAndClearActive(Map<String, Object?> request);
}

abstract interface class ClosableLessonJournal implements LessonJournal {
  Future<void> close();
}

final class RejectedLessonCompletion {
  const RejectedLessonCompletion({
    required this.operationId,
    required this.reasonCode,
    required this.payload,
  });
  final String operationId, reasonCode;
  final Map<String, Object?> payload;
}

/// Keeps permanently rejected answers for review without replaying them forever.
abstract interface class RejectedLessonJournal implements LessonJournal {
  Future<void> rejectCompletion(String operationId, String reasonCode);
  Future<List<RejectedLessonCompletion>> rejectedCompletions();
}

final class JournalFailure implements Exception {
  const JournalFailure(this.code);

  static const closed = 'JOURNAL_CLOSED';
  static const accountRequired = 'JOURNAL_ACCOUNT_REQUIRED';
  static const operationConflict = 'JOURNAL_OPERATION_CONFLICT';
  static const queueCountLimit = 'JOURNAL_QUEUE_COUNT_LIMIT';
  static const queueSizeLimit = 'JOURNAL_QUEUE_SIZE_LIMIT';
  static const corrupt = 'JOURNAL_CORRUPT';
  static const legacyCorrupt = 'JOURNAL_LEGACY_CORRUPT';
  static const storageUnavailable = 'JOURNAL_STORAGE_UNAVAILABLE';

  final String code;

  @override
  String toString() => 'JournalFailure($code)';
}

final class UnavailableLessonJournal implements AtomicLessonJournal {
  const UnavailableLessonJournal(this.code);

  final String code;

  Never _fail() => throw JournalFailure(code);

  @override
  Future<JournalSession?> active() async => _fail();

  @override
  Future<void> clear() async => _fail();

  @override
  Future<void> clearActive() async => _fail();

  @override
  Future<void> enqueueCompletion(Map<String, Object?> request) async => _fail();

  @override
  Future<List<Map<String, Object?>>> pendingCompletions() async => _fail();

  @override
  Future<void> removeCompletion(String operationId) async => _fail();

  @override
  Future<void> saveActive(JournalSession session) async => _fail();

  @override
  Future<void> stageCompletionAndClearActive(
    Map<String, Object?> request,
  ) async => _fail();
}

final class InMemoryLessonJournal
    implements AtomicLessonJournal, RejectedLessonJournal {
  JournalSession? _active;
  final List<Map<String, Object?>> _pending = [];
  final List<RejectedLessonCompletion> _rejected = [];

  @override
  Future<JournalSession?> active() async => _active;

  @override
  Future<void> saveActive(JournalSession session) async => _active = session;

  @override
  Future<void> clearActive() async => _active = null;

  @override
  Future<List<Map<String, Object?>>> pendingCompletions() async =>
      List.unmodifiable(_pending);

  @override
  Future<void> enqueueCompletion(Map<String, Object?> request) async {
    final id = request['operationId'];
    final existing = [
      ..._pending,
      for (final row in _rejected) row.payload,
    ].where((item) => item['operationId'] == id);
    if (existing.isNotEmpty) {
      if (jsonEncode(existing.single) != jsonEncode(request)) {
        throw const JournalFailure(JournalFailure.operationConflict);
      }
      return;
    }
    _pending.add(request);
  }

  @override
  Future<void> stageCompletionAndClearActive(
    Map<String, Object?> request,
  ) async {
    await enqueueCompletion(request);
    _active = null;
  }

  @override
  Future<void> removeCompletion(String operationId) async =>
      _pending.removeWhere((item) => item['operationId'] == operationId);

  @override
  Future<void> rejectCompletion(String operationId, String reasonCode) async {
    final rows = _pending.where((item) => item['operationId'] == operationId);
    if (rows.isEmpty) return;
    final payload = Map<String, Object?>.from(
      jsonDecode(jsonEncode(rows.single)) as Map,
    );
    _rejected.add(
      RejectedLessonCompletion(
        operationId: operationId,
        reasonCode: reasonCode,
        payload: payload,
      ),
    );
    await removeCompletion(operationId);
  }

  @override
  Future<List<RejectedLessonCompletion>> rejectedCompletions() async =>
      List.unmodifiable(_rejected);

  @override
  Future<void> clear() async {
    _active = null;
    _pending.clear();
    _rejected.clear();
  }
}

/// Shared-preferences journal namespaced by user id.
final class PreferencesLessonJournal implements LessonJournal {
  PreferencesLessonJournal({
    required String namespace,
    SharedPreferencesAsync? preferences,
  }) : _activeKey = 'journal.lesson.active.v1.$namespace',
       _pendingKey = 'journal.lesson.pending.v1.$namespace',
       _preferences = preferences; // ignore: prefer_initializing_formals

  final String _activeKey;
  final String _pendingKey;
  SharedPreferencesAsync? _preferences;
  final InMemoryLessonJournal _fallback = InMemoryLessonJournal();
  bool _pluginMissing = false;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  Future<String?> _read(String key) async {
    if (_pluginMissing) return null;
    try {
      return await _store.getString(key);
    } on MissingPluginException {
      _pluginMissing = true;
      return null;
    }
  }

  Future<void> _write(String key, String? value) async {
    if (_pluginMissing) return;
    try {
      if (value == null) {
        await _store.remove(key);
      } else {
        await _store.setString(key, value);
      }
    } on MissingPluginException {
      _pluginMissing = true;
    }
  }

  @override
  Future<JournalSession?> active() async {
    final raw = await _read(_activeKey);
    if (_pluginMissing) return _fallback.active();
    if (raw == null) return null;
    try {
      return JournalSession.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      await _write(_activeKey, null);
      return null;
    }
  }

  @override
  Future<void> saveActive(JournalSession session) async {
    await _fallback.saveActive(session);
    await _write(_activeKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clearActive() async {
    await _fallback.clearActive();
    await _write(_activeKey, null);
  }

  @override
  Future<List<Map<String, Object?>>> pendingCompletions() async {
    final raw = await _read(_pendingKey);
    if (_pluginMissing) return _fallback.pendingCompletions();
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List<Object?>)
          Map<String, Object?>.from(item! as Map),
      ];
    } on Object {
      await _write(_pendingKey, null);
      return const [];
    }
  }

  @override
  Future<void> enqueueCompletion(Map<String, Object?> request) async {
    await _fallback.enqueueCompletion(request);
    final items = [...await pendingCompletions()];
    if (items.any((item) => item['operationId'] == request['operationId'])) {
      return;
    }
    items.add(request);
    await _write(_pendingKey, jsonEncode(items));
  }

  @override
  Future<void> removeCompletion(String operationId) async {
    await _fallback.removeCompletion(operationId);
    final items = [...await pendingCompletions()]
      ..removeWhere((item) => item['operationId'] == operationId);
    await _write(_pendingKey, items.isEmpty ? null : jsonEncode(items));
  }

  @override
  Future<void> clear() async {
    await _fallback.clear();
    await _write(_activeKey, null);
    await _write(_pendingKey, null);
  }
}
