import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/call_repository.dart';
import '../domain/call_models.dart';

/// Drives the video-call state machine:
/// idle → ringing → connected → ended → review → upsell.
/// All timing comes from the [CallSession]; no real audio is used.
class CallController extends Notifier<CallState> {
  Timer? _timer;

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
    if (state.phase != CallPhase.connected ||
        !state.awaitingLearner ||
        state.listening) {
      return;
    }
    state = state.copyWith(listening: true);
    _after(state.session!.listenDuration, () {
      state = state.copyWith(listening: false, cursor: state.cursor + 1);
      _schedulePartner();
    });
  }

  void hangUp() {
    if (state.phase != CallPhase.ringing && state.phase != CallPhase.connected) {
      return;
    }
    _cancel();
    final session = state.session!;
    state = state.copyWith(phase: CallPhase.ended, listening: false);
    unawaited(_repository.completeCall(session.id, state.cursor));
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
    NotifierProvider.autoDispose<CallController, CallState>(
      CallController.new,
    );
