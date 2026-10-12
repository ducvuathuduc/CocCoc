import 'dart:async';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../domain/roleplay_models.dart';
import '../domain/server_scenarios.dart';
import 'roleplay_repository.dart';

/// Server commands an API-backed [RoleplayRepository] implements: one live
/// conversation per run, every learner turn sent to the server, completion
/// once the script is finished.
abstract interface class RoleplayCommands {
  /// Opens a ROLEPLAY conversation for library card [cardId] on its server
  /// scenario. Throws [MaxRequiredException] without the Max plan.
  Future<RoleplayLiveSession> startSession(String cardId);

  /// Sends one learner text turn (`POST /v1/tutor` with the scenario id).
  Future<RoleplayTurn> sendTurn(RoleplayLiveSession session, String text);

  /// Completes the conversation; the server grades stars, words and XP.
  /// Throws [RoleplayIncompleteException] when the script is unfinished.
  Future<RoleplayServerResult> complete(RoleplayLiveSession session);

  /// Ends an unfinished run (`endReason: USER_EXIT`); never throws.
  Future<void> abandon(RoleplayLiveSession session);
}

/// Maps `ENTITLEMENT_REQUIRED` / `SESSION_INCOMPLETE` envelopes onto the
/// domain exceptions the session flow handles; rethrows anything else.
Never rethrowRoleplayError(Object error, StackTrace stack) {
  if (error is ApiException) {
    if (error.code == 'ENTITLEMENT_REQUIRED') {
      final feature = error.details['feature'];
      throw MaxRequiredException(feature is String ? feature : 'ROLEPLAY');
    }
    if (error.code == 'SESSION_INCOMPLETE') {
      int read(String key) {
        final v = error.details[key];
        return v is num ? v.toInt() : 0;
      }

      throw RoleplayIncompleteException(
        read('completedSteps'),
        read('requiredSteps'),
      );
    }
  }
  Error.throwWithStackTrace(error, stack);
}

/// Roleplay library: cards (art, topic, copy) stay the bundled catalog; in API
/// mode each card's dialogue is its server scenario's script
/// ([roleplayServerLinks]), turns go through the server, per-card progress
/// comes from conversation history (`GET /v1/conversations`, kind=ROLEPLAY).
class ApiRoleplayRepository extends MockRoleplayRepository
    implements RoleplayCommands {
  ApiRoleplayRepository(this.api, this.course, {SnapshotHost? host})
    : cache = SnapshotCache<wire.ConversationPage>(
        key: 'conversations.roleplay',
        host: host ?? SnapshotHost.detached(),
        decode: wire.ConversationPage.fromJson,
        encode: (p) => p.toJson(),
      ),
      super(progress: const {});

  final ApiEndpoints api;
  final ActiveCourse course;
  final SnapshotCache<wire.ConversationPage> cache;

  Future<wire.ConversationPage> _fetch() =>
      api.listConversations(kind: 'ROLEPLAY', limit: 100);

  Future<void> refresh() => cache.refresh(_fetch);

  @override
  Map<String, RoleplayProgress> initialProgress() {
    cache.ensureLoaded(_fetch);
    return progressFrom(cache.value?.items ?? const []);
  }

  @override
  List<RoleplayScenario> scenariosFor(String topicId) => [
    for (final s in super.scenariosFor(topicId)) serverPlayed(s),
  ];

  @override
  RoleplayScenario? scenario(String id) {
    final card = super.scenario(id);
    return card == null ? null : serverPlayed(card);
  }

  /// [card] with its dialogue replaced by the linked server script, so the
  /// prompts and step count the session shows are exactly what the server
  /// judges turns against.
  static RoleplayScenario serverPlayed(RoleplayScenario card) {
    final link = roleplayServerLinks[card.id];
    final server = serverScenarioById(serverScenarioIdFor(card.id))!;
    final retitle = link == null || link.retitle;
    return RoleplayScenario(
      id: card.id,
      topicId: card.topicId,
      title: retitle ? server.title : card.title,
      setting: retitle
          ? '${server.title}. ${server.partnerName} is ready to talk with you.'
          : card.setting,
      wellDone: retitle
          ? 'Well done! You finished “${server.title}” in English.'
          : card.wellDone,
      takeaway: card.takeaway,
      pattern: card.pattern,
      example: card.example,
      scene: card.scene,
      lines: [for (final step in server.steps) lineFor(step)],
    );
  }

  static final _hint = RegExp(r'^(.+?):\s*"(.+?)"\s*\.?$');

  /// One server step as a session line: the partner prompt, the Vietnamese
  /// coaching as its translation/tip, and the quoted phrase as a hint chip.
  static RoleplayLine lineFor(ServerScenarioStep step) {
    final m = _hint.firstMatch(step.hintVi);
    return RoleplayLine(
      prompt: step.partner,
      translation: step.hintVi,
      hints: m == null ? const [] : [RoleplayHint(m[1]!, m[2]!)],
      tip: step.hintVi,
    );
  }

  /// Best stars / words and completion count per library card. Server history
  /// keys on server scenario ids; each maps to the card that owns it.
  static Map<String, RoleplayProgress> progressFrom(
    List<wire.Conversation> items,
  ) {
    final out = <String, RoleplayProgress>{};
    for (final c in items) {
      if (c.status != 'COMPLETED') continue;
      final cardId = cardIdForServerScenario(c.scenarioId);
      if (cardId == null) continue;
      final before = out[cardId] ?? const RoleplayProgress();
      out[cardId] = RoleplayProgress(
        stars: c.stars > before.stars ? c.stars : before.stars,
        bestWords: c.wordsUsed > before.bestWords
            ? c.wordsUsed
            : before.bestWords,
        completions: before.completions + 1,
      );
    }
    return out;
  }

  @override
  Future<RoleplayLiveSession> startSession(String cardId) async {
    final serverId = serverScenarioIdFor(cardId);
    try {
      final started = await api.startConversation(
        wire.ConversationStartRequest(
          kind: 'ROLEPLAY',
          courseId: await course.id(),
          scenarioId: serverId,
          voiceSessionId: null,
        ),
      );
      return RoleplayLiveSession(
        conversationId: started.conversationId,
        cardId: cardId,
        serverScenarioId: serverId,
      );
    } catch (error, stack) {
      rethrowRoleplayError(error, stack);
    }
  }

  @override
  Future<RoleplayTurn> sendTurn(
    RoleplayLiveSession session,
    String text,
  ) async {
    final server = serverScenarioById(session.serverScenarioId);
    try {
      final result = await api.tutorFeedback(
        wire.TutorRequest(
          requestId: api.client.ids.next(),
          scenarioId: wire.JsonPresence.value(session.serverScenarioId),
          learnerText: text,
          level: server?.level ?? 'A1',
          locale: 'en-US',
          feedbackLocale: 'vi-VN',
        ),
      );
      return RoleplayTurn(
        reply: result.tutorText,
        // The scripted provider marks an off-topic turn with the model answer
        // as correction and repeats the step; on-topic turns carry none.
        advanced: result.correction == null,
        explanation: result.explanation,
        correction: result.correction,
      );
    } catch (error, stack) {
      rethrowRoleplayError(error, stack);
    }
  }

  @override
  Future<RoleplayServerResult> complete(RoleplayLiveSession session) async {
    try {
      final done = await api.completeConversation(
        session.conversationId,
        const wire.ConversationCompleteRequest(endReason: 'COMPLETED'),
      );
      unawaited(refresh().catchError((Object _) {}));
      return RoleplayServerResult(
        stars: done.stars,
        wordsUsed: done.wordsUsed,
        xp: done.xpAwarded,
      );
    } catch (error, stack) {
      rethrowRoleplayError(error, stack);
    }
  }

  @override
  Future<void> abandon(RoleplayLiveSession session) async {
    try {
      await api.completeConversation(
        session.conversationId,
        const wire.ConversationCompleteRequest(endReason: 'USER_EXIT'),
      );
    } catch (_) {}
  }
}
