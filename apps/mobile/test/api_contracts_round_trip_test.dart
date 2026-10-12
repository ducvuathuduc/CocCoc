// P1-CONTRACT-001: schema-mapped Dart DTO round-trips over the shared fixture
// cases that tools/blueprint/validate-schemas.mjs (Ajv) also checks.
import 'dart:convert';
import 'dart:io';

import 'package:cocenglish/core/api/api_contracts.dart';
import 'package:cocenglish/core/api/generated/api_schemas.g.dart'
    show apiSchemasJson;
import 'package:flutter_test/flutter_test.dart';

final Directory _repoRoot = Directory.current.parent.parent;

Object? _readJson(String repoRelativePath) => jsonDecode(
  File('${_repoRoot.path}/$repoRelativePath').readAsStringSync(),
);

/// Mirrors the expansion markers documented in schema-cases.json.
Object? _expand(Object? value) {
  if (value is List) return value.map(_expand).toList();
  if (value is Map<String, Object?>) {
    final Object? repeat = value[r'$repeat'];
    if (repeat is Map<String, Object?>) {
      return (repeat['text']! as String) * (repeat['count']! as int);
    }
    final Object? file = value[r'$file'];
    if (file is String) return _readJson(file);
    return value.map((String k, Object? v) => MapEntry(k, _expand(v)));
  }
  return value;
}

void main() {
  final Map<String, Object?> fixtureFile =
      _readJson('packages/api_contracts/fixtures/schema-cases.json')!
          as Map<String, Object?>;
  final List<Map<String, Object?>> cases =
      (fixtureFile['cases']! as List<Object?>).cast<Map<String, Object?>>();
  final Map<String, Object?> openapi =
      _readJson('docs/api/openapi.yaml')! as Map<String, Object?>;
  final Map<String, Object?> componentSchemas =
      (openapi['components']! as Map<String, Object?>)['schemas']!
          as Map<String, Object?>;

  test('shared fixture file is present and non-trivial', () {
    expect(cases.length, greaterThanOrEqualTo(30));
    expect(cases.where((Map<String, Object?> c) => c['valid'] == true),
        isNotEmpty);
    expect(cases.where((Map<String, Object?> c) => c['valid'] == false),
        isNotEmpty);
  });

  group('shared schema fixtures', () {
    for (final Map<String, Object?> fixture in cases) {
      final String schema = fixture['schema']! as String;
      final bool valid = fixture['valid']! as bool;
      final String label = fixture['label']! as String;
      test('$schema: $label (${valid ? 'round-trip' : 'rejected'})', () {
        final Object? value = _expand(fixture['value']);
        final Object Function(Object?) decode = apiContractDecoders[schema]!;
        if (valid) {
          final Object dto = decode(value);
          final Object? encoded = (dto as dynamic).toJson();
          expect(encoded, equals(value));
          // Encoded output must itself satisfy the contract and be stable.
          expect(ContractValidator.instance.validate(schema, encoded), isEmpty);
          final Object? reEncoded =
              (decode(jsonDecode(jsonEncode(encoded))) as dynamic).toJson();
          expect(reEncoded, equals(value));
        } else {
          expect(() => decode(value), throwsA(isA<ContractViolation>()));
          expect(ContractValidator.instance.validate(schema, value),
              isNotEmpty);
        }
      });
    }
  });

  test('every OpenAPI component schema has a generated decoder', () {
    expect(apiContractDecoders.keys.toSet(), componentSchemas.keys.toSet());
    expect(ContractValidator.instance.schemaNames.toSet(),
        componentSchemas.keys.toSet());
  });

  test('embedded schemas are a verbatim copy of docs/api/openapi.yaml', () {
    expect(jsonDecode(apiSchemasJson), equals(componentSchemas));
  });

  group('typed unions', () {
    Map<String, Object?> caseValue(String label) =>
        _expand(cases.firstWhere(
          (Map<String, Object?> c) => c['label'] == label,
        )['value']) as Map<String, Object?>;

    test('VoiceLease decodes to the discriminated variant', () {
      final VoiceLease live = VoiceLease.fromJson(caseValue('LIVE complete'));
      expect(live, isA<LiveVoiceLease>());
      expect(live.mode, 'LIVE');
      expect((live as LiveVoiceLease).inputSampleRate, 16000);
      final VoiceLease turn =
          VoiceLease.fromJson(caseValue('TURN no credential'));
      expect(turn, isA<TurnVoiceLease>());
      expect((turn as TurnVoiceLease).ephemeralToken, isNull);
    });

    test('Exercise variants carry their typed payloads', () {
      final Exercise exercise =
          Exercise.fromJson(caseValue('listen exercise with non-audio alternative'));
      expect(exercise, isA<ListenChoiceExercise>());
      final ListenChoiceExercise listen = exercise as ListenChoiceExercise;
      expect(listen.content.choices.single.id, 'a');
      expect(listen.nonAudioAlternative, isA<ChoiceExercise>());
      expect(listen.gradingRule.correctChoiceId.value, 'a');
    });

    test('Answer union keeps typed pair connections', () {
      final Answer answer =
          Answer.fromJson(caseValue('matching connections retained'));
      expect(answer, isA<PairAnswer>());
      expect((answer as PairAnswer).matches.single.rightId, 'right-b');
    });

    test('BusinessEvent dispatches on the const event type', () {
      final BusinessEvent event =
          BusinessEvent.fromJson(caseValue('lesson.completed.v1 example event'));
      expect(event, isA<BusinessEventLessonCompletedV1>());
      expect(event.type, 'lesson.completed.v1');
      expect((event as BusinessEventLessonCompletedV1).payload.originalCorrect,
          8);
    });

    test('a valid variant is rejected through the wrong union', () {
      final Map<String, Object?> textAnswer = caseValue('text answer retained');
      expect(() => Exercise.fromJson(textAnswer),
          throwsA(isA<ContractViolation>()));
      expect(() => VoiceLease.fromJson(textAnswer),
          throwsA(isA<ContractViolation>()));
    });
  });

  group('malformed payloads', () {
    final List<Object?> notObjects = <Object?>[null, 'x', 1, true, <Object?>[]];
    for (final Object? value in notObjects) {
      test('Health rejects ${jsonEncode(value)}', () {
        expect(() => Health.fromJson(value), throwsA(isA<ContractViolation>()));
      });
    }

    test('ContractViolation carries schema name and error paths', () {
      try {
        Health.fromJson(<String, Object?>{'service': 'learning'});
        fail('expected ContractViolation');
      } on ContractViolation catch (violation) {
        expect(violation.schema, 'Health');
        expect(violation.errors.join(' '), contains('buildId'));
      }
    });
  });

  group('optional nullable presence', () {
    test('explicit null and absence stay distinct through round-trip', () {
      final ProfilePatch clear = ProfilePatch.fromJson(<String, Object?>{
        'avatarId': null,
        'expectedRevision': 3,
      });
      expect(clear.avatarId, const JsonPresence<String>.value(null));
      expect(clear.toJson(), <String, Object?>{
        'avatarId': null,
        'expectedRevision': 3,
      });
      final ProfilePatch keep =
          ProfilePatch.fromJson(<String, Object?>{'expectedRevision': 3});
      expect(keep.avatarId.isPresent, isFalse);
      expect(keep.toJson().containsKey('avatarId'), isFalse);
    });

    test('constructed DTOs encode to schema-valid JSON', () {
      const ProfilePatch patch = ProfilePatch(
        nickname: 'Thanh',
        avatarId: JsonPresence<String>.value('owl-1'),
        expectedRevision: 7,
      );
      expect(ContractValidator.instance.validate('ProfilePatch', patch.toJson()),
          isEmpty);
    });
  });
}
