import 'dart:async';

import '../../../core/api/api_contracts.dart' as wire;

/// Periodic advisory heartbeat for one open voice session.
///
/// The server treats heartbeats as telemetry only: they never release budget
/// and never prove provider usage. Failures are swallowed so a lost heartbeat
/// cannot interrupt the conversation. [stop] is called when the session closes
/// (hang-up, completion or abandon) and is idempotent.
final class VoiceSessionHeartbeat {
  VoiceSessionHeartbeat({
    required this._beat,
    required this.epoch,
    this.interval = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'must be positive');
    }
  }

  /// Echoes the server-issued lease epoch; the client never invents one.
  final int epoch;
  final Duration interval;
  final DateTime Function() clock;
  final Future<void> Function(wire.VoiceHeartbeat body) _beat;

  Timer? _timer;
  DateTime? _startedAt;
  int _turnCount = 0;
  bool _sending = false;
  bool _stopped = false;

  bool get running => _timer != null;

  void start() {
    if (_stopped || _timer != null) return;
    _startedAt ??= clock();
    _timer = Timer.periodic(interval, (_) => unawaited(ping()));
  }

  /// Counts one completed learner turn for `turnCount`.
  void countTurn() {
    if (_turnCount < 50) _turnCount++;
  }

  /// Sends one heartbeat now. Public so lifecycle code and tests can probe the
  /// current elapsed/turn values without waiting for the timer.
  Future<void> ping() async {
    if (_stopped || _sending) return;
    _sending = true;
    try {
      final started = _startedAt;
      final elapsed = started == null
          ? 0
          : clock().difference(started).inSeconds.clamp(0, 180).toInt();
      await _beat(
        wire.VoiceHeartbeat(
          epoch: epoch,
          elapsedSeconds: elapsed,
          turnCount: _turnCount,
        ),
      );
    } catch (_) {
      // Advisory only; a dropped heartbeat must not break the session.
    } finally {
      _sending = false;
    }
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }
}
