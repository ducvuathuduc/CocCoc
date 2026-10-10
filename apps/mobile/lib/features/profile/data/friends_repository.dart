import '../domain/friend.dart';

abstract class FriendsRepository {
  Future<List<Friend>> getFriends();
}

class MockFriendsRepository implements FriendsRepository {
  @override
  Future<List<Friend>> getFriends() async {
    return const [
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
  }
}
