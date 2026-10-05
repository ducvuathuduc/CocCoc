import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/preview_controller.dart';

class LearningShell extends ConsumerWidget {
  const LearningShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questIntro =
        navigationShell.currentIndex == 2 &&
        !ref.watch(previewControllerProvider.select((s) => s.questIntroSeen));
    const names = ['Home', 'Practice', 'Quests', 'League', 'Profile'];
    const art = [
      LearningArt.home,
      LearningArt.practice,
      LearningArt.quests,
      LearningArt.league,
      LearningArt.profile,
    ];
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: questIntro
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: ReferenceColors.border, width: 2),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Expanded(
                          child: Semantics(
                            selected: navigationShell.currentIndex == i,
                            button: true,
                            label: names[i],
                            child: Tooltip(
                              message: names[i],
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => navigationShell.goBranch(
                                  i,
                                  initialLocation: false,
                                ),
                                child: AnimatedContainer(
                                  duration: motionDuration(context, 140),
                                  height: 52,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: navigationShell.currentIndex == i
                                        ? ReferenceColors.blueFill
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: navigationShell.currentIndex == i
                                          ? ReferenceColors.blueBorder
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: ReferenceArt(
                                    art[i],
                                    width: 32,
                                    height: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
