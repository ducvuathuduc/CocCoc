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
  Widget build(BuildContext context, WidgetRef ref) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: ReferenceColors.border, width: 2)),
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
                                  ? ReferenceColors.blueFill
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selectedBranch == tab.branchIndex
                                    ? ReferenceColors.blueBorder
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(child: _art(tab.kind)),
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

  Widget _art(AppTabKind kind) {
    final region = switch (kind) {
      AppTabKind.home => LearningArt.home,
      AppTabKind.practice => LearningArt.practice,
      AppTabKind.quests => LearningArt.quests,
      AppTabKind.league => LearningArt.league,
      AppTabKind.profile => LearningArt.profile,
    };
    final aspect = region.source.width / region.source.height;
    return ReferenceArt(
      region,
      width: aspect >= 1 ? 38 : 38 * aspect,
      height: aspect >= 1 ? 38 / aspect : 38,
    );
  }
}
