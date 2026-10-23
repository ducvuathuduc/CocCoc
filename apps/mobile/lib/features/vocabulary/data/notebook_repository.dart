import 'dart:convert';

import '../domain/vocabulary_card.dart';

/// A single durable snapshot; commands serialize read-modify-write and only
/// report success after storage commits. Corrupt snapshots fail visibly.
class NotebookRepository {
  NotebookRepository({required this.read, required this.write});
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  Future<void> _tail = Future.value();
  Future<List<VocabularyCard>> load() async {
    final raw = await read();
    if (raw == null) return [];
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unsupported notebook');
    }
    return (json['cards'] as List)
        .map(
          (v) => VocabularyCard.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList();
  }

  Future<void> _change(void Function(List<VocabularyCard>) update) {
    final next = _tail.then((_) async {
      final cards = await load();
      update(cards);
      await write(
        jsonEncode({
          'version': 1,
          'cards': cards.map((v) => v.toJson()).toList(),
        }),
      );
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> save(VocabularyCard card) => _change((cards) {
    if (cards.any((v) => v.id == card.id)) return;
    if (cards.length >= 1000) throw StateError('Notebook limit: 1000 words.');
    cards.add(card);
  });
  Future<void> remove(String id) =>
      _change((cards) => cards.removeWhere((v) => v.id == id));
  Future<void> review(
    String id,
    DateTime now, {
    required bool correct,
    required bool assisted,
  }) => _change((cards) {
    final index = cards.indexWhere((v) => v.id == id);
    if (index < 0) throw StateError('Word no longer exists.');
    cards[index] = cards[index].review(
      now,
      correct: correct,
      assisted: assisted,
    );
  });
}
