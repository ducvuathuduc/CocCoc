import 'dart:async';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../domain/roleplay_models.dart';
import 'roleplay_repository.dart';

/// Optional server commands an API-backed [RoleplayRepository] implements.
abstract interface class RoleplayCommands {
  /// Records one finished roleplay as a server conversation.
  Future<void> recordConversation(String scenarioId);
}

/// Roleplay library: scenario content stays the bundled catalog; per-scenario
/// progress comes from conversation history (`GET /v1/conversations`,
/// kind=ROLEPLAY) and finished sessions are recorded with
/// `POST /v1/conversations` + `/complete` (server grades stars and XP).
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

  /// Best stars / words and completion count per scenario.
  static Map<String, RoleplayProgress> progressFrom(
    List<wire.Conversation> items,
  ) {
    final out = <String, RoleplayProgress>{};
    for (final c in items) {
      if (c.status != 'COMPLETED') continue;
      final before = out[c.scenarioId] ?? const RoleplayProgress();
      out[c.scenarioId] = RoleplayProgress(
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
  Future<void> recordConversation(String scenarioId) async {
    final started = await api.startConversation(
      wire.ConversationStartRequest(
        kind: 'ROLEPLAY',
        courseId: await course.id(),
        scenarioId: scenarioId,
        voiceSessionId: null,
      ),
    );
    await api.completeConversation(
      started.conversationId,
      const wire.ConversationCompleteRequest(endReason: 'COMPLETED'),
    );
    unawaited(refresh());
  }
}
