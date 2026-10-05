import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/application/learning_controller.dart';
import '../application/achievements_controller.dart';
import '../domain/achievement_models.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsControllerProvider).achievements;
    final learning = ref.watch(learningStateProvider);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _AchievementHeader(
              title: 'Achievements',
              trailing: IconButton(
                tooltip: 'Monthly badges',
                onPressed: () => GoRouter.maybeOf(context) != null
                    ? context.push('/badges')
                    : Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MonthlyBadgesScreen(),
                        ),
                      ),
                icon: const Icon(Icons.calendar_month_outlined),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                children: [
                  const _SectionTitle('Personal Records'),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: scale > 1.4 ? 380 : 194,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _RecordCard(
                          art: AchievementArt.longestStreak,
                          value: '${learning.streak}',
                          label: 'Longest Streak',
                        ),
                        _RecordCard(
                          art: AchievementArt.mostXp,
                          value: '${learning.xp}',
                          label: 'Most XP',
                        ),
                        _RecordCard(
                          art: AchievementArt.perfectLessons,
                          value: '${learning.completedLessons}',
                          label: 'Lessons Completed',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle('Awards'),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: achievements.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 18,
                      mainAxisExtent: scale > 1.4 ? 280 : 166,
                    ),
                    itemBuilder: (context, index) {
                      final achievement = achievements[index];
                      return _AwardTile(
                        achievement: achievement,
                        progress: achievement.progressFor(learning.xp),
                        onTap: () => GoRouter.maybeOf(context) != null
                            ? context.push('/achievements/${achievement.id}')
                            : Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: RouteSettings(
                                    name: '/achievements/${achievement.id}',
                                  ),
                                  builder: (_) => AchievementDetailScreen(
                                    achievementId: achievement.id,
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AchievementDetailScreen extends ConsumerWidget {
  const AchievementDetailScreen({required this.achievementId, super.key});

  final String achievementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(achievementsControllerProvider);
    final controller = ref.read(achievementsControllerProvider.notifier);
    final achievement = controller.find(achievementId);
    if (achievement == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const _AchievementHeader(title: 'Achievement'),
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          size: 72,
                          color: ReferenceColors.disabled,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Achievement unavailable',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: ReferenceColors.ink,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'This achievement is not part of the local preview.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: ReferenceColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentXp = ref.watch(learningStateProvider).xp;
    final progress = achievement.progressFor(currentXp);
    final earned = achievement.isEarned(currentXp);
    final claimed = state.claimedIds.contains(achievement.id);
    final perfectWeek = achievement.id == 'perfect-week';
    final art = achievement.detailArt ?? achievement.art;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _AchievementHeader(
              title: achievement.title,
              trailing: earned
                  ? IconButton(
                      tooltip: 'Share',
                      onPressed: () => _showSharePreview(
                        context,
                        controller.sharePreview(
                          achievement.id,
                          currentXp: currentXp,
                        ),
                      ),
                      icon: const Icon(Icons.ios_share_outlined),
                    )
                  : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                children: [
                  SizedBox(height: perfectWeek ? 75 : 64),
                  Center(
                    child: ReferenceArt(
                      art,
                      width: perfectWeek ? 230 : 210,
                      height: perfectWeek ? 255 : 270,
                    ),
                  ),
                  if (achievement.earnedOn != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3D6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          achievement.earnedOn!,
                          style: const TextStyle(
                            color: Color(0xFFC66B00),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (!earned) ...[
                    const SizedBox(height: 24),
                    _AchievementProgress(
                      value: progress,
                      goal: achievement.goal,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    achievement.description ??
                        (earned
                            ? 'This archived preview achievement is complete.'
                            : 'Complete ${achievement.goal} steps to unlock this achievement.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: earned
                          ? ReferenceColors.ink
                          : ReferenceColors.muted,
                      fontSize: perfectWeek ? 24 : 21,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (achievement.earnedOn == 'ARCHIVED FIXTURE') ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Archived fixture completion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ReferenceColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: achievement.claimAvailable && earned
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: ReferenceButton(
                label: claimed ? 'CLAIMED' : 'CLAIM REWARD',
                backgroundColor: const Color(0xFF1CB0F6),
                edgeColor: const Color(0xFF1899D6),
                onPressed: claimed
                    ? null
                    : () => controller.claim(
                        achievement.id,
                        currentXp: currentXp,
                      ),
              ),
            )
          : null,
    );
  }
}

class MonthlyBadgesScreen extends ConsumerWidget {
  const MonthlyBadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(monthlyBadgesProvider);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const _AchievementHeader(title: 'Monthly Badges'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 36),
                children: [
                  for (final year in const [2025, 2024, 2023]) ...[
                    _SectionTitle('$year Badges'),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: badges
                          .where((badge) => badge.year == year)
                          .length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 14,
                        mainAxisExtent: scale > 1.4 ? 240 : 142,
                      ),
                      itemBuilder: (context, index) {
                        final badge = badges
                            .where((candidate) => candidate.year == year)
                            .elementAt(index);
                        return _MonthlyBadgeTile(badge: badge);
                      },
                    ),
                    if (year == 2023) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Only three 2023 badges are visible in the archived source.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ReferenceColors.muted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementHeader extends StatelessWidget {
  const _AchievementHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ReferenceColors.border, width: 2),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              context.canPop() ? context.pop() : context.go('/home');
              return;
            }
            final navigator = Navigator.of(context);
            if (navigator.canPop()) navigator.pop();
          },
          icon: const ReferenceBackIcon(),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ReferenceColors.disabled,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: 48, child: trailing),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: ReferenceColors.ink,
      fontSize: 27,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.art,
    required this.value,
    required this.label,
  });

  final ArtRegion art;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 146,
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
    decoration: BoxDecoration(
      border: Border.all(color: ReferenceColors.border, width: 2),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        ReferenceArt(art, width: 76, height: 60),
        Text(
          value,
          style: const TextStyle(
            color: ReferenceColors.ink,
            fontSize: 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ReferenceColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        const Text(
          'Today',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ReferenceColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _AwardTile extends StatelessWidget {
  const _AwardTile({
    required this.achievement,
    required this.progress,
    required this.onTap,
  });

  final AchievementDefinition achievement;
  final int progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${achievement.title}, $progress of ${achievement.goal}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          ReferenceArt(achievement.art, width: 88, height: 88),
          const SizedBox(height: 4),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ReferenceColors.ink,
              fontSize: 15,
              height: 1.08,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$progress of ${achievement.goal}',
            style: const TextStyle(
              color: ReferenceColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AchievementProgress extends StatelessWidget {
  const _AchievementProgress({required this.value, required this.goal});
  final int value;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final ratio = goal == 0 ? 0.0 : (value / goal).clamp(0, 1).toDouble();
    return Semantics(
      label: 'Achievement progress',
      value: '$value of $goal',
      child: SizedBox(
        height: 30,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: ReferenceColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC800),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              Text(
                '$value/$goal',
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
    );
  }
}

class _MonthlyBadgeTile extends StatelessWidget {
  const _MonthlyBadgeTile({required this.badge});
  final MonthlyBadge badge;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${badge.month} ${badge.year}, ${badge.earned ? 'earned fixture' : 'locked fixture'}',
    child: Column(
      children: [
        ReferenceArt(badge.art, width: 94, height: 94),
        const SizedBox(height: 4),
        Text(
          badge.month,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: badge.earned ? ReferenceColors.ink : ReferenceColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Future<void> _showSharePreview(BuildContext context, String? message) async {
  if (message == null) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share preview',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ReferenceColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ReferenceColors.ink,
                fontSize: 17,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            ReferenceButton(
              label: 'CLOSE',
              outlined: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}
