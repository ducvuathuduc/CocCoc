import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/ui/pressable_icon.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../connectivity/presentation/offline_banner.dart';
import '../application/app_shell_providers.dart';
import '../domain/app_shell_models.dart';

class AppStatsBar extends ConsumerWidget {
  const AppStatsBar({
    required this.onSelected,
    this.offline = false,
    super.key,
  });
  final bool offline;
  final ValueChanged<AppStatKind> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 10,
        children: [
          for (final stat in ref.watch(appStatsProvider))
            Semantics(
              label: stat.semanticLabel,
              button: true,
              child: Tooltip(
                message: stat.label,
                excludeFromSemantics: true,
                child: PressableIcon(
                  radius: 10,
                  onTap: () => onSelected(stat.kind),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    // widthFactor keeps each stat at its own width; a plain
                    // Container(alignment:) fills the Wrap row and stacks
                    // the stats vertically.
                    child: Align(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _art(stat),
                            if (stat.value.isNotEmpty) ...[
                              const SizedBox(width: 7),
                              ExcludeSemantics(
                                child: Text(
                                  stat.value,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: switch (stat.kind) {
                                      AppStatKind.course => ReferenceColors.ink,
                                      AppStatKind.streak =>
                                        stat.active && !offline
                                            ? LearningColors.orange
                                            : ReferenceColors.disabled,
                                      AppStatKind.gems => LearningColors.blue,
                                      // Stays red offline (sc_12b09a6c).
                                      AppStatKind.hearts => LearningColors.red,
                                      AppStatKind.energy =>
                                        stat.unlimited
                                            ? ReferenceColors.purple
                                            // Energy/02 flat battery (1070,380).
                                            : const Color(0xFFFF86CD),
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _art(AppStat stat) {
    final (region, width) = switch (stat.kind) {
      AppStatKind.course => (LearningArt.english, 30.0),
      AppStatKind.streak => (
        stat.active
            ? LearningArt.flame
            : const ArtRegion('energy-01', Rect.fromLTWH(343, 212, 77, 78)),
        24.0,
      ),
      AppStatKind.gems => (LearningArt.gem, 23.0),
      AppStatKind.hearts => (LearningArt.heart, 26.0),
      AppStatKind.energy => (
        const ArtRegion('energy-02', Rect.fromLTWH(977, 350, 160, 110)),
        30.0,
      ),
    };
    final art = ReferenceArt(
      region,
      width: width,
      height: width * region.source.height / region.source.width,
    );
    // srcIn would flood the crop's opaque box; wash the art grey instead.
    return offline && stat.kind == AppStatKind.streak
        ? OfflinePathTint(child: art)
        : art;
  }
}
