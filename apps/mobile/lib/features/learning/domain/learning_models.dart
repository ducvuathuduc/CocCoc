enum ExerciseKind {
  textTranslation,
  choice,
  wordBank,
  sentenceOrder,
  fillBlank,
  matchPairs,
  imageChoice,
  listenChoice,
  dictation,
  speakRepeat,
  dialogueTurn,
  storyQuestion,
}

enum LessonStage { idle, answering, checking, feedback, completed, paused }

class ExerciseChoice {
  const ExerciseChoice({
    required this.id,
    required this.text,
    this.art,
    this.image,
  });

  final String id;
  final String text;

  /// Bundled reference character key (`LearningArt.character`).
  final String? art;

  /// Word illustration from the content bundle (`imageAssetId`); rendered
  /// instead of [art] when present.
  final LessonImage? image;
}

/// A content image asset: `fileId` (`i.<unitId>.<wordId>`, EXERCISE_FORMATS
/// section 5) and the bundle's `sha256` of its bytes (null for mock content,
/// which only uses the images shipped with the app).
class LessonImage {
  const LessonImage(this.fileId, [this.sha256]);

  final String fileId;
  final String? sha256;

  @override
  bool operator ==(Object other) =>
      other is LessonImage && other.fileId == fileId && other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(fileId, sha256);

  @override
  String toString() => 'LessonImage($fileId)';
}

/// A lesson audio clip: `fileId` (`a.<unitId>.s<N>.n|s`, `a.w.<slug>.n`,
/// EXERCISE_FORMATS section 5) and the bundle's `sha256` of its bytes (null for
/// mock content, which only plays clips shipped with the app).
class LessonAudio {
  const LessonAudio(this.fileId, [this.sha256]);

  final String fileId;
  final String? sha256;

  @override
  bool operator ==(Object other) =>
      other is LessonAudio && other.fileId == fileId && other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(fileId, sha256);

  @override
  String toString() => 'LessonAudio($fileId)';
}

/// Word-audio key of a tile/option text (`a.w.<slug>.n`): lower case,
/// typographic apostrophes folded, every other run of non `[a-z0-9]`
/// characters becomes `_` (tools/content/build-course.mjs `wordSlug`).
String wordAudioSlug(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[\u2018\u2019]'), "'")
    .replaceAll(RegExp('[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

class Exercise {
  const Exercise({
    required this.id,
    required this.kind,
    required this.title,
    required this.prompt,
    this.choices = const <ExerciseChoice>[],
    this.tokens = const <ExerciseChoice>[],
    this.correctIds = const <String>[],
    this.correctText = '',
    this.pairs = const <String, String>{},
    this.hint,
    this.meaning,
    this.audioPairs = false,
    this.pairLabels = const <String, String>{},
    this.audio,
    this.slowAudio,
    this.wordAudio = const <String, LessonAudio>{},
  });

  final String id;
  final ExerciseKind kind;
  final String title;
  final String prompt;
  final List<ExerciseChoice> choices;
  final List<ExerciseChoice> tokens;
  final List<String> correctIds;
  final String correctText;
  final Map<String, String> pairs;
  final String? hint;
  final String? meaning;

  /// Match-pairs variant whose left column plays audio clips (no text shown).
  final bool audioPairs;

  /// Display text for [pairs] keys/values when they are wire ids (API mode).
  /// Empty when the pairs are keyed by their text (mock fixtures).
  final Map<String, String> pairLabels;

  /// Prompt audio at normal speed (listen, dictation, speak, dialogue and
  /// new-word items); played automatically when the exercise appears.
  final LessonAudio? audio;

  /// The same prompt at 0.75x for the slow ("turtle") replay.
  final LessonAudio? slowAudio;

  /// Tap-to-hear clips for English tiles/options, keyed by [wordAudioSlug].
  final Map<String, LessonAudio> wordAudio;

  /// Text shown for a pair side ([id] itself when it is already text).
  String pairLabel(String id) => pairLabels[id] ?? id;

  Exercise copyWith({
    ExerciseKind? kind,
    String? title,
    String? prompt,
    List<ExerciseChoice>? choices,
    List<ExerciseChoice>? tokens,
    List<String>? correctIds,
    String? correctText,
    Map<String, String>? pairs,
    String? hint,
    String? meaning,
  }) {
    return Exercise(
      id: id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      choices: choices ?? this.choices,
      tokens: tokens ?? this.tokens,
      correctIds: correctIds ?? this.correctIds,
      correctText: correctText ?? this.correctText,
      pairs: pairs ?? this.pairs,
      hint: hint ?? this.hint,
      meaning: meaning ?? this.meaning,
      audioPairs: audioPairs,
      pairLabels: pairLabels,
      audio: audio,
      slowAudio: slowAudio,
      wordAudio: wordAudio,
    );
  }
}

/// Listening is paused for this long after "CAN'T LISTEN NOW" on audio pairs.
const listeningSkipDuration = Duration(minutes: 15);

class LessonAnswer {
  const LessonAnswer({
    this.selectedId,
    this.tokenIds = const <String>[],
    this.text = '',
    this.matchedPairs = const <String, String>{},
  });

  final String? selectedId;
  final List<String> tokenIds;
  final String text;
  final Map<String, String> matchedPairs;
}

class SessionReceipt {
  const SessionReceipt({
    required this.id,
    required this.nodeId,
    required this.xp,
    required this.accuracy,
    required this.elapsed,
    required this.firstCompletion,
    required this.guest,
    required this.placement,
    this.gems = 0,
  });

  final String id;
  final String nodeId;
  final int xp;
  final int gems;
  final double accuracy;
  final Duration elapsed;
  final bool firstCompletion;
  final bool guest;
  final bool placement;
}

class LessonState {
  const LessonState({
    this.stage = LessonStage.idle,
    this.exercises = const <Exercise>[],
    this.index = 0,
    this.selectedId,
    this.tokenIds = const <String>[],
    this.text = '',
    this.matchedPairs = const <String, String>{},
    this.selectedPairLeft,
    this.correct,
    this.assisted = false,
    this.textAlternative = false,
    this.correctStreak = 0,
    this.busy = false,
    this.error,
    this.receipt,
    this.resultStep = 0,
    this.originalCorrect = 0,
    this.attempted = 0,
    this.retryPass = 0,
    this.isRetry = false,
    this.nodeId = 'node-0',
    this.guest = false,
    this.placement = false,
    this.startedAt,
    this.originalTotal = 0,
    this.pendingMistakes = const [],
    this.nextMistakes = const [],
    this.resumeStage = LessonStage.answering,
    this.heartsIntroSeen = false,
    this.skipped = false,
    this.heartsEnforced = false,
  });

  static const maxHearts = 5;

  final LessonStage stage;
  final List<Exercise> exercises;
  final int index;
  final String? selectedId;
  final List<String> tokenIds;
  final String text;
  final Map<String, String> matchedPairs;
  final String? selectedPairLeft;
  final bool? correct;
  final bool assisted;
  final bool textAlternative;
  final int correctStreak;
  final bool busy;
  final String? error;
  final SessionReceipt? receipt;
  final int resultStep;
  final int originalCorrect;
  final int attempted;
  final int retryPass;
  final bool isRetry;
  final String nodeId;
  final bool guest;
  final bool placement;
  final DateTime? startedAt;
  final int originalTotal;
  final List<Exercise> pendingMistakes, nextMistakes;
  final LessonStage resumeStage;

  /// The one-time "each mistake costs 1 heart" sheet was acknowledged.
  final bool heartsIntroSeen;

  /// Hearts gate the lesson (intro sheet on first loss, stop at zero).
  final bool heartsEnforced;

  /// Current exercise was skipped via "CAN'T LISTEN NOW" (no heart cost).
  final bool skipped;

  int get hearts =>
      (maxHearts - (attempted - originalCorrect)).clamp(0, maxHearts);

  bool get outOfHearts => heartsEnforced && !isRetry && hearts == 0;

  bool get showHeartsIntro =>
      heartsEnforced && !heartsIntroSeen && !isRetry && correct == false;

  Exercise? get current =>
      index >= 0 && index < exercises.length ? exercises[index] : null;

  bool get canCheck {
    final exercise = current;
    if (stage != LessonStage.answering || busy || exercise == null) {
      return false;
    }
    return switch (exercise.kind) {
      ExerciseKind.choice ||
      ExerciseKind.imageChoice ||
      ExerciseKind.listenChoice => selectedId != null,
      ExerciseKind.wordBank ||
      ExerciseKind.sentenceOrder => tokenIds.isNotEmpty,
      ExerciseKind.matchPairs =>
        exercise.pairs.isNotEmpty &&
            matchedPairs.length == exercise.pairs.length,
      ExerciseKind.textTranslation ||
      ExerciseKind.fillBlank ||
      ExerciseKind.dictation ||
      ExerciseKind.speakRepeat ||
      ExerciseKind.dialogueTurn ||
      ExerciseKind.storyQuestion => text.trim().isNotEmpty,
    };
  }

  double get progress {
    if (exercises.isEmpty) return 0;
    final completed = stage == LessonStage.feedback ? index + 1 : index;
    return (completed / exercises.length).clamp(0, 1).toDouble();
  }

  LessonState copyWith({
    int? originalTotal,
    List<Exercise>? pendingMistakes,
    List<Exercise>? nextMistakes,
    LessonStage? resumeStage,
    LessonStage? stage,
    List<Exercise>? exercises,
    int? index,
    String? selectedId,
    bool clearSelectedId = false,
    List<String>? tokenIds,
    String? text,
    Map<String, String>? matchedPairs,
    String? selectedPairLeft,
    bool clearSelectedPairLeft = false,
    bool? correct,
    bool clearCorrect = false,
    bool? assisted,
    bool? textAlternative,
    int? correctStreak,
    bool? busy,
    String? error,
    bool clearError = false,
    SessionReceipt? receipt,
    bool clearReceipt = false,
    int? resultStep,
    int? originalCorrect,
    int? attempted,
    int? retryPass,
    bool? isRetry,
    String? nodeId,
    bool? guest,
    bool? placement,
    DateTime? startedAt,
    bool? heartsIntroSeen,
    bool? skipped,
  }) {
    return LessonState(
      heartsIntroSeen: heartsIntroSeen ?? this.heartsIntroSeen,
      heartsEnforced: heartsEnforced,
      skipped: skipped ?? this.skipped,
      originalTotal: originalTotal ?? this.originalTotal,
      pendingMistakes: List.unmodifiable(
        pendingMistakes ?? this.pendingMistakes,
      ),
      nextMistakes: List.unmodifiable(nextMistakes ?? this.nextMistakes),
      resumeStage: resumeStage ?? this.resumeStage,
      stage: stage ?? this.stage,
      exercises: List<Exercise>.unmodifiable(exercises ?? this.exercises),
      index: index ?? this.index,
      selectedId: clearSelectedId ? null : selectedId ?? this.selectedId,
      tokenIds: List<String>.unmodifiable(tokenIds ?? this.tokenIds),
      text: text ?? this.text,
      matchedPairs: Map<String, String>.unmodifiable(
        matchedPairs ?? this.matchedPairs,
      ),
      selectedPairLeft: clearSelectedPairLeft
          ? null
          : selectedPairLeft ?? this.selectedPairLeft,
      correct: clearCorrect ? null : correct ?? this.correct,
      assisted: assisted ?? this.assisted,
      textAlternative: textAlternative ?? this.textAlternative,
      correctStreak: correctStreak ?? this.correctStreak,
      busy: busy ?? this.busy,
      error: clearError ? null : error ?? this.error,
      receipt: clearReceipt ? null : receipt ?? this.receipt,
      resultStep: resultStep ?? this.resultStep,
      originalCorrect: originalCorrect ?? this.originalCorrect,
      attempted: attempted ?? this.attempted,
      retryPass: retryPass ?? this.retryPass,
      isRetry: isRetry ?? this.isRetry,
      nodeId: nodeId ?? this.nodeId,
      guest: guest ?? this.guest,
      placement: placement ?? this.placement,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

class LearningState {
  const LearningState({
    this.gems = 5,
    this.xp = 0,
    this.streak = 0,
    this.score = 0,
    this.completedNodes = const <String>{},
    this.currentNode = 0,
    this.lessonInNode = 0,
    this.completedLessons = 0,
    this.claimedReceiptIds = const <String>{},
  });

  final int gems;
  final int xp;
  final int streak;
  final int score;
  final Set<String> completedNodes;
  final int currentNode;
  final int lessonInNode;
  final int completedLessons;
  final Set<String> claimedReceiptIds;

  LearningState copyWith({
    int? gems,
    int? xp,
    int? streak,
    int? score,
    Set<String>? completedNodes,
    int? currentNode,
    int? lessonInNode,
    int? completedLessons,
    Set<String>? claimedReceiptIds,
  }) {
    return LearningState(
      gems: gems ?? this.gems,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      score: score ?? this.score,
      completedNodes: Set<String>.unmodifiable(
        completedNodes ?? this.completedNodes,
      ),
      currentNode: currentNode ?? this.currentNode,
      lessonInNode: lessonInNode ?? this.lessonInNode,
      completedLessons: completedLessons ?? this.completedLessons,
      claimedReceiptIds: Set<String>.unmodifiable(
        claimedReceiptIds ?? this.claimedReceiptIds,
      ),
    );
  }
}
