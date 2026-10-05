import '../domain/learning_models.dart';

abstract class LearningRepository {
  Future<List<Exercise>> loadLesson(String nodeId);

  Future<bool> grade(Exercise exercise, LessonAnswer answer);

  Future<SessionReceipt> complete({
    required String nodeId,
    required int originalCorrect,
    required int originalTotal,
    required Duration elapsed,
    required bool guest,
    required bool placement,
  });

  void saveDraft(LessonState state);

  LessonState? loadDraft();

  void clearDraft();
}

class LearningFailure implements Exception {
  const LearningFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class MockLearningRepository implements LearningRepository {
  MockLearningRepository({this.delay = const Duration(milliseconds: 25)});

  final Duration delay;
  int gradeCalls = 0;
  int completeCalls = 0;
  LessonState? _draft;
  final Set<String> _completedNodes = <String>{};
  int _receiptSequence = 0;

  @override
  Future<List<Exercise>> loadLesson(String nodeId) async {
    await Future<void>.delayed(delay);
    return mockEnglishExercises;
  }

  @override
  Future<bool> grade(Exercise exercise, LessonAnswer answer) async {
    gradeCalls += 1;
    await Future<void>.delayed(delay);
    return switch (exercise.kind) {
      ExerciseKind.choice ||
      ExerciseKind.imageChoice ||
      ExerciseKind.listenChoice =>
        exercise.correctIds.length == 1 &&
            answer.selectedId == exercise.correctIds.single,
      ExerciseKind.wordBank || ExerciseKind.sentenceOrder => _sameIds(
        answer.tokenIds,
        exercise.correctIds,
      ),
      ExerciseKind.matchPairs => _samePairs(
        answer.matchedPairs,
        exercise.pairs,
      ),
      ExerciseKind.textTranslation ||
      ExerciseKind.fillBlank ||
      ExerciseKind.dictation ||
      ExerciseKind.speakRepeat ||
      ExerciseKind.dialogueTurn ||
      ExerciseKind.storyQuestion =>
        _normalize(answer.text) == _normalize(exercise.correctText),
    };
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
    completeCalls += 1;
    await Future<void>.delayed(delay);
    final firstCompletion = !guest && !placement && _completedNodes.add(nodeId);
    final accuracy = originalTotal == 0 ? 0.0 : originalCorrect / originalTotal;
    final xp = guest || placement || !firstCompletion
        ? 0
        : 10 + originalCorrect;
    return SessionReceipt(
      id: 'lesson-${++_receiptSequence}',
      nodeId: nodeId,
      xp: xp,
      gems: firstCompletion && _completedNodes.length == 1 ? 50 : 0,
      accuracy: accuracy,
      elapsed: elapsed,
      firstCompletion: firstCompletion,
      guest: guest,
      placement: placement,
    );
  }

  @override
  void saveDraft(LessonState state) => _draft = state;

  @override
  LessonState? loadDraft() => _draft;

  @override
  void clearDraft() => _draft = null;
}

bool _sameIds(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index += 1) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}

bool _samePairs(Map<String, String> actual, Map<String, String> expected) {
  if (actual.length != expected.length) return false;
  return expected.entries.every((entry) => actual[entry.key] == entry.value);
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

const mockEnglishExercises = <Exercise>[
  Exercise(
    id: 'english-01-image',
    kind: ExerciseKind.imageChoice,
    title: 'Select the correct image',
    prompt: 'the woman',
    choices: [
      ExerciseChoice(id: 'boy', text: 'the boy', art: 'boy'),
      ExerciseChoice(id: 'girl', text: 'the girl', art: 'girl'),
      ExerciseChoice(id: 'cat', text: 'the cat', art: 'cat'),
      ExerciseChoice(id: 'woman', text: 'the woman', art: 'woman'),
    ],
    correctIds: ['woman'],
    hint: 'Woman means người phụ nữ.',
  ),
  Exercise(
    id: 'english-02-choice',
    kind: ExerciseKind.choice,
    title: 'Select the correct translation',
    prompt: 'người phụ nữ',
    choices: [
      ExerciseChoice(id: 'and', text: 'and'),
      ExerciseChoice(id: 'woman', text: 'woman'),
      ExerciseChoice(id: 'boy', text: 'boy'),
    ],
    correctIds: ['woman'],
  ),
  Exercise(
    id: 'english-03-bank',
    kind: ExerciseKind.wordBank,
    title: 'Build the translation',
    prompt: 'Tôi là một người phụ nữ',
    tokens: [
      ExerciseChoice(id: 'i', text: 'I'),
      ExerciseChoice(id: 'am', text: 'am'),
      ExerciseChoice(id: 'a', text: 'a'),
      ExerciseChoice(id: 'woman', text: 'woman'),
      ExerciseChoice(id: 'man', text: 'man'),
    ],
    correctIds: ['i', 'am', 'a', 'woman'],
  ),
  Exercise(
    id: 'english-04-pairs',
    kind: ExerciseKind.matchPairs,
    title: 'Match the pairs',
    prompt: 'Match each English word with its Vietnamese meaning.',
    pairs: {'woman': 'người phụ nữ', 'man': 'người đàn ông', 'bear': 'con gấu'},
  ),
  Exercise(
    id: 'english-05-translate',
    kind: ExerciseKind.textTranslation,
    title: 'Translate to English',
    prompt: 'Con mèo',
    correctText: 'The cat',
    hint: "Use 'the' before 'cat'.",
  ),
  Exercise(
    id: 'english-06-listen',
    kind: ExerciseKind.listenChoice,
    title: 'Listen and choose',
    prompt: 'Audio: a girl',
    choices: [
      ExerciseChoice(id: 'girl', text: 'A girl', art: 'girl'),
      ExerciseChoice(id: 'woman', text: 'A woman', art: 'woman'),
      ExerciseChoice(id: 'man', text: 'A man', art: 'man'),
    ],
    correctIds: ['girl'],
    correctText: 'a girl',
  ),
  Exercise(
    id: 'english-07-blank',
    kind: ExerciseKind.fillBlank,
    title: 'Complete the sentence',
    prompt: 'I ___ a man',
    correctText: 'am',
  ),
  Exercise(
    id: 'english-08-order',
    kind: ExerciseKind.sentenceOrder,
    title: 'Put the words in order',
    prompt: 'Con gấu ở đây',
    tokens: [
      ExerciseChoice(id: 'the', text: 'The'),
      ExerciseChoice(id: 'bear', text: 'bear'),
      ExerciseChoice(id: 'is', text: 'is'),
      ExerciseChoice(id: 'here', text: 'here'),
    ],
    correctIds: ['the', 'bear', 'is', 'here'],
  ),
  Exercise(
    id: 'english-09-dialogue',
    kind: ExerciseKind.dialogueTurn,
    title: 'Reply to the greeting',
    prompt: 'Sam: Hello!',
    correctText: 'Hello',
  ),
  Exercise(
    id: 'english-10-story',
    kind: ExerciseKind.storyQuestion,
    title: 'Answer the story question',
    prompt: 'Lea sees a cat. What does Lea see?',
    correctText: 'a cat',
  ),
];

const mockPracticeExercises = <Exercise>[
  Exercise(
    id: 'english-practice-dictation',
    kind: ExerciseKind.dictation,
    title: 'Write what you hear',
    prompt: 'Audio: I am here.',
    correctText: 'I am here.',
  ),
  Exercise(
    id: 'english-practice-speak',
    kind: ExerciseKind.speakRepeat,
    title: 'Speak this sentence',
    prompt: 'Hello, I am Sam.',
    correctText: 'Hello, I am Sam.',
  ),
];
