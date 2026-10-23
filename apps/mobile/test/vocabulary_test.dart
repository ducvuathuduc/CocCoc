import 'package:flutter_test/flutter_test.dart';

import 'package:cocenglish/features/vocabulary/data/notebook_repository.dart';
import 'package:cocenglish/features/vocabulary/domain/vocabulary_card.dart';
import 'package:cocenglish/features/vocabulary/application/notebook_controller.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21, 12);
  VocabularyCard card() =>
      VocabularyCard.create('Hello', 'Xin chào', 'Hello, Sam!', now);
  test(
    'scope keys isolate accounts, guest, mode and course without collisions',
    () {
      expect({
        notebookStorageKey('demo', null, 'en'),
        notebookStorageKey('demo', 'guest', 'en'),
        notebookStorageKey('api', null, 'en'),
        notebookStorageKey('demo', null, 'fr'),
        notebookStorageKey('demo', 'a.b', 'c'),
        notebookStorageKey('demo', 'a', 'b.c'),
      }, hasLength(6));
    },
  );
  test('due boundary and meaning match preserve accents', () {
    final value = card();
    expect(value.isDue(now.subtract(const Duration(microseconds: 1))), false);
    expect(value.isDue(now), true);
    expect(value.matchesMeaning('  XIN   CHÀO '), true);
    expect(value.matchesMeaning('xin chao'), false);
    expect(
      () => VocabularyCard.create('', 'meaning', '', now),
      throwsArgumentError,
    );
  });
  test('correct advances through capped intervals; wrong and hint reset', () {
    var value = card();
    for (final days in [1, 3, 7, 14, 30, 30]) {
      final at = value.dueAt;
      value = value.review(at, correct: true, assisted: false);
      expect(value.dueAt, DateTime.utc(at.year, at.month, at.day + days));
    }
    expect(value.stage, 4);
    final wrong = value.review(value.dueAt, correct: false, assisted: false);
    expect(wrong.stage, 0);
    final hinted = value.review(value.dueAt, correct: true, assisted: true);
    expect(hinted.stage, 0);
    expect(
      hinted.dueAt
          .difference(
            DateTime.utc(value.dueAt.year, value.dueAt.month, value.dueAt.day),
          )
          .inDays,
      1,
    );
  });
  test('early and duplicate review cannot advance schedule', () {
    final value = card().review(now, correct: true, assisted: false);
    expect(
      () => value.review(now, correct: true, assisted: false),
      throwsStateError,
    );
  });
  test('save deduplicates normalized terms and survives restart', () async {
    String? disk;
    final repo = NotebookRepository(
      read: () async => disk,
      write: (v) async {
        disk = v;
      },
    );
    await repo.save(card());
    await repo.save(VocabularyCard.create('  HELLO ', 'Khác', '', now));
    final restarted = NotebookRepository(
      read: () async => disk,
      write: (v) async {
        disk = v;
      },
    );
    final restored = await restarted.load();
    expect(restored.length, 1);
    expect(restored.single.meaning, 'Xin chào');
    await repo.review(restored.single.id, now, correct: true, assisted: false);
    expect((await repo.load()).single.stage, 1);
    await expectLater(
      repo.review(restored.single.id, now, correct: true, assisted: false),
      throwsStateError,
    );
    await repo.remove(restored.single.id);
    expect(await repo.load(), isEmpty);
  });
  test(
    'write failures surface and corrupt data is never overwritten',
    () async {
      final repo = NotebookRepository(
        read: () async => null,
        write: (_) async => throw StateError('disk'),
      );
      await expectLater(repo.save(card()), throwsStateError);
      var written = false;
      final corrupt = NotebookRepository(
        read: () async => '{broken',
        write: (_) async {
          written = true;
        },
      );
      await expectLater(corrupt.save(card()), throwsFormatException);
      expect(written, false);
    },
  );
  test('concurrent saves are serialized without losing cards', () async {
    String? disk;
    final repo = NotebookRepository(
      read: () async => disk,
      write: (v) async {
        disk = v;
      },
    );
    await Future.wait([
      repo.save(card()),
      repo.save(VocabularyCard.create('Goodbye', 'Tạm biệt', '', now)),
    ]);
    expect(await repo.load(), hasLength(2));
  });
}
