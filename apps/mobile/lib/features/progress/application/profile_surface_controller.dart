import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preview_controller.dart';
import 'profile_actions_controller.dart';

class ProfileSurfaceState {
  ProfileSurfaceState({
    this.scoreCardDismissed = false,
    Set<String> followers = const <String>{},
  }) : followers = Set.unmodifiable(followers);

  final bool scoreCardDismissed;
  final Set<String> followers;

  ProfileSurfaceState copyWith({
    bool? scoreCardDismissed,
    Set<String>? followers,
  }) => ProfileSurfaceState(
    scoreCardDismissed: scoreCardDismissed ?? this.scoreCardDismissed,
    followers: followers ?? this.followers,
  );
}

final profileSurfaceProvider =
    NotifierProvider<ProfileSurfaceController, ProfileSurfaceState>(
      ProfileSurfaceController.new,
    );

class ProfileSurfaceController extends Notifier<ProfileSurfaceState> {
  @override
  ProfileSurfaceState build() => ProfileSurfaceState();

  void dismissScoreCard() {
    if (state.scoreCardDismissed) return;
    state = state.copyWith(scoreCardDismissed: true);
  }

  void receiveFollowers(Set<String> followers) {
    state = state.copyWith(followers: Set<String>.of(followers));
  }

  bool followBack(String person) {
    if (!state.followers.contains(person) ||
        ref.read(previewControllerProvider).following.contains(person) ||
        ref.read(profileActionsProvider).blocked.contains(person)) {
      return false;
    }
    ref.read(previewControllerProvider.notifier).follow(person);
    return true;
  }
}
