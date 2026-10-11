import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shell/presentation/app_bottom_nav.dart';
import '../application/preview_controller.dart';

class LearningShell extends ConsumerWidget {
  const LearningShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questIntro =
        navigationShell.currentIndex == 2 &&
        !ref.watch(previewControllerProvider.select((s) => s.questIntroSeen));
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: questIntro
          ? null
          : AppBottomNav(
              selectedBranch: navigationShell.currentIndex,
              onSelected: (index) =>
                  navigationShell.goBranch(index, initialLocation: false),
            ),
    );
  }
}
