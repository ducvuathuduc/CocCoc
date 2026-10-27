import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../../../core/config/app_config.dart';

enum FriendStreakState { active, pendingOutgoing, pendingIncoming }

/// One friend-streak pair as the streak screen needs it.
class FriendStreakLink {
  const FriendStreakLink({
    required this.pairId,
    required this.userId,
    required this.name,
    required this.state,
    required this.length,
  });

  final String pairId, userId, name;
  final FriendStreakState state;
  final int length;
}

enum SocialInteraction { nudge, highFive, kudos, giftBoost, congrats }

/// One public profile projection (`GET /v1/profiles/{userId}`).
class SocialProfile {
  const SocialProfile({
    required this.userId,
    required this.nickname,
    required this.avatarId,
    required this.studyXp,
    required this.streak,
    required this.achievementIds,
    required this.followStatus,
  });

  final String userId, nickname;
  final String? avatarId;
  final int studyXp, streak;
  final List<String> achievementIds;
  final String followStatus;

  bool get isFollowing =>
      followStatus == 'following' || followStatus == 'friend';
}

/// One friend activity entry (`GET /v1/activity`).
class SocialActivity {
  const SocialActivity({
    required this.eventId,
    required this.userId,
    required this.kind,
    required this.summary,
    required this.createdAt,
  });

  final String eventId, userId, kind, summary;
  final DateTime createdAt;
}

/// Friend streaks, friend interactions, profiles, follows, reports and blocks
/// (Progress social).
abstract interface class SocialRepository {
  /// Server friend streaks; `null` keeps the local preview state (mock).
  List<FriendStreakLink>? friendStreaks();

  Future<void> inviteFriendStreak(String userId);
  Future<void> respondFriendStreak(String userId, {required bool accept});
  Future<void> sendInteraction(
    String userId,
    SocialInteraction kind, {
    required String contextId,
  });
  Future<void> block(String userId);
  Future<void> unblock(String userId);

  /// Public profile projection; `null` keeps the local mock summary.
  Future<SocialProfile?> publicProfile(String userId);

  /// Friend activity feed, newest server page order.
  Future<List<SocialActivity>> activity({int limit = 50});

  Future<void> follow(String userId);
  Future<void> unfollow(String userId);

  /// Reports [userId] with the human-readable action-sheet [reason].
  Future<void> report(String userId, {required String reason});

  Future<void> leaveClassroom(String classroomId);
}

/// Mock: no server; controllers keep their local preview state.
class MockSocialRepository implements SocialRepository {
  const MockSocialRepository();

  @override
  List<FriendStreakLink>? friendStreaks() => null;

  @override
  Future<void> inviteFriendStreak(String userId) async {}

  @override
  Future<void> respondFriendStreak(
    String userId, {
    required bool accept,
  }) async {}

  @override
  Future<void> sendInteraction(
    String userId,
    SocialInteraction kind, {
    required String contextId,
  }) async {}

  @override
  Future<void> block(String userId) async {}

  @override
  Future<void> unblock(String userId) async {}

  @override
  Future<SocialProfile?> publicProfile(String userId) async => null;

  @override
  Future<List<SocialActivity>> activity({int limit = 50}) async => const [];

  @override
  Future<void> follow(String userId) async {}

  @override
  Future<void> unfollow(String userId) async {}

  @override
  Future<void> report(String userId, {required String reason}) async {}

  @override
  Future<void> leaveClassroom(String classroomId) async {}
}

/// [SocialRepository] over `/v1/friend-streaks`, `/v1/interactions` and
/// `/v1/blocks`.
class ApiSocialRepository implements SocialRepository {
  ApiSocialRepository(this.api, {SnapshotHost? host})
    : cache = SnapshotCache<wire.FriendStreakPage>(
        key: 'friend-streaks',
        host: host ?? SnapshotHost.detached(),
        decode: wire.FriendStreakPage.fromJson,
        encode: (p) => p.toJson(),
      );

  final ApiEndpoints api;
  final SnapshotCache<wire.FriendStreakPage> cache;

  Future<wire.FriendStreakPage> _fetch() => api.listFriendStreaks(limit: 50);

  Future<void> refresh() => cache.refresh(_fetch);

  @override
  List<FriendStreakLink>? friendStreaks() {
    cache.ensureLoaded(_fetch);
    final items = cache.value?.items ?? const <wire.FriendStreak>[];
    return [
      for (final s in items)
        if (s.status == 'ACTIVE' || s.status == 'PENDING')
          FriendStreakLink(
            pairId: s.pairId,
            userId: s.friendUserId,
            name: s.friendNickname,
            length: s.length,
            state: s.status == 'ACTIVE'
                ? FriendStreakState.active
                : s.inviterId == s.friendUserId
                ? FriendStreakState.pendingIncoming
                : FriendStreakState.pendingOutgoing,
          ),
    ];
  }

  @override
  Future<void> inviteFriendStreak(String userId) async {
    await api.inviteFriendStreak(
      wire.FriendStreakInviteRequest(targetUserId: userId),
    );
    unawaited(refresh());
  }

  @override
  Future<void> respondFriendStreak(
    String userId, {
    required bool accept,
  }) async {
    final pair = cache.value?.items
        .where((s) => s.friendUserId == userId && s.status == 'PENDING')
        .firstOrNull;
    if (pair == null) return;
    await api.respondFriendStreak(
      pair.pairId,
      wire.FriendStreakResponseRequest(accept: accept),
    );
    unawaited(refresh());
  }

  static const _kinds = {
    SocialInteraction.nudge: 'NUDGE',
    SocialInteraction.highFive: 'HIGH_FIVE',
    SocialInteraction.kudos: 'KUDOS',
    SocialInteraction.giftBoost: 'GIFT_BOOST',
    SocialInteraction.congrats: 'CONGRATS',
  };

  @override
  Future<void> sendInteraction(
    String userId,
    SocialInteraction kind, {
    required String contextId,
  }) async {
    await api.sendInteraction(
      wire.InteractionRequest(
        targetUserId: userId,
        kind: _kinds[kind]!,
        contextId: contextId,
        messageKey: '${kind.name.toLowerCase()}.default',
      ),
    );
  }

  @override
  Future<void> block(String userId) async {
    await api.blockUser(wire.BlockRequest(targetUserId: userId));
    unawaited(refresh());
  }

  @override
  Future<void> unblock(String userId) async {
    await api.unblockUser(userId);
  }

  @override
  Future<SocialProfile?> publicProfile(String userId) async {
    final profile = await api.getPublicProfile(userId);
    return SocialProfile(
      userId: profile.userId,
      nickname: profile.nickname,
      avatarId: profile.avatarId,
      studyXp: profile.studyXp,
      streak: profile.streak,
      achievementIds: profile.achievementIds,
      followStatus: profile.followStatus,
    );
  }

  @override
  Future<List<SocialActivity>> activity({int limit = 50}) async {
    final entries = <SocialActivity>[];
    String? cursor;
    do {
      final page = await api.listActivity(cursor: cursor, limit: 50);
      for (final item in page.items) {
        final createdAt = DateTime.tryParse(item.createdAt);
        if (createdAt == null) continue;
        entries.add(
          SocialActivity(
            eventId: item.eventId,
            userId: item.userId,
            kind: item.kind,
            summary: item.summary,
            createdAt: createdAt,
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null && entries.length < limit && entries.length < 500);
    return List.unmodifiable(entries.take(limit));
  }

  @override
  Future<void> follow(String userId) async {
    await api.followUser(wire.FollowRequest(targetUserId: userId));
  }

  @override
  Future<void> unfollow(String userId) async {
    await api.unfollowUser(userId);
  }

  @override
  Future<void> report(String userId, {required String reason}) async {
    await api.reportUser(
      wire.UserReportRequest(
        targetUserId: userId,
        reason: _reportReasons[reason] ?? 'OTHER',
        note: null,
      ),
    );
  }

  @override
  Future<void> leaveClassroom(String classroomId) async {
    await api.leaveClassroom(classroomId);
  }

  /// The action sheet shows human labels; the wire only admits its enum.
  static const _reportReasons = {
    'Spam': 'SPAM',
    'Nudity': 'INAPPROPRIATE_AVATAR',
    'Something else': 'OTHER',
  };
}

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return const MockSocialRepository();
  return ApiSocialRepository(
    ref.watch(apiEndpointsProvider),
    host: SnapshotHost.of(ref, 'social'),
  );
});

/// Fire-and-forget server command; the controller already updated its state.
void sendSocial(Future<void> Function() command) =>
    unawaited(command().catchError((Object _) {}));
