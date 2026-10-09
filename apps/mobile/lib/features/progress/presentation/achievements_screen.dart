import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/application/learning_controller.dart';
import '../application/achievements_controller.dart';
import '../application/profile_achievements_provider.dart';
import '../domain/achievement_models.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({this.profileId, super.key});
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foreign = profileId == null
        ? null
        : ref.watch(profileAchievementsProvider(profileId!));
    if (profileId != null && foreign == null) {
      return const Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _AchievementHeader(title: 'Achievements'),
              Expanded(child: Center(child: Text('Profile unavailable'))),
            ],
          ),
        ),
      );
    }
    final achievements =
        foreign?.awards ??
        ref.watch(achievementsControllerProvider).achievements;
    final learning = profileId == null
        ? ref.watch(learningStateProvider)
        : null;
    final currentXp = foreign?.profile.xp ?? learning!.xp;
    final streak = foreign?.profile.streak ?? learning!.streak;
    final lessons =
        foreign?.profile.completedLessons ?? learning!.completedLessons;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _AchievementHeader(
              title: 'Achievements',
              trailing: profileId == null
                  ? IconButton(
                      tooltip: 'Monthly badges',
                      onPressed: () => GoRouter.maybeOf(context) != null
                          ? context.push('/badges')
                          : Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const MonthlyBadgesScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.calendar_month_outlined),
                    )
                  : null,
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
                          value: '$streak',
                          label: 'Longest Streak',
                          dateLabel: profileId == null ? 'Today' : null,
                        ),
                        _RecordCard(
                          art: AchievementArt.mostXp,
                          value: '$currentXp',
                          label: 'Most XP',
                          dateLabel: profileId == null ? 'Today' : null,
                        ),
                        _RecordCard(
                          art: AchievementArt.perfectLessons,
                          value: '$lessons',
                          label: 'Lessons Completed',
                          dateLabel: profileId == null ? 'Today' : null,
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
                        progress: achievement.progressFor(currentXp),
                        onTap: () => GoRouter.maybeOf(context) != null
                            ? context.push(
                                Uri(
                                  path: '/achievements/${achievement.id}',
                                  queryParameters: profileId == null
                                      ? null
                                      : {'profile': profileId!},
                                ).toString(),
                              )
                            : Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  settings: RouteSettings(
                                    name: '/achievements/${achievement.id}',
                                  ),
                                  builder: (_) => AchievementDetailScreen(
                                    achievementId: achievement.id,
                                    profileId: profileId,
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
  const AchievementDetailScreen({
    required this.achievementId,
    this.profileId,
    super.key,
  });

  final String achievementId;
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foreign = profileId == null
        ? null
        : ref.watch(profileAchievementsProvider(profileId!));
    final state = profileId == null
        ? ref.watch(achievementsControllerProvider)
        : null;
    final controller = profileId == null
        ? ref.read(achievementsControllerProvider.notifier)
        : null;
    final achievement = profileId == null
        ? controller!.find(achievementId)
        : foreign?.find(achievementId);
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
                          'This achievement is unavailable.',
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

    final currentXp = profileId == null
        ? ref.watch(learningStateProvider).xp
        : foreign!.profile.xp;
    final progress = achievement.progressFor(currentXp);
    final earned = achievement.isEarned(currentXp);
    final claimed = state?.claimedIds.contains(achievement.id) ?? false;
    final perfectWeek = achievement.id == 'perfect-week';
    final art = achievement.detailArt ?? achievement.art;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _AchievementHeader(
              title: achievement.title,
              trailing: earned && profileId == null
                  ? IconButton(
                      tooltip: 'Share',
                      onPressed: () => _showSharePreview(
                        context,
                        controller!.sharePreview(
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
                            ? 'Achievement complete!'
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
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          profileId == null && achievement.claimAvailable && earned
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: ReferenceButton(
                label: claimed ? 'CLAIMED' : 'CLAIM REWARD',
                backgroundColor: const Color(0xFF1CB0F6),
                edgeColor: const Color(0xFF1899D6),
                onPressed: claimed
                    ? null
                    : () => controller!.claim(
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
    final years = badges.map((badge) => badge.year).toSet().toList()
      ..sort((left, right) => right.compareTo(left));
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const _AchievementHeader(title: 'Monthly Badges', minHeight: 49),
            Expanded(
              child: ListView(
                key: const PageStorageKey('monthly-badges-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 36),
                children: [
                  for (final year in years) ...[
                    _SectionTitle('$year Badges'),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final yearBadges = badges
                            .where((badge) => badge.year == year)
                            .toList(growable: false);
                        final columnWidth = (constraints.maxWidth - 16) / 3;
                        final responsiveScale =
                            columnWidth /
                            _monthlyBaselineColumnWidth /
                            _monthlySourcePixelRatio;
                        final sourceFrameHeight =
                            91 * columnWidth / _monthlyBaselineColumnWidth;
                        final largestArtHeight = yearBadges.fold<double>(
                          0,
                          (height, badge) => math.max(
                            height,
                            badge.art.source.height * responsiveScale,
                          ),
                        );
                        final largeText =
                            MediaQuery.textScalerOf(context).scale(1) > 1.4;
                        final imageHeight = largeText
                            ? math.max(sourceFrameHeight, largestArtHeight)
                            : sourceFrameHeight;
                        final labelHeight = _monthlyLabelHeight(
                          context,
                          yearBadges,
                          columnWidth,
                        );
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: yearBadges.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 11,
                                mainAxisExtent: imageHeight + 6 + labelHeight,
                              ),
                          clipBehavior: Clip.none,
                          itemBuilder: (context, index) => _MonthlyBadgeTile(
                            badge: yearBadges[index],
                            imageEnvelopeHeight: imageHeight,
                            artScale: responsiveScale,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
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

const _monthlyBaselineColumnWidth = (390 - 40 - 16) / 3;
const _monthlySourcePixelRatio = 1179 / 390;

const _monthlyBadgeLabelStyle = TextStyle(
  fontSize: 18,
  height: 1.15,
  fontWeight: FontWeight.w700,
);

double _monthlyLabelHeight(
  BuildContext context,
  List<MonthlyBadge> badges,
  double width,
) => badges.fold<double>(0, (height, badge) {
  final painter = TextPainter(
    text: TextSpan(
      text: badge.month,
      style: DefaultTextStyle.of(context).style.merge(_monthlyBadgeLabelStyle),
    ),
    textAlign: TextAlign.center,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: width);
  return math.max(height, painter.height);
});

class _AchievementHeader extends StatelessWidget {
  const _AchievementHeader({
    required this.title,
    this.trailing,
    this.minHeight = 64,
  });

  final String title;
  final Widget? trailing;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
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
    required this.dateLabel,
  });

  final ArtRegion art;
  final String value;
  final String label;
  final String? dateLabel;

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
        if (dateLabel case final date?)
          Text(
            date,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ReferenceColors.muted, fontSize: 12),
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
  const _MonthlyBadgeTile({
    required this.badge,
    required this.imageEnvelopeHeight,
    required this.artScale,
  });
  final MonthlyBadge badge;
  final double imageEnvelopeHeight;
  final double artScale;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('monthly-badge-${badge.year}-${badge.month}'),
    label:
        '${badge.month} ${badge.year}, ${badge.earned ? 'earned' : 'locked'}',
    excludeSemantics: true,
    child: Column(
      children: [
        SizedBox(
          height: imageEnvelopeHeight,
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: ReferenceArt(
              badge.art,
              key: ValueKey('monthly-art-${badge.year}-${badge.month}'),
              width: badge.art.source.width * artScale,
              height: badge.art.source.height * artScale,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          badge.month,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _monthlyBadgeLabelStyle.copyWith(
            color: badge.earned ? ReferenceColors.ink : ReferenceColors.muted,
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
              'Share achievement',
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
