import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lesson_journal.dart';

abstract interface class LegacyLessonJournalSource {
  Future<String?> readActive();
  Future<String?> readPending();
}

final class PreferencesLegacyLessonJournalSource
    implements LegacyLessonJournalSource {
  PreferencesLegacyLessonJournalSource({
    required String namespace,
    SharedPreferencesAsync? preferences,
  }) : _activeKey = 'journal.lesson.active.v1.$namespace',
       _pendingKey = 'journal.lesson.pending.v1.$namespace',
       _preferences = preferences ?? SharedPreferencesAsync();

  final String _activeKey;
  final String _pendingKey;
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readActive() => _read(_activeKey);

  @override
  Future<String?> readPending() => _read(_pendingKey);

  Future<String?> _read(String key) async {
    try {
      return await _preferences.getString(key);
    } on MissingPluginException {
      throw const JournalFailure(JournalFailure.storageUnavailable);
    }
  }
}

final class DriftLessonJournal
    implements
        AtomicLessonJournal,
        ClosableLessonJournal,
        RejectedLessonJournal {
  DriftLessonJournal({
    required String namespace,
    required QueryExecutor executor,
    this.legacy,
    this.maxOperations = 500,
    this.maxMetadataBytes = 10 * 1024 * 1024,
  }) : _namespace = namespace,
       _database = _LessonJournalDatabase(executor) {
    if (namespace.isEmpty) {
      throw const JournalFailure(JournalFailure.accountRequired);
    }
  }

  final String _namespace;
  final LegacyLessonJournalSource? legacy;
  final _LessonJournalDatabase _database;
  final int maxOperations;
  final int maxMetadataBytes;
  Future<void> _tail = Future<void>.value();
  bool _migrated = false;
  bool _closed = false;

  Future<T> _run<T>(Future<T> Function() action) {
    if (_closed) {
      return Future<T>.error(const JournalFailure(JournalFailure.closed));
    }
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        _guardOpen();
        await _ensureMigrated();
        _guardOpen();
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(
          error is JournalFailure
              ? error
              : const JournalFailure(JournalFailure.storageUnavailable),
          stack,
        );
      }
    });
    return result.future;
  }

  void _guardOpen() {
    if (_closed) throw const JournalFailure(JournalFailure.closed);
  }

  Future<void> _ensureMigrated() async {
    if (_migrated) return;
    final marker = await _database
        .customSelect(
          'SELECT 1 FROM lesson_journal_migrations WHERE namespace = ?',
          variables: [Variable.withString(_namespace)],
        )
        .getSingleOrNull();
    if (marker != null) {
      _migrated = true;
      return;
    }

    final legacy = this.legacy;
    JournalSession? active;
    var pending = const <Map<String, Object?>>[];
    if (legacy != null) {
      final activeRaw = await legacy.readActive();
      final pendingRaw = await legacy.readPending();
      try {
        if (activeRaw != null) active = _decodeSession(activeRaw);
        if (pendingRaw != null) pending = _decodePendingList(pendingRaw);
        _validateBatch(pending);
      } on JournalFailure catch (error) {
        if (error.code == JournalFailure.queueCountLimit ||
            error.code == JournalFailure.queueSizeLimit ||
            error.code == JournalFailure.legacyCorrupt) {
          rethrow;
        }
        throw const JournalFailure(JournalFailure.legacyCorrupt);
      } on Object {
        throw const JournalFailure(JournalFailure.legacyCorrupt);
      }
    }
    _guardOpen();
    await _database.transaction(() async {
      if (active != null) await _writeActive(active);
      for (final request in pending) {
        await _insertIfNew(request, enforceLimits: true);
      }
      await _database.customStatement(
        'INSERT INTO lesson_journal_migrations(namespace) VALUES (?)',
        [_namespace],
      );
    });
    _migrated = true;
  }

  @override
  Future<JournalSession?> active() => _run(() async {
    final row = await _database
        .customSelect(
          'SELECT payload, payload_sha256 FROM lesson_active_sessions '
          'WHERE namespace = ?',
          variables: [Variable.withString(_namespace)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    try {
      final payload = row.read<String>('payload');
      if (_digest(payload) != row.read<String>('payload_sha256')) {
        throw const JournalFailure(JournalFailure.corrupt);
      }
      return _decodeSession(payload);
    } on Object {
      throw const JournalFailure(JournalFailure.corrupt);
    }
  });

  @override
  Future<void> saveActive(JournalSession session) =>
      _run(() => _writeActive(session));

  Future<void> _writeActive(JournalSession session) {
    final payload = _canonicalJson(session.toJson());
    return _database.customStatement(
      'INSERT INTO lesson_active_sessions('
      'namespace, payload, payload_sha256) VALUES (?, ?, ?) '
      'ON CONFLICT(namespace) DO UPDATE SET '
      'payload = excluded.payload, payload_sha256 = excluded.payload_sha256',
      [_namespace, payload, _digest(payload)],
    );
  }

  @override
  Future<void> clearActive() => _run(
    () => _database.customStatement(
      'DELETE FROM lesson_active_sessions WHERE namespace = ?',
      [_namespace],
    ),
  );

  @override
  Future<List<Map<String, Object?>>> pendingCompletions() => _run(() async {
    final rows = await _database
        .customSelect(
          'SELECT payload, payload_sha256 FROM lesson_pending_completions '
          'WHERE namespace = ? ORDER BY sequence ASC',
          variables: [Variable.withString(_namespace)],
        )
        .get();
    try {
      return List.unmodifiable([
        for (final row in rows)
          if (_digest(row.read<String>('payload')) ==
              row.read<String>('payload_sha256'))
            _decodeRequest(row.read<String>('payload'))
          else
            throw const JournalFailure(JournalFailure.corrupt),
      ]);
    } on Object {
      throw const JournalFailure(JournalFailure.corrupt);
    }
  });

  @override
  Future<void> enqueueCompletion(Map<String, Object?> request) =>
      _run(() => _database.transaction(() => _insertIfNew(request)));

  @override
  Future<void> stageCompletionAndClearActive(Map<String, Object?> request) =>
      _run(
        () => _database.transaction(() async {
          await _insertIfNew(request);
          await _database.customStatement(
            'DELETE FROM lesson_active_sessions WHERE namespace = ?',
            [_namespace],
          );
        }),
      );

  Future<void> _insertIfNew(
    Map<String, Object?> request, {
    bool enforceLimits = true,
  }) async {
    final canonical = _canonicalJson(request);
    final decoded = _decodeRequest(canonical);
    final operationId = decoded['operationId']! as String;
    final digest = _digest(canonical);
    final existing = await _database
        .customSelect(
          'SELECT payload_sha256 FROM ('
          'SELECT namespace, operation_id, payload_sha256 FROM lesson_pending_completions '
          'UNION ALL SELECT namespace, operation_id, payload_sha256 FROM lesson_rejected_completions'
          ') WHERE namespace = ? AND operation_id = ?',
          variables: [
            Variable.withString(_namespace),
            Variable.withString(operationId),
          ],
        )
        .getSingleOrNull();
    if (existing != null) {
      if (existing.read<String>('payload_sha256') != digest) {
        throw const JournalFailure(JournalFailure.operationConflict);
      }
      return;
    }

    final bytes = utf8.encode(canonical).length;
    if (enforceLimits) {
      final budget = await _database
          .customSelect(
            'SELECT COUNT(*) AS operation_count, '
            'COALESCE(SUM(metadata_bytes), 0) AS metadata_total '
            'FROM (SELECT metadata_bytes FROM lesson_pending_completions WHERE namespace = ? '
            'UNION ALL SELECT metadata_bytes FROM lesson_rejected_completions WHERE namespace = ?)',
            variables: [
              Variable.withString(_namespace),
              Variable.withString(_namespace),
            ],
          )
          .getSingle();
      if (budget.read<int>('operation_count') >= maxOperations) {
        throw const JournalFailure(JournalFailure.queueCountLimit);
      }
      if (budget.read<int>('metadata_total') + bytes > maxMetadataBytes) {
        throw const JournalFailure(JournalFailure.queueSizeLimit);
      }
    }
    await _database.customStatement(
      'INSERT INTO lesson_pending_completions('
      'namespace, operation_id, payload, payload_sha256, metadata_bytes'
      ') VALUES (?, ?, ?, ?, ?)',
      [_namespace, operationId, canonical, digest, bytes],
    );
  }

  void _validateBatch(List<Map<String, Object?>> pending) {
    final seen = <String, String>{};
    var bytes = 0;
    for (final request in pending) {
      final canonical = _canonicalJson(request);
      final decoded = _decodeRequest(canonical);
      final operationId = decoded['operationId']! as String;
      final digest = _digest(canonical);
      final previous = seen[operationId];
      if (previous != null && previous != digest) {
        throw const JournalFailure(JournalFailure.legacyCorrupt);
      }
      seen[operationId] = digest;
      if (previous == null) bytes += utf8.encode(canonical).length;
    }
    if (seen.length > maxOperations) {
      throw const JournalFailure(JournalFailure.queueCountLimit);
    }
    if (bytes > maxMetadataBytes) {
      throw const JournalFailure(JournalFailure.queueSizeLimit);
    }
  }

  @override
  Future<void> removeCompletion(String operationId) => _run(
    () => _database.customStatement(
      'DELETE FROM lesson_pending_completions '
      'WHERE namespace = ? AND operation_id = ?',
      [_namespace, operationId],
    ),
  );

  @override
  Future<void> rejectCompletion(String operationId, String reasonCode) => _run(
    () => _database.transaction(() async {
      final row = await _database
          .customSelect(
            'SELECT payload, payload_sha256 FROM lesson_pending_completions WHERE namespace = ? AND operation_id = ?',
            variables: [
              Variable.withString(_namespace),
              Variable.withString(operationId),
            ],
          )
          .getSingleOrNull();
      if (row == null) return;
      final payload = row.read<String>('payload');
      if (_digest(payload) != row.read<String>('payload_sha256')) {
        throw const JournalFailure(JournalFailure.corrupt);
      }
      _decodeRequest(payload);
      final reason = RegExp(r'^[A-Z][A-Z0-9_]{0,63}$').hasMatch(reasonCode)
          ? reasonCode
          : 'OFFLINE_COMPLETION_REJECTED';
      await _database.customStatement(
        'INSERT INTO lesson_rejected_completions(namespace, operation_id, payload, payload_sha256, metadata_bytes, sequence, reason_code) '
        'SELECT namespace, operation_id, payload, payload_sha256, metadata_bytes, sequence, ? FROM lesson_pending_completions WHERE namespace = ? AND operation_id = ?',
        [reason, _namespace, operationId],
      );
      await _database.customStatement(
        'DELETE FROM lesson_pending_completions WHERE namespace = ? AND operation_id = ?',
        [_namespace, operationId],
      );
    }),
  );

  @override
  Future<List<RejectedLessonCompletion>> rejectedCompletions() =>
      _run(() async {
        final rows = await _database
            .customSelect(
              'SELECT operation_id, payload, payload_sha256, reason_code FROM lesson_rejected_completions WHERE namespace = ? ORDER BY sequence ASC',
              variables: [Variable.withString(_namespace)],
            )
            .get();
        return List.unmodifiable([
          for (final row in rows)
            if (_digest(row.read<String>('payload')) ==
                row.read<String>('payload_sha256'))
              RejectedLessonCompletion(
                operationId: row.read<String>('operation_id'),
                reasonCode: row.read<String>('reason_code'),
                payload: _decodeRequest(row.read<String>('payload')),
              )
            else
              throw const JournalFailure(JournalFailure.corrupt),
        ]);
      });

  @override
  Future<void> clear() => _run(
    () => _database.transaction(() async {
      await _database.customStatement(
        'DELETE FROM lesson_active_sessions WHERE namespace = ?',
        [_namespace],
      );
      await _database.customStatement(
        'DELETE FROM lesson_pending_completions WHERE namespace = ?',
        [_namespace],
      );
      await _database.customStatement(
        'DELETE FROM lesson_rejected_completions WHERE namespace = ?',
        [_namespace],
      );
    }),
  );

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _tail;
    await _database.close();
  }

  static JournalSession _decodeSession(String raw) => JournalSession.fromJson(
    Map<String, Object?>.from(jsonDecode(raw) as Map),
  );

  static List<Map<String, Object?>> _decodePendingList(String raw) => [
    for (final item in jsonDecode(raw) as List<Object?>)
      _decodeRequest(_canonicalJson(item)),
  ];

  static Map<String, Object?> _decodeRequest(String raw) {
    final decoded = Map<String, Object?>.from(jsonDecode(raw) as Map);
    final operationId = decoded['operationId'];
    if (operationId is! String || operationId.isEmpty) {
      throw const JournalFailure(JournalFailure.corrupt);
    }
    return decoded;
  }

  static String _canonicalJson(Object? value) => jsonEncode(_canonical(value));

  static String _digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const JournalFailure(JournalFailure.corrupt);
        }
        sorted[entry.key as String] = _canonical(entry.value);
      }
      return sorted;
    }
    if (value is List) return [for (final item in value) _canonical(item)];
    if (value is double && !value.isFinite) {
      throw const JournalFailure(JournalFailure.corrupt);
    }
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    throw const JournalFailure(JournalFailure.corrupt);
  }
}

final class _LessonJournalDatabase extends GeneratedDatabase {
  _LessonJournalDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (_, from, to) async {
      if (from < 2) await _createRejectedTable();
    },
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE lesson_active_sessions ('
        'namespace TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL, '
        'payload_sha256 TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE lesson_pending_completions ('
        'sequence INTEGER PRIMARY KEY AUTOINCREMENT, '
        'namespace TEXT NOT NULL, operation_id TEXT NOT NULL, '
        'payload TEXT NOT NULL, payload_sha256 TEXT NOT NULL, '
        'metadata_bytes INTEGER NOT NULL, '
        'UNIQUE(namespace, operation_id))',
      );
      await customStatement(
        'CREATE INDEX lesson_pending_order '
        'ON lesson_pending_completions(namespace, sequence)',
      );
      await customStatement(
        'CREATE TABLE lesson_journal_migrations ('
        'namespace TEXT PRIMARY KEY NOT NULL)',
      );
      await _createRejectedTable();
    },
  );

  Future<void> _createRejectedTable() => customStatement(
    'CREATE TABLE lesson_rejected_completions ('
    'namespace TEXT NOT NULL, operation_id TEXT NOT NULL, payload TEXT NOT NULL, '
    'payload_sha256 TEXT NOT NULL, metadata_bytes INTEGER NOT NULL, '
    'sequence INTEGER NOT NULL, reason_code TEXT NOT NULL, PRIMARY KEY(namespace, operation_id))',
  );
}
