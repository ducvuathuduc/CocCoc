import 'dart:convert';
import 'dart:typed_data';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../roleplay/domain/server_scenarios.dart';
import '../domain/call_models.dart';
import 'call_repository.dart';

/// Fallback learner audio for TURN voice turns when nothing was recorded
/// (microphone denied/unavailable): 0.1 s of 16 kHz mono 16-bit PCM silence.
/// The scripted provider answers it with the step's model line; the real
/// speech provider hears nothing, so the script waits for a retry.
final Uint8List turnPlaceholderWav = () {
  const dataBytes = 3200;
  final b = ByteData(44 + dataBytes);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, 16000, Endian.little);
  b.setUint32(28, 32000, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  return b.buffer.asUint8List();
}();

/// SHA-256 (hex) of [turnPlaceholderWav]; checked by the call repository test.
const turnPlaceholderWavSha256 =
    '2976da01e205a110c9fa41d47659e238a5c6d3c3f3137582f2949853faa201dd';

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
    final result = await api.submitVoiceTurn(
      live.voiceSessionId,
      wire.TurnRequest(
        turnId: api.client.ids.next(),
        epoch: live.epoch,
        wavBase64: base64Encode(wav ?? turnPlaceholderWav),
        audioSha256: wav == null
            ? turnPlaceholderWavSha256
            : sha256.convert(wav).toString(),
      ),
    );
    live.spoken++;
    return CallTurnResult(
      transcript: result.transcript,
      reply: result.tutor.tutorText,
    );
  }

  @override
  Future<void> completeCall(String sessionId, int linesSpoken) async {
    final live = _live.remove(sessionId);
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
