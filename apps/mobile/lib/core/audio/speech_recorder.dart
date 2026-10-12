import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

/// Server contract for recorded speech (OpenAPI TurnRequest/AssessmentRequest):
/// 16 kHz mono 16-bit PCM WAV, at most 15 s.
const speechSampleRate = 16000;
const speechMaxSeconds = 15;
const _maxPcmBytes = speechSampleRate * 2 * speechMaxSeconds;

/// Microphone capture for speaking exercises and TURN voice calls.
///
/// [start] asks for the microphone permission (Android RECORD_AUDIO / iOS
/// NSMicrophoneUsageDescription prompt) and returns false when it is denied or
/// no recorder is available; [stop] returns the recorded WAV, or null when
/// nothing was captured.
abstract class SpeechRecorder {
  Future<bool> start();
  Future<Uint8List?> stop();
  Future<void> cancel();
}

/// Wraps raw little-endian PCM16 mono samples in a 44-byte RIFF/WAVE header.
Uint8List pcm16ToWav(Uint8List pcm, {int sampleRate = speechSampleRate}) {
  final header = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List(44 + pcm.length)
    ..setRange(0, 44, header.buffer.asUint8List())
    ..setRange(44, 44 + pcm.length, pcm);
}

/// [SpeechRecorder] on the `record` plugin: streams PCM16 at 16 kHz mono into
/// memory (no file), capped at [speechMaxSeconds].
class PluginSpeechRecorder implements SpeechRecorder {
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _sub;
  BytesBuilder _pcm = BytesBuilder(copy: false);

  @override
  Future<bool> start() async {
    try {
      await cancel();
      final recorder = _recorder ??= AudioRecorder();
      if (!await recorder.hasPermission()) return false;
      _pcm = BytesBuilder(copy: false);
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: speechSampleRate,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _sub = stream.listen((chunk) {
        final room = _maxPcmBytes - _pcm.length;
        if (room <= 0) return;
        _pcm.add(chunk.length <= room ? chunk : chunk.sublist(0, room));
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> stop() async {
    try {
      await _recorder?.stop();
    } catch (_) {}
    await _sub?.cancel();
    _sub = null;
    final pcm = _pcm.takeBytes();
    // Keep whole 16-bit samples; under ~0.1 s is "nothing captured".
    final even = pcm.length - pcm.length % 2;
    if (even < 3200) return null;
    return pcm16ToWav(Uint8List.sublistView(pcm, 0, even));
  }

  @override
  Future<void> cancel() async {
    await _sub?.cancel();
    _sub = null;
    _pcm = BytesBuilder(copy: false);
    try {
      if (await _recorder?.isRecording() ?? false) await _recorder?.stop();
    } catch (_) {}
  }
}

final speechRecorderProvider = Provider<SpeechRecorder>((ref) {
  final recorder = PluginSpeechRecorder();
  ref.onDispose(recorder.cancel);
  return recorder;
});
