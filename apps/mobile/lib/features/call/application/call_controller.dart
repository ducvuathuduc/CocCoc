import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/speech_recorder.dart';
import '../../auth/application/auth_controller.dart';
import '../data/call_repository.dart';
import '../domain/call_models.dart';

final callAccountIdentityProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider.select((state) => state.user?.id));
});

final class _PendingCapture {
  const _PendingCapture(this.sessionId, this.cursor, this.wav);
  final String sessionId;
  final int cursor;
  final Uint8List wav;
}

/// Drives the video-call state machine:
/// idle → ringing → connected → ended → review → upsell.
class CallController extends Notifier<CallState> {
  Timer? _timer;
  Completer<void>? _stopListening;
  SpeechRecorder? _activeRecorder;
  _PendingCapture? _pendingCapture;
  late CallRepository _repository;
  String? _accountId;
  int _generation = 0;
  bool _initialized = false;
  bool _disposed = false;

  @override
  CallState build() {
    final repository = ref.watch(callRepositoryProvider);
    final accountId = ref.watch(callAccountIdentityProvider);
    if (!_initialized) {
      _initialized = true;
      ref.onDispose(() {
        _disposed = true;
        _generation++;
        _cancelCapture();
      });
    } else {
      _generation++;
      _cancelCapture();
    }
    _repository = repository;
    _accountId = accountId;
    return const CallState();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _cancelCapture({bool clearPending = true}) {
    _cancelTimer();
    final stop = _stopListening;
    if (stop != null && !stop.isCompleted) stop.complete();
    _stopListening = null;
    final recorder = _activeRecorder;
    _activeRecorder = null;
    if (recorder != null) unawaited(recorder.cancel());
    if (clearPending) _pendingCapture = null;
  }

  bool _current(int generation, CallRepository repository) =>
      !_disposed &&
      ref.mounted &&
      generation == _generation &&
      identical(repository, _repository);

  void _after(Duration delay, void Function() action) {
    _cancelTimer();
    final generation = _generation;
    final repository = _repository;
    _timer = Timer(delay, () {
      if (_current(generation, repository)) action();
    });
  }

  Future<void> start({String partnerId = 'lily'}) async {
    if (state.phase != CallPhase.idle) return;
    final repository = _repository;
    final generation = _generation;
    final accountId = _accountId;
    try {
      final session = await repository.loadSession(partnerId);
      if (!_current(generation, repository) || accountId != _accountId) return;
      state = CallState(session: session, phase: CallPhase.ringing);
      _after(session.ringDuration, _connect);
    } on CallMaxRequired catch (error) {
      if (_current(generation, repository) && accountId == _accountId) {
        state = CallState(session: error.preview, phase: CallPhase.upsell);
      }
    } catch (_) {
      if (_current(generation, repository) && accountId == _accountId) {
        state = state.copyWith(error: 'We couldn’t start the call. Try again.');
      }
    }
  }

  void _connect() {
    state = state.copyWith(phase: CallPhase.connected, cursor: 0);
    _schedulePartner();
  }

  void _schedulePartner() {
    final session = state.session!;
    final next = state.next;
    if (next == null) {
      _after(session.partnerLineDuration, hangUp);
    } else if (next.speaker == CallSpeaker.partner) {
      _after(session.partnerLineDuration, () {
        state = state.copyWith(cursor: state.cursor + 1);
        _schedulePartner();
      });
    }
  }

  void pressMic() {
    if (state.phase == CallPhase.connected &&
        state.listening &&
        _stopListening != null &&
        !_stopListening!.isCompleted) {
      _stopListening!.complete();
      return;
    }
    if (state.phase != CallPhase.connected ||
        !state.awaitingLearner ||
        state.listening) {
      return;
    }
    state = state.copyWith(listening: true);
    if (_repository case final CallTurns turns) {
      final pending = _pendingCapture;
      if (pending != null &&
          pending.sessionId == state.session!.id &&
          pending.cursor == state.cursor) {
        unawaited(_submit(turns, pending));
      } else {
        unawaited(_record(turns));
      }
      return;
    }
    _after(state.session!.listenDuration, () {
      state = state.copyWith(listening: false, cursor: state.cursor + 1);
      _schedulePartner();
    });
  }

  Future<void> _record(CallTurns turns) async {
    final repository = _repository;
    final generation = _generation;
    final session = state.session!;
    final cursor = state.cursor;
    final recorder = ref.read(speechRecorderProvider);
    _activeRecorder = recorder;
    try {
      final started = await recorder.start();
      if (!_currentTurn(generation, repository, session.id, cursor)) {
        await recorder.cancel();
        return;
      }
      if (!started) {
        _activeRecorder = null;
        state = state.copyWith(
          listening: false,
          error: 'Microphone access is required. Check permission and retry.',
        );
        return;
      }
      final stop = _stopListening = Completer<void>();
      await Future.any<void>([
        stop.future,
        Future<void>.delayed(const Duration(seconds: speechMaxSeconds)),
      ]);
      _stopListening = null;
      if (!_currentTurn(generation, repository, session.id, cursor)) {
        await recorder.cancel();
        return;
      }
      final wav = await recorder.stop();
      if (identical(_activeRecorder, recorder)) _activeRecorder = null;
      if (!_currentTurn(generation, repository, session.id, cursor)) return;
      if (wav == null || wav.length <= 44) {
        state = state.copyWith(
          listening: false,
          error: 'No audio was captured. Tap the microphone and try again.',
        );
        return;
      }
      final pending = _PendingCapture(session.id, cursor, wav);
      _pendingCapture = pending;
      await _submit(turns, pending);
    } catch (_) {
      if (identical(_activeRecorder, recorder)) _activeRecorder = null;
      await recorder.cancel();
      if (_currentTurn(generation, repository, session.id, cursor)) {
        state = state.copyWith(
          listening: false,
          error: 'We couldn’t record your voice. Check permission and retry.',
        );
      }
    }
  }

  Future<void> _submit(CallTurns turns, _PendingCapture pending) async {
    final repository = _repository;
    final generation = _generation;
    try {
      final turn = await turns.speakTurn(
        pending.sessionId,
        pending.cursor,
        wav: pending.wav,
      );
      if (!_currentTurn(
        generation,
        repository,
        pending.sessionId,
        pending.cursor,
      )) {
        return;
      }
      _pendingCapture = null;
      final script = [...state.session!.script];
      if (turn.transcript.trim().isNotEmpty) {
        script[pending.cursor] = CallLine(
          speaker: CallSpeaker.learner,
          text: turn.transcript,
        );
      }
      if (pending.cursor + 1 < script.length &&
          script[pending.cursor + 1].speaker == CallSpeaker.partner &&
          turn.reply.trim().isNotEmpty) {
        script[pending.cursor + 1] = CallLine(
          speaker: CallSpeaker.partner,
          text: turn.reply,
        );
      }
      state = state.copyWith(
        session: state.session!.withScript(script),
        listening: false,
        cursor: pending.cursor + 1,
      );
      _schedulePartner();
    } catch (_) {
      if (_currentTurn(
        generation,
        repository,
        pending.sessionId,
        pending.cursor,
      )) {
        state = state.copyWith(
          listening: false,
          error: 'We couldn’t send your voice. Tap the microphone to retry.',
        );
      }
    }
  }

  bool _currentTurn(
    int generation,
    CallRepository repository,
    String sessionId,
    int cursor,
  ) =>
      _current(generation, repository) &&
      state.phase == CallPhase.connected &&
      state.session?.id == sessionId &&
      state.cursor == cursor;

  void hangUp() {
    if (state.phase != CallPhase.ringing &&
        state.phase != CallPhase.connected) {
      return;
    }
    final repository = _repository;
    final session = state.session!;
    final cursor = state.cursor;
    _generation++;
    _cancelCapture();
    state = state.copyWith(phase: CallPhase.ended, listening: false);
    unawaited(
      repository.completeCall(session.id, cursor).catchError((Object _) {}),
    );
  }

  void advance() {
    state = switch (state.phase) {
      CallPhase.ended => state.copyWith(phase: CallPhase.review),
      CallPhase.review => state.copyWith(phase: CallPhase.upsell),
      _ => state,
    };
  }
}

final callControllerProvider =
    NotifierProvider.autoDispose<CallController, CallState>(CallController.new);
