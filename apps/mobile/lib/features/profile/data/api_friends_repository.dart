import 'package:flutter/painting.dart';

import '../../../core/api/client/api_endpoints.g.dart';
import '../domain/friend.dart';
import 'friends_repository.dart';

/// [FriendsRepository] backed by `GET /v1/friends` (mutual + followed public
/// profiles). Avatar tint is derived from the user id with the mock palette.
class ApiFriendsRepository implements FriendsRepository {
  const ApiFriendsRepository(this.api);

  final ApiEndpoints api;

  static const _palette = [
    Color(0xFFE96D8E),
    Color(0xFF81DECD),
    Color(0xFFFFC800),
    Color(0xFF1CB0F6),
    Color(0xFFCE82FF),
    Color(0xFF58CC02),
  ];

  @override
  Future<List<Friend>> getFriends() async {
    final friends = <Friend>[];
    String? cursor;
    do {
      final page = await api.listFriends(cursor: cursor, limit: 100);
      for (final profile in page.items) {
        friends.add(
          Friend(
            name: profile.nickname,
            xp: profile.studyXp,
            color: _palette[profile.userId.hashCode.abs() % _palette.length],
            isFollowing: profile.followStatus != 'none',
            isFollower: profile.followStatus == 'friend',
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null && friends.length < 500);
    return friends;
  }
}
