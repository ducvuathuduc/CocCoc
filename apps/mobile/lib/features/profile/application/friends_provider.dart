import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/friends_repository.dart';
import '../domain/friend.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../data/api_friends_repository.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  if (ref.watch(appConfigProvider).isApi) {
    return ApiFriendsRepository(ref.watch(apiEndpointsProvider));
  }
  return const MockFriendsRepository();
});

final friendsProvider = FutureProvider<List<Friend>>((ref) async {
  final repository = ref.watch(friendsRepositoryProvider);
  return repository.getFriends();
});
