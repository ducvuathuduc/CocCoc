import 'session_mode.dart';

/// Server-issued result of a session. [passThreshold] is echoed by the session
/// and [passed]/[unlockedNodeId] by its completion; the client never computes
/// or overrides them.
class SessionOutcome {
  const SessionOutcome({
    required this.mode,
    this.passThreshold,
    this.passed,
    this.unlockedNodeId,
  });

  final SessionMode mode;
  final double? passThreshold;
  final bool? passed;
  final String? unlockedNodeId;
}
