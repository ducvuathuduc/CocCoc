import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/extended_controller.dart';
import '../../progress/presentation/hub_screens.dart';
import '../application/super_features_controller.dart';
import '../domain/super_features.dart';

/// Manage features (audit row 33): Super perks as switches, in the settings
/// page style (bold 19 titles, grey 16 subtitles, grey section label).
/// Free learners see the list locked with a GET SUPER action.
class SuperFeaturesScreen extends ConsumerWidget {
  const SuperFeaturesScreen({super.key});
  static const route = '/settings/super-features';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(superFeaturesContentProvider);
    final state = ref.watch(superFeaturesControllerProvider);
    final unlocked = ref.watch(extendedControllerProvider).unlimited;
    return PreviewPage(
      title: content.pageTitle,
      children: [
        if (!unlocked) ...[
          const SizedBox(height: 8),
          LearningCard(
            key: const ValueKey('super-features-locked'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      color: ReferenceColors.disabled,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        content.lockedTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ReferenceColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content.lockedBody,
                  style: const TextStyle(
                    fontSize: 16,
                    color: ReferenceColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                ReferenceButton(
                  key: const ValueKey('super-features-get-super'),
                  label: content.lockedAction,
                  backgroundColor: LearningColors.blue,
                  edgeColor: LearningColors.blueDark,
                  onPressed: () => context.push('/super'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 8),
        Text(content.sectionLabel, style: sectionStyle),
        const SizedBox(height: 6),
        for (final feature in state.features)
          _FeatureRow(feature: feature, enabled: unlocked),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(
            state.error!,
            key: const ValueKey('super-features-error'),
            style: const TextStyle(
              color: LearningColors.red,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const Divider(color: ReferenceColors.border, thickness: 2),
        const SizedBox(height: 12),
        Text(
          content.footnote,
          style: const TextStyle(fontSize: 15, color: ReferenceColors.muted),
        ),
      ],
    );
  }
}

class _FeatureRow extends ConsumerWidget {
  const _FeatureRow({required this.feature, required this.enabled});
  final SuperFeature feature;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = enabled && feature.enabled;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? ReferenceColors.ink
                          : ReferenceColors.disabled,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feature.subtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      color: ReferenceColors.disabled,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              key: ValueKey('super-feature-${feature.id}'),
              value: on,
              onChanged: enabled
                  ? (value) => ref
                        .read(superFeaturesControllerProvider.notifier)
                        .toggle(feature.id, value)
                  : null,
              thumbColor: const WidgetStatePropertyAll(Colors.white),
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? LearningColors.blue
                    : ReferenceColors.border,
              ),
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
