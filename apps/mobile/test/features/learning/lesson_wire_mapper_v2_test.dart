import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/features/learning/data/english_explanations.dart';
import 'package:cocenglish/features/learning/data/lesson_image_catalog.g.dart';
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

  test(
    'picture item uses the word illustrations, hash-pinned by the bundle',
    () {
      const hash =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final mapper = LessonWireMapper(
        [
          wire.Exercise.fromJson(
            imageChoice('e2', [
              'i.u6.bedroom',
              'i.u10.street',
              'i.u3.tea',
              'i.u2.cat',
            ]),
          ),
        ],
        assets: [
          wire.Asset.fromJson({
            'fileId': 'i.u10.street',
            'sha256': hash,
            'mime': 'image/webp',
            'bytes': 100,
            'durationMs': null,
            'width': 512,
            'height': 512,
            'locale': null,
            'voice': null,
            'speed': null,
            'provider': null,
            'modelVersion': null,
            'altText': 'Hình minh họa: đường (street)',
          }),
        ],
      );
      final pictures = mapper.toDomain().single;
      expect(pictures.kind, ExerciseKind.imageChoice);
      expect(pictures.choices.map((c) => c.image), [
        const LessonImage('i.u6.bedroom'),
        const LessonImage('i.u10.street', hash),
        const LessonImage('i.u3.tea'),
        const LessonImage('i.u2.cat'),
      ]);
      expect(
        pictures.choices.map((c) => c.art),
        everyElement(isNull),
        reason: 'a real illustration replaces the reference character art',
      );
      expect(pictures.choices.map((c) => c.text), [
        'bedroom',
        'street',
        'tea',
        'cat',
      ]);
      expect(pictures.correctIds, ['c2']);
      expect(pictures.correctText, 'street');
      expect(
        mapper
            .toWireAnswer('e2', const LessonAnswer(selectedId: 'c2'))
            .toJson(),
        {'kind': 'choice', 'choiceId': 'c2'},
      );
    },
  );

  test(
    'picture item without images falls back to character art, then text',
    () {
      final mapper = LessonWireMapper([
        wire.Exercise.fromJson(
          imageChoice('e1', ['i.u1.boy', 'i.u1.cat', 'i.u1.girl', 'i.u1.bear']),
        ),
        wire.Exercise.fromJson(
          imageChoice('e3', [
            'i.u9.zebra',
            'i.u10.street',
            'i.u3.tea',
            'i.u2.cat',
          ]),
        ),
      ]);
      final [characters, text] = mapper.toDomain();
      expect(characters.kind, ExerciseKind.imageChoice);
      expect(characters.choices.map((c) => c.art), [
        'boy',
        'cat',
        'girl',
        'bear',
      ]);
      expect(characters.choices.map((c) => c.image), everyElement(isNull));
      expect(
        text.kind,
        ExerciseKind.choice,
        reason: 'text fallback when one option has no picture, no wrong art',
      );
      expect(text.choices.map((c) => c.text), [
        'zebra',
        'street',
        'tea',
        'cat',
      ]);
    },
  );

  test('every v2 imageChoice option has a bundled illustration', () {
    final dir = Directory('../../content/vi_en/dist/v2/bundles');
    var options = 0;
    for (final file in dir.listSync().whereType<File>()) {
      final bundle = wire.LessonBundle.fromJson(
        jsonDecode(file.readAsStringSync()),
      );
      final mapper = LessonWireMapper(bundle.exercises, assets: bundle.assets);
      final hashes = {for (final a in bundle.assets) a.fileId: a.sha256};
      for (final exercise in bundle.exercises) {
        final json = exercise.toJson();
        if (json['type'] != 'imageChoice') continue;
        final domain = mapper.toDomain().firstWhere((e) => e.id == json['id']);
        expect(domain.kind, ExerciseKind.imageChoice, reason: '${json['id']}');
        for (final choice in domain.choices) {
          options++;
          final image = choice.image!;
          expect(
            bundledLessonImages[image.fileId],
            hashes[image.fileId],
            reason: '${image.fileId}: bundled bytes == manifest hash',
          );
          expect(
            File('assets/lesson_images/${image.fileId}.webp').existsSync(),
            isTrue,
          );
        }
      }
    }
    expect(options, greaterThan(400));
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
