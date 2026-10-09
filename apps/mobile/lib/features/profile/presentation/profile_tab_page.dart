// Profile tab page: Riverpod MVVM entry over the mock profile tab screen.
//
// View-only: watches [activeProfileProvider] and forwards callbacks.
// Ground truth: docs/design/references/profile/04-08.png.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/profile_controller.dart';
import '../profile_tab_screen.dart';

/// Standalone profile tab page wired to the mock profile controller.
class ProfileTabPage extends ConsumerWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    return ProfileTabScreen(profile: profile);
  }
}
