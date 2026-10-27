import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../../call/data/ai_capabilities.dart';

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

/// `POST /v1/assessment-jobs` on the AI service, then `GET
/// /v1/assessment-jobs/{jobId}` until the job reaches a terminal state or
/// `expiresAt`. Assessment is asynchronous: a QUEUED/RUNNING job carries no
/// numeric metrics, so the verdict stays nullable until the owner endpoint
/// returns a terminal assessment.
class ApiSpeechAssessor implements SpeechAssessor {
  ApiSpeechAssessor(
    this.api, {
    this.pollInterval = const Duration(milliseconds: 500),
    this.maxWait = const Duration(seconds: 30),
    DateTime Function()? now,
    Future<void> Function(Duration delay)? sleep,
  }) : now = now ?? DateTime.now,
       sleep = sleep ?? Future<void>.delayed;

  final ApiEndpoints api;
  final Duration pollInterval;
  final Duration maxWait;
  final DateTime Function() now;
  final Future<void> Function(Duration delay) sleep;

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
    final created = await api.createAssessment(
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
    return verdictFrom(await _awaitTerminal(created), reference);
  }

  /// Polls the owner endpoint for a queued/running job. A transport failure or
  /// expiry returns the last known assessment (unscored), never a fabricated
  /// score and never an infinite loop.
  Future<wire.Assessment> _awaitTerminal(wire.Assessment first) async {
    var current = first;
    final deadline = now().add(maxWait);
    final maxAttempts = pollInterval <= Duration.zero
        ? 1
        : (maxWait.inMicroseconds / pollInterval.inMicroseconds)
              .ceil()
              .clamp(1, 200)
              .toInt();
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!_pending(current)) return current;
      final expires = DateTime.tryParse(current.expiresAt);
      final stopAt = expires != null && expires.isBefore(deadline)
          ? expires
          : deadline;
      if (!now().isBefore(stopAt)) return current;
      try {
        await sleep(pollInterval);
      } catch (_) {
        return current;
      }
      if (!now().isBefore(stopAt)) return current;
      try {
        current = await api.getAssessment(current.jobId);
      } catch (_) {
        return current;
      }
    }
    return current;
  }

  static bool _pending(wire.Assessment a) =>
      a.status == 'QUEUED' || a.status == 'RUNNING';
}

/// Null in mock/offline mode: speaking exercises then keep the typed fallback.
/// In API mode the assessor exists only when the server's capability manifest
/// reports pronunciation enabled; a disabled or unreachable manifest fails
/// closed instead of enabling a provider locally.
final speechAssessorProvider = Provider<SpeechAssessor?>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return null;
  final caps = ref.watch(aiCapabilitiesProvider);
  if (caps.asData?.value?.pronunciation != true) return null;
  return ApiSpeechAssessor(ref.watch(apiEndpointsProvider));
});
