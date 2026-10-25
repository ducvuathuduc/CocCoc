import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/cache/drift_lesson_journal.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frozen v1 file fixture. Upgrading it must preserve the original answer bytes.
class _VersionOne extends GeneratedDatabase {
  _VersionOne(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE lesson_active_sessions(namespace TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL, payload_sha256 TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE lesson_pending_completions(sequence INTEGER PRIMARY KEY AUTOINCREMENT, namespace TEXT NOT NULL, operation_id TEXT NOT NULL, payload TEXT NOT NULL, payload_sha256 TEXT NOT NULL, metadata_bytes INTEGER NOT NULL, UNIQUE(namespace, operation_id))',
      );
      await customStatement(
        'CREATE TABLE lesson_journal_migrations(namespace TEXT PRIMARY KEY NOT NULL)',
      );
    },
  );
}

void main() {
  test(
    'v1 to v2 upgrade preserves queued answers before durable rejection',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'coc-journal-upgrade-',
      );
      final file = File('${temp.path}/journal.sqlite');
      final payload = jsonEncode({
        'operationId': 'old-op',
        'lessonId': 'old-lesson',
        'answers': [
          {'exerciseId': 'e1', 'answer': 'original answer'},
        ],
      });
      final old = _VersionOne(NativeDatabase(file));
      await old.customStatement(
        'INSERT INTO lesson_journal_migrations(namespace) VALUES (?)',
        ['a'],
      );
      await old.customStatement(
        'INSERT INTO lesson_pending_completions(namespace, operation_id, payload, payload_sha256, metadata_bytes) VALUES (?, ?, ?, ?, ?)',
        [
          'a',
          'old-op',
          payload,
          sha256.convert(utf8.encode(payload)).toString(),
          utf8.encode(payload).length,
        ],
      );
      await old.close();

      final upgraded = DriftLessonJournal(
        namespace: 'a',
        executor: NativeDatabase(file),
      );
      try {
        expect(
          (await upgraded.pendingCompletions()).single,
          jsonDecode(payload),
        );
        await upgraded.rejectCompletion('old-op', 'CONTENT_STALE');
      } finally {
        await upgraded.close();
      }
      final reopened = DriftLessonJournal(
        namespace: 'a',
        executor: NativeDatabase(file),
      );
      try {
        expect(await reopened.pendingCompletions(), isEmpty);
        final rejected = (await reopened.rejectedCompletions()).single;
        expect(rejected.payload, jsonDecode(payload));
        expect(rejected.reasonCode, 'CONTENT_STALE');
      } finally {
        await reopened.close();
        await temp.delete(recursive: true);
      }
    },
  );
}
