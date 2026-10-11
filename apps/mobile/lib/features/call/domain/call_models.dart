/// Video Call (Max) domain. Pure Dart: no Flutter imports.
library;

/// Call state machine: ringing → connected → ended → review → upsell.
enum CallPhase { idle, ringing, connected, ended, review, upsell }

enum CallSpeaker { partner, learner }

class CallLine {
  const CallLine({required this.speaker, required this.text});
  final CallSpeaker speaker;
  final String text;
}

/// Screen copy for the call flow. Comes from the repository so a backend
/// (or localisation) can replace it without touching widgets.
class CallCopy {
  const CallCopy({
    required this.introTitle,
    required this.introCallLabel,
    required this.introLaterLabel,
    required this.callingLabel,
    required this.earnedLabel,
    required this.reviewTitle,
    required this.continueLabel,
    required this.upsellLead,
    required this.upsellHighlight,
    required this.upsellTail,
    required this.upgradeLabel,
    required this.noThanksLabel,
    required this.phoneKicker,
    required this.maxBadge,
    required this.listeningLabel,
  });
  final String introTitle;
  final String introCallLabel;
  final String introLaterLabel;
  final String callingLabel;
  final String earnedLabel;
  final String reviewTitle;
  final String continueLabel;
  final String upsellLead;
  final String upsellHighlight;
  final String upsellTail;
  final String upgradeLabel;
  final String noThanksLabel;
  final String phoneKicker;
  final String maxBadge;
  final String listeningLabel;
}

class CallSession {
  const CallSession({
    required this.id,
    required this.partnerName,
    required this.learnerInitial,
    required this.xpReward,
    required this.script,
    required this.copy,
    this.ringDuration = const Duration(seconds: 2),
    this.partnerLineDuration = const Duration(milliseconds: 2400),
    this.listenDuration = const Duration(milliseconds: 1200),
  });
  final String id;
  final String partnerName;
  final String learnerInitial;
  final int xpReward;
  final List<CallLine> script;
  final CallCopy copy;
  final Duration ringDuration;
  final Duration partnerLineDuration;
  final Duration listenDuration;
}

class CallState {
  const CallState({
    this.session,
    this.phase = CallPhase.idle,
    this.cursor = 0,
    this.listening = false,
    this.micMuted = false,
    this.error,
  });
  final CallSession? session;
  final CallPhase phase;

  /// Number of script lines already spoken.
  final int cursor;
  final bool listening;
  final bool micMuted;
  final String? error;

  List<CallLine> get spoken =>
      session == null ? const [] : session!.script.take(cursor).toList();
  CallLine? get caption => cursor == 0 ? null : session!.script[cursor - 1];
  CallLine? get next =>
      session == null || cursor >= session!.script.length
      ? null
      : session!.script[cursor];
  bool get awaitingLearner => next?.speaker == CallSpeaker.learner;

  CallState copyWith({
    CallSession? session,
    CallPhase? phase,
    int? cursor,
    bool? listening,
    bool? micMuted,
    String? error,
  }) => CallState(
    session: session ?? this.session,
    phase: phase ?? this.phase,
    cursor: cursor ?? this.cursor,
    listening: listening ?? this.listening,
    micMuted: micMuted ?? this.micMuted,
    error: error,
  );
}
