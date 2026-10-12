import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';

/// One reference word with its pronunciation result (Duolingo-style
/// green/red). [accuracy] is null when the scorer gave no number.
class SpokenWord {
  const SpokenWord(this.word, {this.accuracy, this.errorType});
  final String word;
  final double? accuracy;
  final String? errorType;

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
  if (a.scoreState == 'VALID') {
    final words = [
      for (final w in a.words)
        if (w.errorType != 'Insertion')
          SpokenWord(
            w.word,
            accuracy: w.accuracy?.toDouble(),
            errorType: w.errorType,
          ),
    ];
    final accuracy = a.accuracy?.toDouble() ?? 0;
    final completeness = a.completeness?.toDouble() ?? 0;
    return SpeechVerdict(
      scored: true,
      passed: accuracy >= 70 && completeness >= 80,
      transcript: transcript,
      words: words,
      accuracy: accuracy,
    );
  }
  return SpeechVerdict(
    scored: false,
    passed:
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
