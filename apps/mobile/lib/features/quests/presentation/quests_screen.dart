import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/quests_controller.dart';
import '../domain/quest_models.dart';
import 'upgrade_chest_screen.dart';
import 'quest_art.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key, this.sectionType});

  final QuestSectionType? sectionType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.referencePalette;
    final questState = ref.watch(questsControllerProvider);
    final controller = ref.read(questsControllerProvider.notifier);

    if (!questState.introSeen) {
      const magenta = Color(0xFFA71E6E);
      return Scaffold(
        backgroundColor: magenta,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ReferenceArt(
                          QuestArt.singerIntro,
                          width: 206,
                          height: 220,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Earn 30 quest points this month\nto claim your ${questState.monthlyChallenge.badgeName}!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            height: 1.28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ReferenceButton(
                  label: 'CONTINUE',
                  backgroundColor: Colors.white,
                  edgeColor: const Color(0xFFCE82AF),
                  foregroundColor: magenta,
                  onPressed: controller.dismissIntro,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activeSection = sectionType ?? questState.sectionType;
    final monthly = questState.monthlyChallenge;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? palette.surface
          : Colors.white,
      body: ListView(
        key: const PageStorageKey('quests'),
        padding: EdgeInsets.zero,
        children: [
          // Top banner
          Container(
            color: const Color(0xFF992C6B),
            padding: EdgeInsets.fromLTRB(24, topInset + 10, 24, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthly.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  monthly.daysRemaining,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const ReferenceArt(
                      QuestArt.singerHeader,
                      width: 96,
                      height: 82,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? palette.raisedSurface
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthly.isCompleted
                            ? 'Challenge completed!'
                            : 'Earn ${monthly.targetPoints} Quest Points',
                        style: headingStyle,
                      ),
                      const SizedBox(height: 12),
                      QuestProgress(
                        value: monthly.currentPoints,
                        target: monthly.targetPoints,
                        color: const Color(0xFFBC418A),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeSection == QuestSectionType.friends) ...[
                  _TimedHeader(
                    label: 'FRIENDS QUEST',
                    time: questState.friendsQuest.timeRemaining,
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1030 / 376,
                      child: LayoutBuilder(
                        builder: (context, constraints) => ReferenceArt(
                          questState.friendsQuest.isCompleted
                              ? QuestArt.friendsBannerCompleted
                              : QuestArt.friendsBanner,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(questState.friendsQuest.title, style: headingStyle),
                  const SizedBox(height: 12),
                  QuestProgress(
                    value: questState.friendsQuest.userLessons,
                    secondaryValue: questState.friendsQuest.friendLessons,
                    target: questState.friendsQuest.target,
                    color: const Color(0xFFBC418A),
                    secondaryColor: const Color(0xFF75214A),
                  ),
                  const SizedBox(height: 18),
                  _LessonCountRow(
                    name: 'You',
                    dot: const Color(0xFFBC418A),
                    lessons: questState.friendsQuest.userLessons,
                  ),
                  const SizedBox(height: 12),
                  _LessonCountRow(
                    name: questState.friendsQuest.friendName,
                    dot: const Color(0xFF75214A),
                    lessons: questState.friendsQuest.friendLessons,
                  ),
                  const SizedBox(height: 20),
                  if (questState.friendsQuest.isCompleted)
                    ReferenceButton(
                      label:
                          'HIGH FIVED ${questState.friendsQuest.friendName.toUpperCase()}!',
                      outlined: true,
                      foregroundColor: ReferenceColors.disabled,
                      leading: const ReferenceArt(
                        QuestArt.highFive,
                        width: 24,
                        height: 19,
                      ),
                      onPressed: null,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ReferenceButton(
                            label: 'NUDGE',
                            outlined: true,
                            foregroundColor: const Color(0xFF4B4B4B),
                            leading: const ReferenceArt(
                              QuestArt.nudge,
                              width: 22,
                              height: 22,
                            ),
                            onPressed: controller.nudge,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ReferenceButton(
                            label: 'GIFT',
                            outlined: true,
                            foregroundColor: const Color(0xFF4B4B4B),
                            leading: const ReferenceArt(
                              QuestArt.gift,
                              width: 22,
                              height: 20,
                            ),
                            onPressed: controller.gift,
                          ),
                        ),
                      ],
                    ),
                ] else ...[
                  _TimedHeader(
                    label: 'WEEKEND QUEST',
                    time: questState.weekendQuest.timeRemaining,
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1035 / 430,
                      child: LayoutBuilder(
                        builder: (context, constraints) => ReferenceArt(
                          QuestArt.weekendBanner,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(questState.weekendQuest.title, style: headingStyle),
                  const SizedBox(height: 12),
                  QuestProgress(
                    value: questState.weekendQuest.currentXp,
                    target: questState.weekendQuest.targetXp,
                    color: const Color(0xFFBC418A),
                  ),
                ],

                const SizedBox(height: 32),
                Divider(color: palette.border, thickness: 2),
                const SizedBox(height: 24),

                _TimedHeader(
                  label: 'DAILY QUESTS',
                  time: questState.dailyTimeRemaining,
                ),
                const SizedBox(height: 20),

                for (final quest in questState.dailyQuests)
                  _DailyQuestTile(
                    quest: quest,
                    onClaim: () async {
                      final reward = await controller.claimReward(quest.id);
                      if (!context.mounted) return;
                      if (reward != null) {
                        await showUpgradeChest(context, reward);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not claim this reward. Check your connection and try again.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
          SizedBox(height: bottomInset + 20),
        ],
      ),
    );
  }
}

/// Section label + countdown. Both sides shrink with an ellipsis so large
/// accessibility text never overflows; at 1x they keep their natural width.
class _TimedHeader extends StatelessWidget {
  const _TimedHeader({required this.label, required this.time});

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: sectionStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: context.referencePalette.disabled,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    time,
                    style: sectionStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCountRow extends StatelessWidget {
  const _LessonCountRow({
    required this.name,
    required this.dot,
    required this.lessons,
  });

  final String name;
  final Color dot;
  final int lessons;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 6, backgroundColor: dot),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    name,
                    style: headingStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
            child: Text(
              '$lessons lessons',
              style: TextStyle(
                fontSize: 19,
                color: context.referencePalette.disabled,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyQuestTile extends StatelessWidget {
  const _DailyQuestTile({required this.quest, required this.onClaim});

  final DailyQuest quest;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final canClaim = quest.canClaim;
    final isClaimed = quest.isClaimed;

    Widget chestArt;
    switch (quest.chestType) {
      case QuestChestType.bronze:
        chestArt = const ReferenceArt(
          QuestArt.chestBronze,
          width: 50,
          height: 38,
        );
      case QuestChestType.silver:
        chestArt = const ReferenceArt(
          QuestArt.chestSilver,
          width: 50,
          height: 51,
        );
      case QuestChestType.gold:
        chestArt = const ReferenceArt(
          QuestArt.chestGold,
          width: 50,
          height: 38,
        );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        button: canClaim,
        enabled: canClaim,
        label: canClaim ? 'Claim ${quest.title}' : quest.title,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canClaim ? onClaim : null,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: headingStyle.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 14),
                    QuestProgress(
                      value: quest.current,
                      target: quest.target,
                      color: const Color(0xFFBC418A),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Opacity(opacity: isClaimed ? 0.45 : 1.0, child: chestArt),
            ],
          ),
        ),
      ),
    );
  }
}

class QuestProgress extends StatelessWidget {
  const QuestProgress({
    required this.value,
    required this.target,
    required this.color,
    this.secondaryValue = 0,
    this.secondaryColor,
    this.height = 20,
    super.key,
  });

  final int value, target;
  final Color color;
  final int secondaryValue;
  final Color? secondaryColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = (value + secondaryValue).clamp(0, target);
    final primaryFraction = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final totalFraction = target > 0 ? (total / target).clamp(0.0, 1.0) : 0.0;
    final hasDarkFill = totalFraction >= 0.5;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: Container(
              width: double.infinity,
              height: height,
              color: context.referencePalette.border,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  return Stack(
                    children: [
                      if (secondaryColor != null && secondaryValue > 0)
                        TweenAnimationBuilder<double>(
                          duration: motionDuration(context, 350),
                          tween: Tween(begin: 0, end: totalFraction),
                          builder: (context, v, _) => Container(
                            width: maxWidth * v,
                            height: height,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              borderRadius: BorderRadius.circular(height / 2),
                            ),
                          ),
                        ),
                      TweenAnimationBuilder<double>(
                        duration: motionDuration(context, 350),
                        tween: Tween(begin: 0, end: primaryFraction),
                        builder: (context, v, _) => Container(
                          width: maxWidth * v,
                          height: height,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(height / 2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                '$total / $target',
                style: TextStyle(
                  color: hasDarkFill
                      ? Colors.white
                      : context.referencePalette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
