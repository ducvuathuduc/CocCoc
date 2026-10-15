import 'dart:async';
import 'dart:typed_data';

import 'package:cocenglish/core/audio/speech_recorder.dart';
import 'package:cocenglish/features/learning/data/speech_assessment.dart';

class FakeRecorder implements SpeechRecorder {
  bool allowed = true;
  int starts = 0;
  int cancels = 0;
  int stops = 0;
  Uint8List? audio = pcm16ToWav(Uint8List(32000));
  Completer<bool>? permission;

  @override
  Future<bool> start() async {
    starts++;
    return permission == null ? allowed : await permission!.future;
  }

  @override
  Future<Uint8List?> stop() async {
    stops++;
    return audio;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class FakeAssessor implements SpeechAssessor {
  final calls = <({List<int> wav, String exerciseId, String reference})>[];
  Completer<SpeechVerdict>? pending;
  bool fails = false;
  SpeechVerdict verdict = const SpeechVerdict(
    scored: true,
    passed: true,
    transcript: 'Hello, I am Sam.',
    accuracy: 86,
    fluency: 79,
    completeness: 100,
    words: [
      SpokenWord(
        'Hello',
        accuracy: 90,
        phonemes: [SpokenPhoneme('h', 95), SpokenPhoneme('ə', 55)],
      ),
      SpokenWord('Sam', accuracy: 45, errorType: 'Mispronunciation'),
    ],
  );

  @override
  Future<SpeechVerdict> assess(
    Uint8List wav, {
    required String exerciseId,
    required String referenceText,
  }) async {
    calls.add((
      wav: wav.toList(),
      exerciseId: exerciseId,
      reference: referenceText,
    ));
    if (fails) throw StateError('offline');
    return pending == null ? verdict : await pending!.future;
  }
}
