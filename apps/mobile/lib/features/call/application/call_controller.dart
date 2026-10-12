import 'dart:async';

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/speech_recorder.dart';

import '../data/call_repository.dart';
import '../domain/call_models.dart';

/// Drives the video-call state machine:
/// idle → ringing → connected → ended → review → upsell.
/// Timing comes from the [CallSession]. In API mode ([CallTurns]) the learner
/// turn is recorded from the microphone (tap the mic to start, tap again to
/// send; auto-sends at [speechMaxSeconds]) and transcribed by the server.
class CallController extends Notifier<CallState> {
  Timer? _timer;
  Completer<void>? _stopListening;

  @override
  CallState build() {
    ref.onDispose(_cancel);
    return const CallState();
  }

  CallRepository get _repository => ref.read(callRepositoryProvider);

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _after(Duration delay, void Function() action) {
    _cancel();
    _timer = Timer(delay, () {
      if (ref.mounted) action();
    });
  }

  /// Places the call: loads the session and starts ringing.
  Future<void> start({String partnerId = 'lily'}) async {
    if (state.phase != CallPhase.idle) return;
    try {
      final session = await _repository.loadSession(partnerId);
      if (!ref.mounted) return;
      state = CallState(session: session, phase: CallPhase.ringing);
      _after(session.ringDuration, _connect);
    } on CallMaxRequired catch (e) {
      // API mode without Max: straight to the existing upsell phase.
      if (ref.mounted) {
        state = CallState(session: e.preview, phase: CallPhase.upsell);
      }
    } catch (error) {
      if (ref.mounted) state = state.copyWith(error: '$error');
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
    // Learner turn: wait for the mic.
  }

  /// Mic press on the learner's turn. Mock "listening" then commits the line.
  void pressMic() {
    if (state.phase == CallPhase.connected &&
        state.listening &&
        _stopListening != null &&
        !_stopListening!.isCompleted) {
      // Second tap while recording: send the turn now.
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
      unawaited(_speak(turns));
      return;
    }
    _after(state.session!.listenDuration, () {
      state = state.copyWith(listening: false, cursor: state.cursor + 1);
      _schedulePartner();
    });
  }

  /// API mode: sends the learner turn; the server transcript replaces the
  /// learner line and its reply becomes the partner's next line. The listening
  /// state lasts at least the session's listen duration.
  Future<void> _speak(CallTurns turns) async {
    final session = state.session!;
    final at = state.cursor;
    final recorder = ref.read(speechRecorderProvider);
    try {
      Uint8List? wav;
      if (await recorder.start()) {
        final stop = _stopListening = Completer<void>();
        await Future.any<void>([
          stop.future,
          Future<void>.delayed(const Duration(seconds: speechMaxSeconds)),
        ]);
        _stopListening = null;
        wav = await recorder.stop();
        if (!ref.mounted || state.cursor != at) return;
      }
      final results = await Future.wait<Object?>([
        turns.speakTurn(session.id, at, wav: wav),
        if (wav == null) Future<void>.delayed(session.listenDuration),
      ]);
      final turn = results.first! as CallTurnResult;
      if (!ref.mounted ||
          state.phase != CallPhase.connected ||
          state.session?.id != session.id ||
          state.cursor != at) {
        return;
      }
      final script = [...state.session!.script];
      if (turn.transcript.trim().isNotEmpty) {
        script[at] = CallLine(
          speaker: CallSpeaker.learner,
          text: turn.transcript,
        );
      }
      if (at + 1 < script.length &&
          script[at + 1].speaker == CallSpeaker.partner &&
          turn.reply.trim().isNotEmpty) {
        script[at + 1] = CallLine(
          speaker: CallSpeaker.partner,
          text: turn.reply,
        );
      }
      state = state.copyWith(
        session: state.session!.withScript(script),
        listening: false,
        cursor: at + 1,
      );
      _schedulePartner();
    } catch (_) {
      // Turn not accepted: stay on the learner's line so the mic can retry.
      if (ref.mounted && state.cursor == at) {
        state = state.copyWith(listening: false);
      }
    }
  }

  void hangUp() {
    if (state.phase != CallPhase.ringing &&
        state.phase != CallPhase.connected) {
      return;
    }
    _cancel();
    final session = state.session!;
    state = state.copyWith(phase: CallPhase.ended, listening: false);
    unawaited(
      _repository
          .completeCall(session.id, state.cursor)
          .catchError((Object _) {}),
    );
  }

  /// CONTINUE: ended → review → upsell.
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
