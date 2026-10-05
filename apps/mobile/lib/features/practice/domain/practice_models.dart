class PracticeWord {
  const PracticeWord({
    required this.id,
    required this.term,
    required this.meaning,
  });

  final String id;
  final String term;
  final String meaning;
}

enum WordSort { recent, alphabetical }

class PracticeState {
  const PracticeState({
    this.words = const <PracticeWord>[],
    this.index = 0,
    this.revealed = false,
    this.recalledIds = const <String>{},
    this.wordSort = WordSort.recent,
  });

  final List<PracticeWord> words;
  final int index;
  final bool revealed;
  final Set<String> recalledIds;
  final WordSort wordSort;
  List<PracticeWord> get sortedWords {
    final result = List<PracticeWord>.of(words);
    if (wordSort == WordSort.alphabetical) {
      result.sort(
        (a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()),
      );
    }
    return List.unmodifiable(result);
  }

  PracticeWord? get current =>
      words.isEmpty ? null : words[index % words.length];

  PracticeState copyWith({
    int? index,
    bool? revealed,
    Set<String>? recalledIds,
    WordSort? wordSort,
  }) => PracticeState(
    words: words,
    index: index ?? this.index,
    revealed: revealed ?? this.revealed,
    recalledIds: Set<String>.unmodifiable(recalledIds ?? this.recalledIds),
    wordSort: wordSort ?? this.wordSort,
  );
}

enum SpeechCapability {
  ready,
  permissionDenied,
  unsupported,
  capturing,
  unscored,
}

enum CallStage { idle, connecting, responding, reconnecting, ended }

class ConversationLine {
  const ConversationLine({required this.speaker, required this.text});

  final String speaker;
  final String text;
}

class SpeakingState {
  const SpeakingState({
    this.capability = SpeechCapability.ready,
    this.callStage = CallStage.idle,
    this.transcript = const <ConversationLine>[],
  });

  final SpeechCapability capability;
  final CallStage callStage;
  final List<ConversationLine> transcript;

  SpeakingState copyWith({
    SpeechCapability? capability,
    CallStage? callStage,
    List<ConversationLine>? transcript,
  }) => SpeakingState(
    capability: capability ?? this.capability,
    callStage: callStage ?? this.callStage,
    transcript: List<ConversationLine>.unmodifiable(
      transcript ?? this.transcript,
    ),
  );
}
