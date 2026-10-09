import 'course_catalog.dart';
import 'learning_models.dart';

String courseNodeId(CourseTarget target, int node) =>
    target == const CourseTarget(1, 1)
    ? 'node-$node'
    : 'section-${target.section}-unit-${target.unit}-review-$node';

List<Exercise> courseReviewExercises(CourseTarget target) => List.unmodifiable([
  for (final (index, phrase) in unitGuide(target).phrases.indexed)
    Exercise(
      id: 'course-${target.section}-${target.unit}-phrase-$index',
      kind: ExerciseKind.wordBank,
      title: 'Translate this sentence',
      prompt: phrase.vietnamese,
      tokens: List.unmodifiable([
        for (final (wordIndex, word)
            in phrase.english.split(' ').indexed.toList().reversed)
          ExerciseChoice(id: 'word-$wordIndex', text: word),
      ]),
      correctIds: List.unmodifiable([
        for (var i = 0; i < phrase.english.split(' ').length; i++) 'word-$i',
      ]),
    ),
]);
