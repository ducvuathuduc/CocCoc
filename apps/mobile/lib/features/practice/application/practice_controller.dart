import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/practice_repository.dart';
import '../domain/practice_models.dart';

final practiceRepositoryProvider = Provider<PracticeRepository>(
  (_) => const MockPracticeRepository(),
);

final practiceControllerProvider =
    NotifierProvider<PracticeController, PracticeState>(PracticeController.new);

final speakingControllerProvider =
    NotifierProvider<SpeakingController, SpeakingState>(SpeakingController.new);

class PracticeController extends Notifier<PracticeState> {
  @override
  PracticeState build() => PracticeState(
    words: List<PracticeWord>.unmodifiable(
      ref.read(practiceRepositoryProvider).loadWords(),
    ),
  );

  void reveal() {
    if (state.current == null) return;
    state = state.copyWith(revealed: true);
  }

  void sort(WordSort order) => state = state.copyWith(wordSort: order);

  void remember() {
    final current = state.current;
    if (!state.revealed || current == null) return;
    state = state.copyWith(
      index: (state.index + 1) % state.words.length,
      revealed: false,
      recalledIds: <String>{...state.recalledIds, current.id},
    );
  }

  void practiceAgain() {
    if (!state.revealed || state.current == null) return;
    state = state.copyWith(
      index: (state.index + 1) % state.words.length,
      revealed: false,
    );
  }
}

class SpeakingController extends Notifier<SpeakingState> {
  Timer? _timer;
  int _revision = 0;
  bool _disposed = false;
  bool _recordingInterrupted = false;
  bool _callInterrupted = false;

  @override
  SpeakingState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _revision += 1;
      _timer?.cancel();
    });
    return const SpeakingState();
  }

  void showPermissionDenied() {
    cancelPending();
    state = state.copyWith(capability: SpeechCapability.permissionDenied);
  }

  void showUnsupported() {
    cancelPending();
    state = state.copyWith(capability: SpeechCapability.unsupported);
  }

  void resetCapability() {
    cancelPending();
    state = state.copyWith(capability: SpeechCapability.ready);
  }

  void startMockRecording() {
    cancelPending();
    _recordingInterrupted = false;
    final revision = ++_revision;
    state = state.copyWith(capability: SpeechCapability.capturing);
    _timer = Timer(const Duration(milliseconds: 450), () {
      if (_disposed || revision != _revision) return;
      state = state.copyWith(capability: SpeechCapability.unscored);
    });
  }

  void pauseRecordingForLifecycle() {
    if (state.capability != SpeechCapability.capturing) return;
    _recordingInterrupted = true;
    cancelPending();
  }

  void resumeRecordingAfterLifecycle() {
    if (!_recordingInterrupted) return;
    _recordingInterrupted = false;
    state = state.copyWith(capability: SpeechCapability.ready);
  }

  void startCall() {
    cancelPending();
    _callInterrupted = false;
    final revision = ++_revision;
    state = state.copyWith(
      callStage: CallStage.connecting,
      transcript: mockCallOpening,
    );
    _timer = Timer(const Duration(milliseconds: 350), () {
      if (_disposed || revision != _revision) return;
      state = state.copyWith(callStage: CallStage.responding);
    });
  }

  void reconnect() {
    cancelPending();
    final revision = ++_revision;
    state = state.copyWith(callStage: CallStage.reconnecting);
    _timer = Timer(const Duration(milliseconds: 350), () {
      if (_disposed || revision != _revision) return;
      state = state.copyWith(callStage: CallStage.responding);
    });
  }

  void pauseCallForLifecycle() {
    if (!{
      CallStage.connecting,
      CallStage.responding,
      CallStage.reconnecting,
    }.contains(state.callStage)) {
      return;
    }
    _callInterrupted = true;
    cancelPending();
    state = state.copyWith(callStage: CallStage.reconnecting);
  }

  void resumeCallAfterLifecycle() {
    if (!_callInterrupted) return;
    _callInterrupted = false;
    reconnect();
  }

  void sendTypedReply(String value) {
    final reply = value.trim();
    if (state.callStage != CallStage.responding || reply.isEmpty) return;
    state = state.copyWith(
      transcript: <ConversationLine>[
        ...state.transcript,
        ConversationLine(speaker: 'You', text: reply),
        const ConversationLine(speaker: 'Lily', text: 'Très bien.'),
      ],
    );
  }

  void endCall() {
    cancelPending();
    _callInterrupted = false;
    state = state.copyWith(callStage: CallStage.ended);
  }

  void cancelPending() {
    _revision += 1;
    _timer?.cancel();
    _timer = null;
  }
}
