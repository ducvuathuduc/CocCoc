/// Personal review heuristic from FR-PRACTICE-002. Dates use UTC days so
/// travelling does not move an already scheduled review. No XP is awarded.
class VocabularyCard {
  const VocabularyCard({
    required this.id,
    required this.term,
    required this.meaning,
    required this.example,
    required this.dueAt,
    this.stage = 0,
  });
  factory VocabularyCard.create(
    String term,
    String meaning,
    String example,
    DateTime now,
  ) {
    final clean = term.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty ||
        clean.length > 300 ||
        meaning.trim().isEmpty ||
        meaning.length > 1000 ||
        example.length > 1000) {
      throw ArgumentError(
        'A word/phrase and meaning are required (300/1000 characters maximum).',
      );
    }
    return VocabularyCard(
      id: clean.toLowerCase(),
      term: clean,
      meaning: meaning.trim(),
      example: example.trim(),
      dueAt: now.toUtc(),
    );
  }
  final String id, term, meaning, example;
  final DateTime dueAt;
  final int stage;
  bool matchesMeaning(String answer) {
    String normalize(String text) =>
        text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return normalize(answer) == normalize(meaning);
  }

  bool isDue(DateTime now) => !dueAt.isAfter(now.toUtc());
  VocabularyCard review(
    DateTime now, {
    required bool correct,
    required bool assisted,
  }) {
    if (!isDue(now)) throw StateError('This word is not due yet.');
    final advance = correct && !assisted;
    final utc = now.toUtc();
    return VocabularyCard(
      id: id,
      term: term,
      meaning: meaning,
      example: example,
      dueAt: DateTime.utc(
        utc.year,
        utc.month,
        utc.day + (advance ? [1, 3, 7, 14, 30][stage] : 1),
      ),
      stage: advance ? (stage + 1).clamp(0, 4) : 0,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'term': term,
    'meaning': meaning,
    'example': example,
    'dueAt': dueAt.toIso8601String(),
    'stage': stage,
  };
  factory VocabularyCard.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['dueAt'] as String);
    final base = VocabularyCard.create(
      json['term'] as String,
      json['meaning'] as String,
      json['example'] as String,
      date,
    );
    final stage = json['stage'] as int;
    if (stage < 0 || stage > 4 || json['id'] != base.id) {
      throw const FormatException('Invalid review card');
    }
    return VocabularyCard(
      id: base.id,
      term: base.term,
      meaning: base.meaning,
      example: base.example,
      dueAt: date.toUtc(),
      stage: stage,
    );
  }
}
