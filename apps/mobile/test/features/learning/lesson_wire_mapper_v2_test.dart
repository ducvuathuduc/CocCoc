import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/features/learning/data/english_explanations.dart';
import 'package:cocenglish/features/learning/data/lesson_wire_mapper.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> imageChoice(String id, List<String> assets) => {
  'content': {
    'choices': [
      for (var i = 0; i < assets.length; i++)
        {
          'id': 'c${i + 1}',
          'imageAssetId': assets[i],
          'text': assets[i].split('.').last,
        },
    ],
  },
  'explanation': 'ok',
  'gradingRule': {
    'caseSensitive': false,
    'correctChoiceId': 'c2',
    'ignoreDiacritics': false,
    'ignorePunctuation': false,
  },
  'hint': 'hint',
  'id': id,
  'prompt': {'locale': 'vi-VN', 'text': 'Hình nào là "con mèo"?'},
  'skillIds': ['u1.vocab'],
  'type': 'imageChoice',
  'vocabularyIds': ['u1.cat'],
};

final matchPairs = <String, Object?>{
  'content': {
    'pairs': [
      {
        'id': 'p1',
        'left': {'id': 'p1l', 'text': 'goodbye'},
        'right': {'id': 'p1r', 'text': 'tạm biệt'},
      },
      {
        'id': 'p2',
        'left': {'id': 'p2l', 'text': 'hello'},
        'right': {'id': 'p2r', 'text': 'xin chào'},
      },
    ],
  },
  'explanation': 'goodbye = tạm biệt',
  'gradingRule': {
    'caseSensitive': false,
    'correctPairIds': ['p1', 'p2'],
    'ignoreDiacritics': false,
    'ignorePunctuation': false,
  },
  'hint': 'hint',
  'id': 'u1n1l1-e05',
  'prompt': {'locale': 'vi-VN', 'text': 'Nối các cặp từ tương ứng'},
  'skillIds': ['u1.vocab'],
  'type': 'matchPairs',
  'vocabularyIds': ['u1.goodbye', 'u1.hello'],
};

void main() {
  test('imageAssetId maps i.<unit>.<word> to bundled art', () {
    expect(LessonWireMapper.artFor('i.u1.cat'), 'cat');
    expect(LessonWireMapper.artFor('i.u2.woman'), 'woman');
    expect(LessonWireMapper.artFor('i.u6.bedroom'), isNull);
    expect(LessonWireMapper.artFor(null), isNull);
  });

  test('picture item keeps picture tiles only when every option has art', () {
    final mapper = LessonWireMapper([
      wire.Exercise.fromJson(
        imageChoice('e1', ['i.u1.boy', 'i.u1.cat', 'i.u1.girl', 'i.u1.bear']),
      ),
      wire.Exercise.fromJson(
        imageChoice('e2', [
          'i.u6.bedroom',
          'i.u10.street',
          'i.u3.tea',
          'i.u1.cat',
        ]),
      ),
    ]);
    final [pictures, text] = mapper.toDomain();
    expect(pictures.kind, ExerciseKind.imageChoice);
    expect(pictures.choices.map((c) => c.art), ['boy', 'cat', 'girl', 'bear']);
    expect(
      text.kind,
      ExerciseKind.choice,
      reason: 'text fallback, no wrong art',
    );
    expect(text.choices.map((c) => c.text), [
      'bedroom',
      'street',
      'tea',
      'cat',
    ]);
    expect(text.correctIds, ['c2']);
    expect(text.correctText, 'street');
    expect(
      mapper.toWireAnswer('e2', const LessonAnswer(selectedId: 'c2')).toJson(),
      {'kind': 'choice', 'choiceId': 'c2'},
    );
  });

  test('match pairs are keyed by wire ids and labelled by text', () {
    final mapper = LessonWireMapper([wire.Exercise.fromJson(matchPairs)]);
    final exercise = mapper.toDomain().single;
    expect(exercise.pairs, {'p1l': 'p1r', 'p2l': 'p2r'});
    expect(exercise.pairLabel('p1l'), 'goodbye');
    expect(exercise.pairLabel('p2r'), 'xin chào');
    expect(exerciseAnswer(exercise), 'goodbye → tạm biệt\nhello → xin chào');
    final answer = mapper.toWireAnswer(
      exercise.id,
      LessonAnswer(matchedPairs: exercise.pairs),
    );
    final json = answer.toJson();
    expect(json['matches'], [
      {'leftId': 'p1l', 'rightId': 'p1r'},
      {'leftId': 'p2l', 'rightId': 'p2r'},
    ]);
    expect(mapper.gradeLocally(exercise.id, json), isTrue);
  });

  test('text-keyed fixture pairs still label themselves', () {
    const exercise = Exercise(
      id: 'm',
      kind: ExerciseKind.matchPairs,
      title: 't',
      prompt: 'p',
      pairs: {'hello': 'xin chào'},
    );
    expect(exercise.pairLabel('hello'), 'hello');
  });
}
