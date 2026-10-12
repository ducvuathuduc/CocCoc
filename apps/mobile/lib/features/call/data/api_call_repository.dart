import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';
import '../domain/call_models.dart';
import 'call_repository.dart';

/// [CallRepository] that opens a server conversation (`POST /v1/conversations`,
/// kind=VIDEO_CALL) for each call and completes it on hang-up. The scripted
/// dialogue is bundled content; the session id is the server conversation id.
class ApiCallRepository implements CallRepository {
  ApiCallRepository(
    this.api,
    this.course, {
    this.content = const MockCallRepository(),
  });

  final ApiEndpoints api;
  final ActiveCourse course;

  /// Bundled call scripts (content, not user data).
  final CallRepository content;

  @override
  Future<CallSession> loadSession(String partnerId) async {
    final script = await content.loadSession(partnerId);
    final conversation = await api.startConversation(
      wire.ConversationStartRequest(
        kind: 'VIDEO_CALL',
        courseId: await course.id(),
        scenarioId: partnerId,
        voiceSessionId: null,
      ),
    );
    return CallSession(
      id: conversation.conversationId,
      partnerName: script.partnerName,
      learnerInitial: script.learnerInitial,
      xpReward: script.xpReward,
      script: script.script,
      copy: script.copy,
      ringDuration: script.ringDuration,
      partnerLineDuration: script.partnerLineDuration,
      listenDuration: script.listenDuration,
    );
  }

  @override
  Future<void> completeCall(String sessionId, int linesSpoken) async {
    final finished = linesSpoken > 0;
    await api.completeConversation(
      sessionId,
      wire.ConversationCompleteRequest(
        endReason: finished ? 'COMPLETED' : 'USER_EXIT',
      ),
    );
  }
}
