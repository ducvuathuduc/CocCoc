import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/profile_achievements_provider.dart';
import '../application/profile_actions_controller.dart';
import '../domain/achievement_models.dart';
import 'profile_actions.dart';

const _foreignAwardArt = <String, ArtRegion>{
  'legend': ArtRegion(
    'profile-foreign-source',
    Rect.fromLTWH(78, 1688, 280, 236),
  ),
  'perfect-week': ArtRegion(
    'profile-foreign-source',
    Rect.fromLTWH(438, 1672, 306, 252),
  ),
  'flawless-finisher': ArtRegion(
    'profile-foreign-source',
    Rect.fromLTWH(808, 1660, 292, 268),
  ),
};

class ForeignProfileAchievements extends ConsumerWidget {
  const ForeignProfileAchievements({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAchievements = ref.watch(profileAchievementsProvider(userId));
    if (profileAchievements == null) return const SizedBox.shrink();
    final awards = <AchievementDefinition>[
      for (final id in const ['legend', 'perfect-week', 'flawless-finisher'])
        ?profileAchievements.find(id),
    ];
    if (awards.length != 3) return const SizedBox.shrink();
    final blocked = ref.watch(
      profileActionsProvider.select((state) => state.blocked.contains(userId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Achievements', style: headingStyle)),
            TextButton(
              onPressed: () => context.push(
                Uri(
                  path: '/achievements',
                  queryParameters: {'profile': userId},
                ).toString(),
              ),
              child: const Text(
                'VIEW ALL',
                style: TextStyle(
                  color: LearningColors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 4) / 3;
            final artWidth = (cellWidth - 16).clamp(54.0, 88.0);
            return Table(
              border: TableBorder.all(
                color: ReferenceColors.border,
                width: 2,
                borderRadius: BorderRadius.circular(18),
              ),
              children: [
                TableRow(
                  children: [
                    for (final award in awards)
                      _ForeignAwardCell(
                        award: award,
                        art: _foreignAwardArt[award.id]!,
                        artWidth: artWidth,
                        userId: userId,
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SafetyAction(
          label: 'REPORT USER',
          icon: Icons.outlined_flag,
          onPressed: () => showReportUserFlow(context, ref, userId),
        ),
        const SizedBox(height: 8),
        _SafetyAction(
          label: blocked ? 'UNBLOCK USER' : 'BLOCK USER',
          icon: Icons.block,
          onPressed: () => blocked
              ? ref.read(profileActionsProvider.notifier).unblock(userId)
              : showBlockUserFlow(context, ref, userId),
        ),
      ],
    );
  }
}

class _ForeignAwardCell extends StatelessWidget {
  const _ForeignAwardCell({
    required this.award,
    required this.art,
    required this.artWidth,
    required this.userId,
  });

  final AchievementDefinition award;
  final ArtRegion art;
  final double artWidth;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final label = '${award.title}, ${award.progress} of ${award.goal}';
    void openAward() => context.push(
      Uri(
        path: '/achievements/${award.id}',
        queryParameters: {'profile': userId},
      ).toString(),
    );

    return Semantics(
      button: true,
      label: label,
      onTap: openAward,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('foreign-award-${award.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: openAward,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReferenceArt(
                  art,
                  width: artWidth,
                  height: artWidth * art.source.height / art.source.width,
                ),
                const SizedBox(height: 8),
                Text(
                  '${award.progress} / ${award.goal}',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ReferenceColors.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

class _SafetyAction extends StatelessWidget {
  const _SafetyAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: ReferenceColors.muted,
        textStyle: const TextStyle(
          fontFamily: 'DuolingoSans',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        minimumSize: const Size(48, 48),
      ),
    ),
  );
}
