import 'dart:convert';
import 'dart:typed_data';

import 'package:cocenglish/core/api/api_contracts.dart' as wire;
import 'package:cocenglish/core/api/contract_validator.dart';
import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/core/audio/speech_recorder.dart';
import 'package:cocenglish/features/learning/data/speech_assessment.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_transport.dart';

Map<String, Object?> assessment({
  String state = 'VALID',
  String status = 'SUCCEEDED',
  num? accuracy = 70,
  num? completeness = 80,
}) => {
  'jobId': '11111111-1111-4111-8111-111111111111',
  'status': status,
  'transcript': 'Hello, Sam.',
  'accuracy': state == 'VALID' ? accuracy : null,
  'fluency': state == 'VALID' ? 81.5 : null,
  'completeness': state == 'VALID' ? completeness : null,
  'prosody': null,
  'words': state == 'VALID'
      ? [
          {
            'word': 'Hello',
            'accuracy': 91,
            'errorType': 'None',
            'phonemes': [
              {'phoneme': 'h', 'accuracy': 94},
              {'phoneme': 'ə', 'accuracy': null},
            ],
          },
          {
            'word': 'uh',
            'accuracy': 20,
            'errorType': 'Insertion',
            'phonemes': [],
          },
          {
            'word': 'Sam',
            'accuracy': 25,
            'errorType': 'Mispronunciation',
            'phonemes': [],
          },
        ]
      : [],
  'scorer': state == 'VALID' ? 'azure-pronunciation-assessment' : null,
  'scoreVersion': state == 'VALID' ? 'azure-rest-v1-hundredmark' : null,
  'unavailableReason': state == 'VALID' ? null : 'NO_SCORE',
  'expiresAt': '2026-10-16T00:00:00Z',
  'scoreState': state,
  'locale': 'en-US',
  'referenceHash': 'a' * 64,
  'provider': 'azure',
  'modelVersion': state == 'VALID' ? 'azure-rest-v1-hundredmark' : null,
  'miscues': [],
};

void main() {
  test('keeps dedicated scorer metrics and drops inserted words', () {
    final verdict = verdictFrom(
      wire.Assessment.fromJson(assessment()),
      'Hello, Sam.',
    );
    expect(verdict.scored, isTrue);
    expect(verdict.passed, isTrue);
    expect(verdict.accuracy, 70);
    expect(verdict.fluency, 81.5);
    expect(verdict.completeness, 80);
    expect(verdict.prosody, isNull);
    expect(verdict.words.map((w) => w.word), ['Hello', 'Sam']);
    expect(verdict.words.map((w) => w.ok), [true, false]);
    expect(verdict.words.first.phonemes.map((p) => p.symbol), ['h', 'ə']);
    expect(verdict.words.first.phonemes.map((p) => p.accuracy), [94, null]);
  });

  for (final scores in [(69, 80), (70, 79), (70, 80)]) {
    test(
      'speaking pass boundary accuracy ${scores.$1} completeness ${scores.$2}',
      () {
        final verdict = verdictFrom(
          wire.Assessment.fromJson(
            assessment(accuracy: scores.$1, completeness: scores.$2),
          ),
          'Hello, Sam.',
        );
        expect(verdict.scored, isTrue);
        expect(verdict.passed, scores == (70, 80));
      },
    );
  }

  for (final state in ['NULL_UNAVAILABLE', 'NULL_LOW_CONFIDENCE', 'FAILED']) {
    test('$state has no numeric pronunciation metrics', () {
      final verdict = verdictFrom(
        wire.Assessment.fromJson(assessment(state: state)),
        'hello sam',
      );
      expect(verdict.scored, isFalse);
      expect(verdict.accuracy, isNull);
      expect(verdict.fluency, isNull);
      expect(verdict.completeness, isNull);
      expect(verdict.prosody, isNull);
      expect(verdict.words, isEmpty);
      expect(verdict.passed, state == 'NULL_UNAVAILABLE');
    });
  }

  for (final status in ['QUEUED', 'RUNNING', 'FAILED', 'EXPIRED']) {
    test('$status cannot pass or show an old score', () {
      final verdict = verdictFrom(
        wire.Assessment.fromJson(assessment(status: status)),
        'Hello, Sam.',
      );
      expect(verdict.scored, isFalse);
      expect(verdict.passed, isFalse);
      expect(verdict.accuracy, isNull);
    });
  }

  test('wire rejects a valid score without provenance or required metrics', () {
    for (final field in [
      'scorer',
      'scoreVersion',
      'modelVersion',
      'accuracy',
      'completeness',
    ]) {
      final body = assessment()..[field] = null;
      expect(
        () => wire.Assessment.fromJson(body),
        throwsA(isA<ContractViolation>()),
        reason: field,
      );
    }
  });

  test('wire rejects stale numbers on a transcript-only response', () {
    final body = assessment(state: 'NULL_UNAVAILABLE')..['accuracy'] = 99;
    expect(
      () => wire.Assessment.fromJson(body),
      throwsA(isA<ContractViolation>()),
    );
  });

  test(
    'transcription mismatch cannot pass even when scoring is unavailable',
    () {
      final verdict = verdictFrom(
        wire.Assessment.fromJson(assessment(state: 'NULL_UNAVAILABLE')),
        'Good morning',
      );
      expect(verdict.passed, isFalse);
    },
  );

  test(
    'uploads WAV with reference, SHA256, bearer auth and stable retry key',
    () async {
      final transport = FakeApiTransport();
      transport.once(
        'POST /v1/assessment-jobs',
        (_) => throw const ApiTransportException('lost connection'),
      );
      transport.json('POST /v1/assessment-jobs', assessment(), status: 202);
      final api = ApiEndpoints(fakeClient(transport));
      final wav = pcm16ToWav(Uint8List(32000));
      final result = await ApiSpeechAssessor(api).assess(
        wav,
        exerciseId: 'practice-pronunciation-1',
        referenceText: 'Hello, Sam.',
      );
      expect(result.accuracy, 70);
      final requests = transport.to('POST /v1/assessment-jobs');
      expect(requests, hasLength(2));
      expect(requests[0].body, requests[1].body);
      expect(
        requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key'],
      );
      expect(requests[0].headers['Idempotency-Key'], isNotEmpty);
      expect(requests[0].headers['Authorization'], startsWith('Bearer '));
      final body = bodyOf(requests.first);
      expect(base64Decode(body['wavBase64'] as String), wav);
      expect(body['audioSha256'], sha256.convert(wav).toString());
      expect(body['referenceText'], 'Hello, Sam.');
      expect(body['referenceExerciseId'], 'practice-pronunciation-1');
      expect(body['locale'], 'en-US');
      expect(body.containsKey('accuracy'), isFalse);
    },
  );
}
