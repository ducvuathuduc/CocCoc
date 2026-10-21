import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/speech_recorder.dart';
import '../../learning/data/speech_assessment.dart';

enum PronunciationStage {
  ready,
  requesting,
  recording,
  assessing,
  stopping,
  result,
  error,
  unavailable,
}

class PronunciationState {
  const PronunciationState({
    this.stage = PronunciationStage.ready,
    this.index = 0,
    this.verdict,
    this.message,
  });

  static const sentences = [
    'Hello, I am Sam.',
    'Could you help me, please?',
    'I would like a cup of coffee.',
  ];

  final PronunciationStage stage;
  final int index;
  final SpeechVerdict? verdict;
  final String? message;
  String get reference => sentences[index];
  String get exerciseId => 'practice-pronunciation-${index + 1}';
  bool get busy => {
    PronunciationStage.requesting,
    PronunciationStage.recording,
    PronunciationStage.assessing,
    PronunciationStage.stopping,
  }.contains(stage);
}

final pronunciationControllerProvider =
    NotifierProvider.autoDispose<PronunciationController, PronunciationState>(
      PronunciationController.new,
    );

/// Practice feedback only. Never awards XP or sends a client grade to Learning.
class PronunciationController extends Notifier<PronunciationState> {
  late SpeechRecorder _recorder;
  SpeechAssessor? _assessor;
  Future<bool>? _starting;
  Timer? _limit;
  int _epoch = 0;
  bool _alive = false;

  @override
  PronunciationState build() {
    _recorder = ref.watch(speechRecorderProvider);
    _assessor = ref.watch(speechAssessorProvider);
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _epoch++;
      _limit?.cancel();
      unawaited(_releaseCapture());
    });
    return PronunciationState(
      stage: _assessor == null
          ? PronunciationStage.unavailable
          : PronunciationStage.ready,
    );
  }

  bool _current(int epoch) => _alive && _epoch == epoch;

  Future<void> _releaseCapture() async {
    final recorder = _recorder;
    final starting = _starting;
    try {
      await starting;
    } catch (_) {
      // Permission/recorder failures still need cleanup.
    }
    try {
      await recorder.cancel();
    } catch (_) {
      // Native cleanup is best effort; it must not resurrect an old attempt.
    }
  }

  Future<void> start() async {
    if (state.busy || _assessor == null) return;
    final epoch = ++_epoch;
    final index = state.index;
    state = PronunciationState(
      stage: PronunciationStage.requesting,
      index: index,
    );
    try {
      _starting = _recorder.start();
      final allowed = await _starting!;
      if (!_current(epoch)) return;
      if (!allowed) {
        await _releaseCapture();
        if (!_current(epoch)) return;
        state = PronunciationState(
          stage: PronunciationStage.error,
          index: index,
          message: 'Microphone unavailable',
        );
        return;
      }
      state = PronunciationState(
        stage: PronunciationStage.recording,
        index: index,
      );
      _limit = Timer(
        const Duration(seconds: speechMaxSeconds),
        () => unawaited(stop()),
      );
    } catch (_) {
      await _releaseCapture();
      if (!_current(epoch)) return;
      state = PronunciationState(
        stage: PronunciationStage.error,
        index: index,
        message: 'Microphone unavailable',
      );
    }
  }

  Future<void> stop() async {
    if (state.stage != PronunciationStage.recording) return;
    _limit?.cancel();
    final epoch = _epoch;
    final attempt = state;
    state = PronunciationState(
      stage: PronunciationStage.assessing,
      index: attempt.index,
    );
    try {
      final wav = await _recorder.stop();
      if (!_current(epoch)) return;
      if (wav == null || wav.isEmpty) {
        state = PronunciationState(
          stage: PronunciationStage.error,
          index: attempt.index,
          message: 'No audio captured. Try speaking again.',
        );
        return;
      }
      final verdict = await _assessor!
          .assess(
            wav,
            exerciseId: attempt.exerciseId,
            referenceText: attempt.reference,
          )
          .timeout(const Duration(seconds: 60));
      if (!_current(epoch)) return;
      state = PronunciationState(
        stage: PronunciationStage.result,
        index: attempt.index,
        verdict: verdict,
      );
    } catch (_) {
      await _releaseCapture();
      if (!_current(epoch)) return;
      state = PronunciationState(
        stage: PronunciationStage.error,
        index: attempt.index,
        message: 'Could not assess this recording. Check your connection and try again.',
      );
    }
  }

  /// Invalidate pending permission/provider work before releasing native capture.
  Future<void> interrupt() async {
    if (!_alive || !state.busy || state.stage == PronunciationStage.stopping) {
      return;
    }
    final epoch = ++_epoch;
    final index = state.index;
    _limit?.cancel();
    state = PronunciationState(
      stage: PronunciationStage.stopping,
      index: index,
    );
    await _releaseCapture();
    if (!_current(epoch)) return;
    state = PronunciationState(
      index: index,
      message: 'Recording stopped. Tap to try again.',
    );
  }

  void next() {
    if (state.busy || state.stage != PronunciationStage.result) return;
    _epoch++;
    state = PronunciationState(
      index: (state.index + 1) % PronunciationState.sentences.length,
    );
  }
}
