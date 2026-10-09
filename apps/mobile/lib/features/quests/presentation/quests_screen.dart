import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/preview_controller.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learning = ref.watch(learningStateProvider);
    final preview = ref.watch(previewControllerProvider);
    final controller = ref.read(previewControllerProvider.notifier);
    if (!preview.questIntroSeen) {
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
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReferenceArt(
                          LearningArt.singer,
                          width: 206,
                          height: 220,
                        ),
                        SizedBox(height: 28),
                        Text(
                          'Earn 30 quest points this month\nto claim your December Badge!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                  onPressed: controller.dismissQuestIntro,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget dailyQuest(
      String id,
      String title,
      int value,
      int target,
    ) {
      final done = value >= target, claimed = preview.claims.contains(id);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: done && !claimed ? () => controller.claimQuest(id, eligible: done) : null,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: headingStyle.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 14),
                    QuestProgress(
                      value: value,
                      target: target,
                      color: claimed ? LearningColors.yellow : LearningColors.yellow, // Not exactly specified, but typically gold/yellow
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Opacity(
                opacity: claimed ? 0.5 : 1.0,
                child: const ReferenceArt(LearningArt.chest, width: 48, height: 48), // Example size, using the chest art
              ),
            ],
          ),
        ),
      );
    }

    final decPoints = preview.claims.length;
    final decDone = decPoints >= 30;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('quests'),
          children: [
            Container(
              color: const Color(0xFF992C6B),
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'December Quest',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '15 DAYS',
                                    style: TextStyle(
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
                      ReferenceArt(
                        LearningArt.questSinger,
                        width: 96,
                        height: 82,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LearningCard(
                    child: Column(
                      children: [
                        Text(decDone ? 'Challenge completed!' : 'Earn 30 Quest Points', style: headingStyle),
                        const SizedBox(height: 12),
                        QuestProgress(
                          value: decPoints,
                          target: 30,
                          color: const Color(0xFFE843BA),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('FRIENDS QUEST', style: sectionStyle),
                      const Row(
                        children: [
                          Icon(Icons.timer_outlined, color: ReferenceColors.disabled, size: 16),
                          SizedBox(width: 4),
                          Text('2D', style: sectionStyle),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  const ReferenceArt(
                    LearningArt.questFriends,
                    width: double.infinity,
                    height: 107,
                  ),
                  const SizedBox(height: 18),
                  const Text('Complete 25 lessons', style: headingStyle),
                  const SizedBox(height: 12),
                  const QuestProgress(
                    value: 16,
                    target: 25,
                    color: Color(0xFFA71E6E),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 6, backgroundColor: Color(0xFFA71E6E)),
                          SizedBox(width: 12),
                          Text('You', style: headingStyle),
                        ],
                      ),
                      Text('14 lessons', style: TextStyle(fontSize: 19, color: ReferenceColors.disabled, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 6, backgroundColor: Color(0xFF671444)),
                          SizedBox(width: 12),
                          Text('Alex', style: headingStyle),
                        ],
                      ),
                      Text('2 lessons', style: TextStyle(fontSize: 19, color: ReferenceColors.disabled, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ReferenceButton(
                          label: 'NUDGE',
                          outlined: true,
                          foregroundColor: LearningColors.blue,
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ReferenceButton(
                          label: 'GIFT',
                          outlined: true,
                          foregroundColor: LearningColors.blue,
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: ReferenceColors.border, thickness: 2),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DAILY QUESTS', style: sectionStyle),
                      const Row(
                        children: [
                          Icon(Icons.timer_outlined, color: ReferenceColors.disabled, size: 16),
                          SizedBox(width: 4),
                          Text('5H', style: sectionStyle),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  dailyQuest(
                    'daily-2',
                    'Complete your next 2 lessons',
                    learning.completedLessons,
                    2,
                  ),
                  dailyQuest(
                    'daily-score',
                    'Score 90% in 1 lesson',
                    1,
                    1,
                  ),
                  dailyQuest(
                    'daily-xp',
                    'Get 10 in a row in 2 lessons',
                    0,
                    2,
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

class QuestProgress extends StatelessWidget {
  const QuestProgress({
    required this.value,
    required this.target,
    required this.color,
    super.key,
  });
  final int value, target;
  final Color color;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: TweenAnimationBuilder<double>(
          duration: motionDuration(context, 350),
          tween: Tween(begin: 0, end: (value / target).clamp(0, 1)),
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 18,
            color: color,
            backgroundColor: ReferenceColors.border,
          ),
        ),
      ),
      Positioned.fill(
        child: Center(
          child: Text(
            '${value.clamp(0, target)} / $target',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  );
}
