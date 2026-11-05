import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/ui/pressable_icon.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/app_shell_providers.dart';
import '../domain/app_shell_models.dart';

class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({
    required this.selectedBranch,
    required this.onSelected,
    super.key,
  });
  final int selectedBranch;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.referencePalette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                for (final tab in ref.watch(appTabsProvider))
                  Expanded(
                    child: Semantics(
                      selected: selectedBranch == tab.branchIndex,
                      button: true,
                      label: tab.label,
                      child: Tooltip(
                        message: tab.label,
                        excludeFromSemantics: true,
                        child: PressableIcon(
                          onTap: () => onSelected(tab.branchIndex),
                          child: Center(
                            child: AnimatedContainer(
                              duration: motionDuration(context, 140),
                              width: 52,
                              height: 52,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: selectedBranch == tab.branchIndex
                                    ? palette.blueFill
                                    : palette.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedBranch == tab.branchIndex
                                      ? dark
                                            ? palette.border
                                            : ReferenceColors.blueBorder
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(child: _art(tab.kind, dark: dark)),
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

  Widget _art(AppTabKind kind, {required bool dark}) {
    final region = dark
        ? switch (kind) {
            AppTabKind.home => const ArtRegion(
              'android-dark-shell-icons',
              Rect.fromLTWH(0, 0, 32, 30),
            ),
            AppTabKind.practice => const ArtRegion(
              'android-dark-shell-icons',
              Rect.fromLTWH(32, 0, 30, 28),
            ),
            AppTabKind.quests => const ArtRegion(
              'android-dark-shell-icons',
              Rect.fromLTWH(64, 0, 29, 30),
            ),
            AppTabKind.league => const ArtRegion(
              'android-dark-shell-icons',
              Rect.fromLTWH(96, 0, 24, 27),
            ),
            AppTabKind.profile => const ArtRegion(
              'android-dark-shell-icons',
              Rect.fromLTWH(128, 0, 32, 29),
            ),
          }
        : switch (kind) {
            AppTabKind.home => LearningArt.home,
            AppTabKind.practice => LearningArt.practice,
            AppTabKind.quests => LearningArt.quests,
            AppTabKind.league => LearningArt.league,
            AppTabKind.profile => LearningArt.profile,
          };
    return SizedBox(
      width: 38,
      height: 38,
      child: FittedBox(
        fit: BoxFit.contain,
        child: ReferenceArt(
          region,
          width: region.source.width,
          height: region.source.height,
        ),
      ),
    );
  }
}
