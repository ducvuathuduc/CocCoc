import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/quests_controller.dart';
import '../domain/quest_models.dart';
import 'quest_art.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key, this.sectionType});

  final QuestSectionType? sectionType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      backgroundColor: Colors.white,
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
                    color: Colors.white,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('FRIENDS QUEST', style: sectionStyle),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: ReferenceColors.disabled,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            questState.friendsQuest.timeRemaining,
                            style: sectionStyle,
                          ),
                        ],
                      ),
                    ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(0xFFBC418A),
                          ),
                          SizedBox(width: 12),
                          Text('You', style: headingStyle),
                        ],
                      ),
                      Text(
                        '${questState.friendsQuest.userLessons} lessons',
                        style: const TextStyle(
                          fontSize: 19,
                          color: ReferenceColors.disabled,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(0xFF75214A),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            questState.friendsQuest.friendName,
                            style: headingStyle,
                          ),
                        ],
                      ),
                      Text(
                        '${questState.friendsQuest.friendLessons} lessons',
                        style: const TextStyle(
                          fontSize: 19,
                          color: ReferenceColors.disabled,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('WEEKEND QUEST', style: sectionStyle),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: ReferenceColors.disabled,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            questState.weekendQuest.timeRemaining,
                            style: sectionStyle,
                          ),
                        ],
                      ),
                    ],
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
                const Divider(color: ReferenceColors.border, thickness: 2),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DAILY QUESTS', style: sectionStyle),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: ReferenceColors.disabled,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          questState.dailyTimeRemaining,
                          style: sectionStyle,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                for (final quest in questState.dailyQuests)
                  _DailyQuestTile(
                    quest: quest,
                    onClaim: () => controller.claimQuest(quest.id),
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
              color: const Color(0xFFE5E5E5),
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
                  color: hasDarkFill ? Colors.white : const Color(0xFF8E8E93),
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
