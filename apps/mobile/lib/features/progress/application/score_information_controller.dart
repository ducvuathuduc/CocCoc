import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/score_information.dart';

typedef ScoreClipboardWriter = Future<void> Function(String value);

final scoreClipboardWriterProvider = Provider<ScoreClipboardWriter>(
  (_) =>
      (value) => Clipboard.setData(ClipboardData(text: value)),
);

class ScoreInformationState {
  const ScoreInformationState({
    this.selectedRange = 1,
    this.playingExample,
    this.copyError = false,
    this.copied = false,
    this.copyBusy = false,
  });
  final int selectedRange;
  final int? playingExample;
  final bool copyError;
  final bool copied;
  final bool copyBusy;
  ScoreBand get band => scoreBands[selectedRange];

  ScoreInformationState copyWith({
    int? selectedRange,
    int? playingExample,
    bool clearPlaying = false,
    bool? copyError,
    bool? copied,
    bool? copyBusy,
  }) => ScoreInformationState(
    selectedRange: selectedRange ?? this.selectedRange,
    playingExample: clearPlaying ? null : playingExample ?? this.playingExample,
    copyError: copyError ?? this.copyError,
    copied: copied ?? this.copied,
    copyBusy: copyBusy ?? this.copyBusy,
  );
}

final scoreInformationProvider =
    NotifierProvider<ScoreInformationController, ScoreInformationState>(
      ScoreInformationController.new,
    );

class ScoreInformationController extends Notifier<ScoreInformationState> {
  Timer? _timer;
  int _copyGeneration = 0;

  @override
  ScoreInformationState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _copyGeneration += 1;
    });
    return const ScoreInformationState();
  }

  void selectRange(int index) {
    if (index < 0 || index >= scoreBands.length) return;
    pause();
    state = state.copyWith(selectedRange: index);
  }

  void play(int index) {
    if (index < 0 || index >= state.band.examples.length) return;
    if (state.playingExample == index) {
      pause();
      return;
    }
    _timer?.cancel();
    state = state.copyWith(playingExample: index);
    _timer = Timer(const Duration(seconds: 2), pause);
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    if (!ref.mounted) return;
    state = state.copyWith(clearPlaying: true);
  }

  void resetCopyFeedback() {
    _copyGeneration += 1;
    if (!ref.mounted) return;
    state = state.copyWith(copyError: false, copied: false, copyBusy: false);
  }

  Future<void> copyScore(int score) async {
    if (!ref.mounted || state.copyBusy) return;
    final generation = ++_copyGeneration;
    state = state.copyWith(copyError: false, copied: false, copyBusy: true);
    try {
      await ref.read(scoreClipboardWriterProvider)(
        'My English Score is $score.',
      );
      if (!ref.mounted || generation != _copyGeneration) return;
      state = state.copyWith(copyError: false, copied: true, copyBusy: false);
    } catch (_) {
      if (!ref.mounted || generation != _copyGeneration) return;
      state = state.copyWith(copyError: true, copied: false, copyBusy: false);
    }
  }
}
