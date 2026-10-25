import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../roleplay/domain/server_scenarios.dart';
import '../domain/call_models.dart';
import 'call_repository.dart';

final class CallCaptureFailure implements Exception {
  const CallCaptureFailure(this.message);
  final String message;
}

final class _PendingVoiceTurn {
  const _PendingVoiceTurn(this.request, this.audioSha256);
  final wire.TurnRequest request;
  final String audioSha256;
}

class _LiveCall {
  _LiveCall(this.voiceSessionId, this.epoch, this.steps);
  final String voiceSessionId;
  final int epoch;
  final int steps;
  int spoken = 0;
}

/// [CallRepository] for the Max video call against the AI service: a TURN
/// voice session (`POST /v1/voice-sessions`), a VIDEO_CALL conversation on the
/// partner's server scenario ([callServerLinks]) bound to it, one
/// `POST /v1/voice-sessions/{id}/turns` per learner line (the server's reply
/// becomes the partner's next line), and completion on hang-up: COMPLETED once
/// every step was spoken, USER_EXIT otherwise. Partner name, art and copy stay
/// the bundled [content]; the dialogue is the server script.
class ApiCallRepository implements CallRepository, CallTurns {
  ApiCallRepository(
    this.api,
    this.course, {
    this.content = const MockCallRepository(),
  });

  final ApiEndpoints api;
  final ActiveCourse course;

  /// Bundled call presentation (partner, copy, timing), not user data.
  final CallRepository content;

  final Map<String, _LiveCall> _live = {};
  final Map<(String, int), _PendingVoiceTurn> _pendingTurns = {};

  /// Server script as call lines: partner, learner (model answer, replaced by
  /// the server transcript when spoken), …, partner closing.
  static List<CallLine> scriptFor(ServerScenario server) => [
    for (final step in server.steps) ...[
      CallLine(speaker: CallSpeaker.partner, text: step.partner),
      CallLine(speaker: CallSpeaker.learner, text: step.expect),
    ],
    CallLine(speaker: CallSpeaker.partner, text: server.closing),
  ];

  @override
  Future<CallSession> loadSession(String partnerId) async {
    final preview = await content.loadSession(partnerId);
    final server = serverScenarioById(callServerScenarioIdFor(partnerId))!;
    final voiceSessionId = api.client.ids.next();
    final lease = await api.createVoiceSession(
      wire.VoiceRequest(
        sessionId: voiceSessionId,
        scenarioId: server.id,
        mode: 'TURN',
        level: server.level,
      ),
    );
    final epoch = switch (lease) {
      wire.TurnVoiceLease(:final epoch) => epoch,
      wire.LiveVoiceLease(:final epoch) => epoch,
    };
    final wire.Conversation conversation;
    try {
      conversation = await api.startConversation(
        wire.ConversationStartRequest(
          kind: 'VIDEO_CALL',
          courseId: await course.id(),
          scenarioId: server.id,
          voiceSessionId: voiceSessionId,
        ),
      );
    } catch (error) {
      await _closeVoice(voiceSessionId);
      if (error is ApiException && error.code == 'ENTITLEMENT_REQUIRED') {
        throw CallMaxRequired(preview);
      }
      rethrow;
    }
    _live[conversation.conversationId] = _LiveCall(
      voiceSessionId,
      epoch,
      server.steps.length,
    );
    return preview
        .withScript(scriptFor(server))
        .withId(conversation.conversationId);
  }

  Future<void> _closeVoice(String voiceSessionId) async {
    try {
      await api.closeVoiceSession(voiceSessionId);
    } catch (_) {}
  }

  @override
  Future<CallTurnResult> speakTurn(
    String sessionId,
    int cursor, {
    Uint8List? wav,
  }) async {
    final live = _live[sessionId];
    if (live == null) throw StateError('No live call $sessionId');
    if (wav == null || !_isCapturedWav(wav)) {
      throw const CallCaptureFailure('A recorded WAV clip is required.');
    }
    final key = (sessionId, cursor);
    final audioSha256 = sha256.convert(wav).toString();
    final previous = _pendingTurns[key];
    if (previous != null && previous.audioSha256 != audioSha256) {
      throw const CallCaptureFailure(
        'Retry the pending turn before recording another clip.',
      );
    }
    final pending =
        previous ??
        _PendingVoiceTurn(
          wire.TurnRequest(
            turnId: api.client.ids.next(),
            epoch: live.epoch,
            wavBase64: base64Encode(wav),
            audioSha256: audioSha256,
          ),
          audioSha256,
        );
    _pendingTurns[key] = pending;
    final result = await api.submitVoiceTurn(
      live.voiceSessionId,
      pending.request,
    );
    _pendingTurns.remove(key);
    live.spoken++;
    return CallTurnResult(
      transcript: result.transcript,
      reply: result.tutor.tutorText,
    );
  }

  @override
  Future<void> completeCall(String sessionId, int linesSpoken) async {
    final live = _live.remove(sessionId);
    _pendingTurns.removeWhere((key, _) => key.$1 == sessionId);
    final finished = live != null && live.spoken >= live.steps;
    Future<void> end(String reason) => api.completeConversation(
      sessionId,
      wire.ConversationCompleteRequest(endReason: reason),
    );
    try {
      await end(finished ? 'COMPLETED' : 'USER_EXIT');
    } on ApiException catch (e) {
      // Server still has steps left: close the run as an exit instead.
      if (e.code != 'SESSION_INCOMPLETE') rethrow;
      await end('USER_EXIT');
    }
  }

  static bool _isCapturedWav(Uint8List wav) {
    if (wav.length <= 44) return false;
    final bytes = ByteData.sublistView(wav);
    String tag(int offset) =>
        String.fromCharCodes(wav.sublist(offset, offset + 4));
    return tag(0) == 'RIFF' &&
        tag(8) == 'WAVE' &&
        tag(36) == 'data' &&
        bytes.getUint32(40, Endian.little) > 0 &&
        bytes.getUint32(40, Endian.little) <= wav.length - 44;
  }
}

extension on CallSession {
  CallSession withId(String id) => CallSession(
    id: id,
    partnerName: partnerName,
    learnerInitial: learnerInitial,
    xpReward: xpReward,
    script: script,
    copy: copy,
    ringDuration: ringDuration,
    partnerLineDuration: partnerLineDuration,
    listenDuration: listenDuration,
  );
}
