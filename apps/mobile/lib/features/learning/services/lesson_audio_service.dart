import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/application/preview_controller.dart';
import '../data/lesson_audio_io_stub.dart'
    if (dart.library.io) '../data/lesson_audio_io.dart'
    as platform;
import '../data/lesson_audio_store.dart';
import '../domain/learning_models.dart';

/// Lesson sound effects (original synthesized files in `assets/sfx/`, see
/// tools/content/sfx/synth_sfx.py and assets/PROVENANCE.md).
enum LessonSfx {
  correct('sfx/correct.wav'),
  incorrect('sfx/incorrect.wav'),
  combo('sfx/combo.wav'),
  heartLoss('sfx/heart_loss.wav'),
  lessonComplete('sfx/lesson_complete.wav'),
  streak('sfx/streak.wav');

  const LessonSfx(this.asset);

  /// Path relative to `assets/`.
  final String asset;
}

/// The native audio sink (wrapped vendor plugin). Two channels like the
/// reference app: voice clips replace each other; effects overlay them.
abstract class LessonSoundOutput {
  Future<void> playVoice(LessonAudioSource source);
  Future<void> playEffect(String asset);
  Future<void> stopVoice();
  void dispose();
}

/// `audioplayers` implementation (Android MediaPlayer/ExoPlayer, iOS
/// AVPlayer). Every call is best effort: a missing codec or plugin must never
/// break a lesson.
class AudioplayersSoundOutput implements LessonSoundOutput {
  AudioPlayer? _voice;
  final List<AudioPlayer?> _effects = [null, null];
  int _nextEffect = 0;

  AudioPlayer get _voicePlayer =>
      _voice ??= AudioPlayer(playerId: 'lesson-voice')
        ..setReleaseMode(ReleaseMode.stop);

  /// Two low-latency effect players used in turn, so a heart-loss pop can
  /// overlap the "incorrect" sound instead of cutting it off.
  AudioPlayer _effectPlayer() {
    final index = _nextEffect;
    _nextEffect = (_nextEffect + 1) % _effects.length;
    return _effects[index] ??= AudioPlayer(playerId: 'lesson-sfx-$index')
      ..setReleaseMode(ReleaseMode.stop)
      ..setPlayerMode(PlayerMode.lowLatency);
  }

  @override
  Future<void> playVoice(LessonAudioSource source) async {
    try {
      final player = _voicePlayer;
      await player.stop();
      await player.play(switch (source) {
        BundledLessonAudio(:final path) => AssetSource(path),
        CachedLessonAudio(:final path) => DeviceFileSource(path),
      });
    } on Object catch (error) {
      debugPrint('lesson audio: $error');
    }
  }

  @override
  Future<void> playEffect(String asset) async {
    try {
      final player = _effectPlayer();
      await player.stop();
      await player.play(AssetSource(asset));
    } on Object catch (error) {
      debugPrint('lesson sfx: $error');
    }
  }

  @override
  Future<void> stopVoice() async {
    try {
      await _voice?.stop();
    } on Object {
      // Nothing to stop.
    }
  }

  @override
  void dispose() {
    unawaited(_voice?.dispose());
    for (final player in _effects) {
      unawaited(player?.dispose());
    }
  }
}

/// No-op sink for widget tests (no audio plugin) and headless runs.
class SilentSoundOutput implements LessonSoundOutput {
  @override
  Future<void> playVoice(LessonAudioSource source) async {}

  @override
  Future<void> playEffect(String asset) async {}

  @override
  Future<void> stopVoice() async {}

  @override
  void dispose() {}
}

/// Lesson audio for the views: prompt clips (normal / slow), tap-to-hear
/// words and sound effects. Voice playback always works; effects follow the
/// "Sound effects" setting.
class LessonAudioService {
  LessonAudioService({
    required this.store,
    required this.output,
    bool Function()? effectsEnabled,
  }) : _effectsEnabled = effectsEnabled ?? (() => true);

  final LessonAudioStore store;
  final LessonSoundOutput output;
  final bool Function() _effectsEnabled;
  int _generation = 0;

  /// Plays [clip] (replacing any clip still playing). Returns whether a
  /// source was found; resolution that finishes after a newer request is
  /// dropped so a slow download never talks over the next exercise.
  Future<bool> play(LessonAudio? clip) async {
    if (clip == null || output is SilentSoundOutput) return false;
    final generation = ++_generation;
    final source = await store.resolve(clip);
    if (source == null || generation != _generation) return false;
    await output.playVoice(source);
    return true;
  }

  /// The clip for an English tile/option [text]: the bundle's word audio, or
  /// a word clip shipped with the app (mock course).
  LessonAudio? wordClip(Exercise exercise, String text) =>
      exercise.wordAudio[wordAudioSlug(text)] ?? store.bundledWord(text);

  Future<bool> playWord(Exercise exercise, String text) =>
      play(wordClip(exercise, text));

  Future<void> effect(LessonSfx sfx) async {
    if (!_effectsEnabled()) return;
    await output.playEffect(sfx.asset);
  }

  /// [effect] after [delay] (no timer at all when effects are off or there
  /// is no audio device, e.g. widget tests).
  Future<void> effectAfter(LessonSfx sfx, Duration delay) async {
    if (!_effectsEnabled() || output is SilentSoundOutput) return;
    await Future<void>.delayed(delay);
    await effect(sfx);
  }

  Future<void> stop() {
    _generation++;
    return output.stopVoice();
  }

  /// Downloads the lesson's prompt clips ahead of time (API mode).
  Future<void> prefetch(Iterable<Exercise> exercises) async {
    if (output is SilentSoundOutput) return;
    await store.prefetch([
      for (final e in exercises) ...[?e.audio, ?e.slowAudio],
    ]);
  }
}

final lessonSoundOutputProvider = Provider<LessonSoundOutput>((ref) {
  final output = platform.runningUnderFlutterTest
      ? SilentSoundOutput()
      : AudioplayersSoundOutput();
  ref.onDispose(output.dispose);
  return output;
});

final lessonAudioServiceProvider = Provider<LessonAudioService>((ref) {
  return LessonAudioService(
    store: ref.watch(lessonAudioStoreProvider),
    output: ref.watch(lessonSoundOutputProvider),
    effectsEnabled: () => ref.read(previewControllerProvider).sound,
  );
});
