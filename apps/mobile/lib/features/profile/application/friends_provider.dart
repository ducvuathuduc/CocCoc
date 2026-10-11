import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/friends_repository.dart';
import '../domain/friend.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return MockFriendsRepository();
});

final friendsProvider = FutureProvider<List<Friend>>((ref) async {
  final repository = ref.watch(friendsRepositoryProvider);
  return repository.getFriends();
});
