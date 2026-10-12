import 'package:flutter/material.dart';

import '../domain/friend.dart';

abstract class FriendsRepository {
  Future<List<Friend>> getFriends();
}

/// The two friends of the archived reference account (golden fixtures).
const referenceFriends = <Friend>[
  Friend(
    name: 'Alex Smith',
    xp: 18,
    color: Color(0xFFE96D8E),
    isFollowing: true,
    isFollower: false,
  ),
  Friend(
    name: 'JohnSmith',
    xp: 79,
    color: Color(0xFF81DECD),
    isFollowing: true,
    isFollower: true,
    flagColors: [Color(0xFF000000), Color(0xFFDD0000), Color(0xFFFFCE00)],
  ),
];

/// Demo account friends: the reference pair plus a realistic study circle.
const demoFriends = <Friend>[
  ...referenceFriends,
  Friend(
    name: 'Linh Nguyen',
    xp: 1240,
    color: Color(0xFFE96D8E),
    isFollowing: true,
    isFollower: true,
    flagColors: [Color(0xFFDA251D), Color(0xFFFFFF00), Color(0xFFDA251D)],
  ),
  Friend(
    name: 'Minh Tran',
    xp: 980,
    color: Color(0xFF81DECD),
    isFollowing: true,
    isFollower: false,
    flagColors: [Color(0xFFDA251D), Color(0xFFFFFF00), Color(0xFFDA251D)],
  ),
  Friend(
    name: 'Sarah Johnson',
    xp: 1875,
    color: Color(0xFFFFC800),
    isFollowing: true,
    isFollower: true,
  ),
  Friend(
    name: 'Hoa Pham',
    xp: 640,
    color: Color(0xFF1CB0F6),
    isFollowing: false,
    isFollower: true,
    flagColors: [Color(0xFFDA251D), Color(0xFFFFFF00), Color(0xFFDA251D)],
  ),
  Friend(
    name: 'Daniel Kim',
    xp: 2210,
    color: Color(0xFFCE82FF),
    isFollowing: true,
    isFollower: true,
    flagColors: [Colors.white, Color(0xFFCD2E3A), Color(0xFF0047A0)],
  ),
  Friend(
    name: 'Mai Le',
    xp: 455,
    color: Color(0xFF58CC02),
    isFollowing: true,
    isFollower: false,
    flagColors: [Color(0xFFDA251D), Color(0xFFFFFF00), Color(0xFFDA251D)],
  ),
  Friend(
    name: 'Emma Wilson',
    xp: 1530,
    color: Color(0xFFE96D8E),
    isFollowing: true,
    isFollower: true,
    flagColors: [Color(0xFF012169), Colors.white, Color(0xFFC8102E)],
  ),
  Friend(
    name: 'Quang Vo',
    xp: 310,
    color: Color(0xFF81DECD),
    isFollowing: false,
    isFollower: true,
    flagColors: [Color(0xFFDA251D), Color(0xFFFFFF00), Color(0xFFDA251D)],
  ),
  Friend(
    name: 'Yuki Tanaka',
    xp: 1120,
    color: Color(0xFFFFC800),
    isFollowing: true,
    isFollower: true,
    flagColors: [Colors.white, Color(0xFFBC002D), Colors.white],
  ),
  Friend(
    name: 'Bao Hoang',
    xp: 875,
    color: Color(0xFF1CB0F6),
    isFollowing: true,
    isFollower: false,
    flagColors: [Color(0xFFDA251D), Color(0xFFFFFF00), Color(0xFFDA251D)],
  ),
  Friend(
    name: 'Lucas Martin',
    xp: 1390,
    color: Color(0xFFCE82FF),
    isFollowing: true,
    isFollower: true,
    flagColors: [Color(0xFF0055A4), Colors.white, Color(0xFFEF4135)],
  ),
  Friend(
    name: 'Thao Dang',
    xp: 720,
    color: Color(0xFF58CC02),
    isFollowing: false,
    isFollower: true,
    flagColors: [Color(0xFFDA251D), Color(0xFFFFFF00), Color(0xFFDA251D)],
  ),
  Friend(
    name: 'Olivia Brown',
    xp: 2045,
    color: Color(0xFFE96D8E),
    isFollowing: true,
    isFollower: true,
  ),
  Friend(
    name: 'Khanh Bui',
    xp: 590,
    color: Color(0xFF81DECD),
    isFollowing: true,
    isFollower: false,
    flagColors: [Color(0xFFDA251D), Color(0xFFFFFF00), Color(0xFFDA251D)],
  ),
  Friend(
    name: 'Anh Do',
    xp: 1660,
    color: Color(0xFFFFC800),
    isFollowing: true,
    isFollower: true,
    flagColors: [Color(0xFFDA251D), Color(0xFFFFFF00), Color(0xFFDA251D)],
  ),
];

class MockFriendsRepository implements FriendsRepository {
  const MockFriendsRepository({this.friends = demoFriends});

  /// Only the archived reference pair (keeps reference goldens stable).
  const MockFriendsRepository.reference() : friends = referenceFriends;

  final List<Friend> friends;

  @override
  Future<List<Friend>> getFriends() async => friends;
}
