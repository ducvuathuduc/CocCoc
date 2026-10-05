import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/practice/data/practice_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repository = MockLearningRepository(delay: Duration.zero);

  test(
    'lesson loads the authored English sequence for Vietnamese learners',
    () async {
      final exercises = await repository.loadLesson('node-0');

      expect(exercises, hasLength(10));
      expect(exercises.map((exercise) => exercise.id), [
        'english-01-image',
        'english-02-choice',
        'english-03-bank',
        'english-04-pairs',
        'english-05-translate',
        'english-06-listen',
        'english-07-blank',
        'english-08-order',
        'english-09-dialogue',
        'english-10-story',
      ]);
      expect(exercises.map((exercise) => exercise.kind), [
        ExerciseKind.imageChoice,
        ExerciseKind.choice,
        ExerciseKind.wordBank,
        ExerciseKind.matchPairs,
        ExerciseKind.textTranslation,
        ExerciseKind.listenChoice,
        ExerciseKind.fillBlank,
        ExerciseKind.sentenceOrder,
        ExerciseKind.dialogueTurn,
        ExerciseKind.storyQuestion,
      ]);
      expect(exercises[0].prompt, 'the woman');
      expect(exercises[0].choices.map((choice) => choice.art), [
        'boy',
        'girl',
        'cat',
        'woman',
      ]);
      expect(exercises[1].prompt, 'người phụ nữ');
      expect(exercises[1].choices.map((choice) => choice.text), [
        'and',
        'woman',
        'boy',
      ]);
      expect(exercises[2].prompt, 'Tôi là một người phụ nữ');
      expect(exercises[2].tokens.map((token) => token.text), [
        'I',
        'am',
        'a',
        'woman',
        'man',
      ]);
      expect(exercises[3].pairs, {
        'woman': 'người phụ nữ',
        'man': 'người đàn ông',
        'bear': 'con gấu',
      });
      expect(exercises[4].prompt, 'Con mèo');
      expect(exercises[4].correctText, 'The cat');
      expect(exercises[5].correctText, 'a girl');
      expect(exercises[6].prompt, 'I ___ a man');
      expect(exercises[6].correctText, 'am');
      expect(exercises[7].prompt, 'Con gấu ở đây');
      expect(exercises[7].tokens.map((token) => token.text), [
        'The',
        'bear',
        'is',
        'here',
      ]);
      expect(exercises[8].prompt, 'Sam: Hello!');
      expect(exercises[8].correctText, 'Hello');
      expect(exercises[9].prompt, 'Lea sees a cat. What does Lea see?');
      expect(exercises[9].correctText, 'a cat');
    },
  );

  test('every authored lesson and practice answer grades correctly', () async {
    final exercises = [
      ...await repository.loadLesson('node-0'),
      ...mockPracticeExercises,
    ];

    for (final exercise in exercises) {
      expect(
        await repository.grade(exercise, _correctAnswer(exercise)),
        isTrue,
        reason: '${exercise.id} must accept its authored answer',
      );
      expect(
        await repository.grade(exercise, _wrongAnswer(exercise)),
        isFalse,
        reason: '${exercise.id} must reject a wrong answer',
      );
    }
  });

  test('practice fixtures use English prompts with Vietnamese meanings', () {
    expect(mockPracticeExercises.map((exercise) => exercise.kind), [
      ExerciseKind.dictation,
      ExerciseKind.speakRepeat,
    ]);
    expect(mockPracticeExercises.map((exercise) => exercise.correctText), [
      'I am here.',
      'Hello, I am Sam.',
    ]);
    expect(mockPracticeWords.map((word) => [word.term, word.meaning]), [
      ['woman', 'người phụ nữ'],
      ['hello', 'xin chào'],
      ['bear', 'con gấu'],
      ['thank you', 'cảm ơn'],
    ]);
    expect(mockCallOpening.single.speaker, 'Lily');
    expect(mockCallOpening.single.text, 'Hello.');
  });

  test('learning and practice fixtures contain no French remnants', () async {
    final exercises = [
      ...await repository.loadLesson('node-0'),
      ...mockPracticeExercises,
    ];
    final fixtureText = [
      for (final exercise in exercises) ...[
        exercise.id,
        exercise.title,
        exercise.prompt,
        exercise.correctText,
        exercise.hint ?? '',
        ...exercise.choices.expand(
          (choice) => [choice.id, choice.text, choice.art ?? ''],
        ),
        ...exercise.tokens.expand((token) => [token.id, token.text]),
        ...exercise.pairs.entries.expand((pair) => [pair.key, pair.value]),
      ],
      for (final word in mockPracticeWords) ...[
        word.id,
        word.term,
        word.meaning,
      ],
      for (final line in mockCallOpening) line.text,
    ].join(' ').toLowerCase();

    for (final remnant in [
      'french',
      'français',
      'femme',
      'homme',
      'bonjour',
      'bonsoir',
      'merci',
      'garçon',
      'je suis',
      'le chat',
      'une fille',
      "l'ours",
    ]) {
      expect(fixtureText, isNot(contains(remnant)), reason: remnant);
    }
  });
}

LessonAnswer _correctAnswer(Exercise exercise) => switch (exercise.kind) {
  ExerciseKind.choice ||
  ExerciseKind.imageChoice ||
  ExerciseKind.listenChoice => LessonAnswer(
    selectedId: exercise.correctIds.single,
  ),
  ExerciseKind.wordBank ||
  ExerciseKind.sentenceOrder => LessonAnswer(tokenIds: exercise.correctIds),
  ExerciseKind.matchPairs => LessonAnswer(matchedPairs: exercise.pairs),
  ExerciseKind.textTranslation ||
  ExerciseKind.fillBlank ||
  ExerciseKind.dictation ||
  ExerciseKind.speakRepeat ||
  ExerciseKind.dialogueTurn ||
  ExerciseKind.storyQuestion => LessonAnswer(text: exercise.correctText),
};

LessonAnswer _wrongAnswer(Exercise exercise) => switch (exercise.kind) {
  ExerciseKind.choice ||
  ExerciseKind.imageChoice ||
  ExerciseKind.listenChoice => const LessonAnswer(selectedId: 'wrong'),
  ExerciseKind.wordBank ||
  ExerciseKind.sentenceOrder => const LessonAnswer(tokenIds: ['wrong']),
  ExerciseKind.matchPairs => const LessonAnswer(
    matchedPairs: {'wrong': 'answer'},
  ),
  ExerciseKind.textTranslation ||
  ExerciseKind.fillBlank ||
  ExerciseKind.dictation ||
  ExerciseKind.speakRepeat ||
  ExerciseKind.dialogueTurn ||
  ExerciseKind.storyQuestion => const LessonAnswer(text: 'wrong answer'),
};
