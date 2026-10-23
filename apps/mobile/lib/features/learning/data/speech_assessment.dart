import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';

/// One phoneme returned by the dedicated scorer; missing metrics stay null.
class SpokenPhoneme {
  const SpokenPhoneme(this.symbol, this.accuracy);
  final String symbol;
  final double? accuracy;
}

/// One reference word with its pronunciation result. Accuracy is nullable.
class SpokenWord {
  const SpokenWord(
    this.word, {
    this.accuracy,
    this.errorType,
    this.phonemes = const [],
  });
  final String word;
  final double? accuracy;
  final String? errorType;
  final List<SpokenPhoneme> phonemes;

  /// Pronounced well enough to show green.
  bool get ok =>
      accuracy != null &&
      accuracy! >= 60 &&
      (errorType == null ||
          errorType == 'None' ||
          errorType == 'UnexpectedBreak' ||
          errorType == 'MissingBreak' ||
          errorType == 'Monotone');
}

/// Result of assessing one spoken attempt against the reference sentence.
class SpeechVerdict {
  const SpeechVerdict({
    required this.scored,
    required this.passed,
    required this.transcript,
    this.words = const <SpokenWord>[],
    this.accuracy,
    this.fluency,
    this.completeness,
    this.prosody,
    this.reason,
  });

  /// True when a dedicated pronunciation scorer (Azure) produced numbers.
  final bool scored;

  /// Scored: accuracy ≥ 70 and completeness ≥ 80 (AI_ARCHITECTURE lesson
  /// speaking grade). Unscored: the recognized words equal the reference.
  final bool passed;
  final String transcript;

  /// Reference-aligned words (insertions dropped) when [scored].
  final List<SpokenWord> words;
  final double? accuracy;
  final double? fluency;
  final double? completeness;
  final double? prosody;
  final String? reason;
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9' ]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Maps the server Assessment to a [SpeechVerdict].
SpeechVerdict verdictFrom(wire.Assessment a, String referenceText) {
  final transcript = a.transcript ?? '';
  double? metric(num? value) =>
      value != null && value.isFinite && value >= 0 && value <= 100
      ? value.toDouble()
      : null;
  final accuracy = metric(a.accuracy);
  final completeness = metric(a.completeness);
  final succeeded = a.status == 'SUCCEEDED';
  if (succeeded &&
      a.scoreState == 'VALID' &&
      transcript.trim().isNotEmpty &&
      a.locale == 'en-US' &&
      a.scorer != null &&
      a.modelVersion != null &&
      a.scoreVersion != null &&
      accuracy != null &&
      completeness != null) {
    final words = [
      for (final w in a.words)
        if (w.errorType != 'Insertion')
          SpokenWord(
            w.word,
            accuracy: metric(w.accuracy),
            errorType: w.errorType,
            phonemes: List.unmodifiable([
              for (final p in w.phonemes)
                SpokenPhoneme(p.phoneme, metric(p.accuracy)),
            ]),
          ),
    ];
    return SpeechVerdict(
      scored: true,
      passed: accuracy >= 70 && completeness >= 80,
      transcript: transcript,
      words: words,
      accuracy: accuracy,
      fluency: metric(a.fluency),
      completeness: completeness,
      prosody: metric(a.prosody),
    );
  }
  return SpeechVerdict(
    scored: false,
    passed:
        succeeded &&
        a.scoreState == 'NULL_UNAVAILABLE' &&
        transcript.trim().isNotEmpty &&
        _norm(transcript) == _norm(referenceText),
    transcript: transcript,
    reason: a.unavailableReason,
  );
}

/// Sends a recorded attempt for pronunciation assessment.
abstract class SpeechAssessor {
  Future<SpeechVerdict> assess(
    Uint8List wav, {
    required String exerciseId,
    required String referenceText,
  });
}

/// `POST /v1/assessment-jobs` on the AI service (synchronous result).
class ApiSpeechAssessor implements SpeechAssessor {
  ApiSpeechAssessor(this.api);
  final ApiEndpoints api;

  static final _id = RegExp(r'[^A-Za-z0-9_.-]');

  @override
  Future<SpeechVerdict> assess(
    Uint8List wav, {
    required String exerciseId,
    required String referenceText,
  }) async {
    var ref = exerciseId.replaceAll(_id, '_');
    if (ref.isEmpty || !RegExp(r'^[A-Za-z0-9]').hasMatch(ref)) ref = 'x$ref';
    if (ref.length > 36) ref = ref.substring(0, 36);
    final reference = referenceText.length > 300
        ? referenceText.substring(0, 300)
        : referenceText;
    final result = await api.createAssessment(
      wire.AssessmentRequest(
        jobId: api.client.ids.next(),
        referenceExerciseId: ref,
        lessonVersion: 'v2',
        locale: 'en-US',
        wavBase64: base64Encode(wav),
        audioSha256: sha256.convert(wav).toString(),
        referenceText: reference,
      ),
      idempotencyKey: api.client.ids.next(),
    );
    return verdictFrom(result, reference);
  }
}

/// Null in mock/offline mode: speaking exercises then keep the typed fallback.
final speechAssessorProvider = Provider<SpeechAssessor?>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return null;
  return ApiSpeechAssessor(ref.watch(apiEndpointsProvider));
});
