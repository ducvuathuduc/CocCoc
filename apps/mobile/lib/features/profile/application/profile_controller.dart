// Profile tab application state (mock only, no I/O).
//
// Holds the selected mock variant for the standalone profile tab page.
// Views stay widget-only; this controller owns the local selection command.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile_mock.dart';

/// Selectable mock variants for the profile tab page.
enum ProfileVariant { newUser, rich }

/// Local selection state; defaults to the new-user fixture.
class ProfileTabController extends Notifier<ProfileVariant> {
  @override
  ProfileVariant build() => ProfileVariant.newUser;

  /// Switches the displayed mock fixture; no I/O, no reward effects.
  void select(ProfileVariant variant) {
    state = variant;
  }
}

final profileTabControllerProvider =
    NotifierProvider<ProfileTabController, ProfileVariant>(
      ProfileTabController.new,
    );

/// Active mock profile for the selected variant (mock only, never networked).
final activeProfileProvider = Provider<ProfileMock>(
  (ref) => switch (ref.watch(profileTabControllerProvider)) {
    ProfileVariant.newUser => profileMockNew,
    ProfileVariant.rich => profileMockRich,
  },
);
