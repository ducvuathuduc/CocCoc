import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/learning_controller.dart';
import 'learning_visuals.dart';
import 'lesson_summary.dart';

class LessonResults extends ConsumerWidget {
  const LessonResults({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonControllerProvider);
    final progress = ref.watch(learningStateProvider);
    final receipt = lesson.receipt;
    final controller = ref.read(lessonControllerProvider.notifier);
    if (receipt == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              LearningHeader(
                title: 'Results',
                onClose: () => context.go('/home'),
              ),
              const Expanded(
                child: Center(
                  child: Text('Finish a lesson to see your results.'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final step = lesson.resultStep;
    void next() {
      controller.nextResult();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AnimatedSwitcher(
                          duration: motionDuration(context, 280),
                          child: Column(
                            key: ValueKey(step),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (step == 0) ...[
                                const SizedBox(height: 34),
                                LessonSummary(
                                  receipt: receipt,
                                  mistakeCount:
                                      lesson.attempted - lesson.originalCorrect,
                                ),
                              ] else if (step == 1) ...[
                                const ReferenceArt(
                                  LearningArt.scoreDuo,
                                  width: 163,
                                  height: 257,
                                ),
                                const SizedBox(height: 35),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ReferenceArt(
                                      LearningArt.english,
                                      width: 85,
                                      height: 66,
                                    ),
                                    const SizedBox(width: 18),
                                    Text(
                                      '${progress.score}',
                                      style: const TextStyle(
                                        fontSize: 84,
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                const Text(
                                  'You unlocked your Duolingo\nEnglish Score!',
                                  textAlign: TextAlign.center,
                                  style: headingStyle,
                                ),
                              ] else if (step == 2) ...[
                                if (receipt.gems > 0)
                                  const Text(
                                    '+50 gems',
                                    style: TextStyle(
                                      color: LearningColors.blue,
                                      fontSize: 33,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                const SizedBox(height: 35),
                                const ReferenceArt(
                                  LearningArt.chest,
                                  width: 285,
                                  height: 230,
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  receipt.gems > 0
                                      ? 'You earned 50 gems for unlocking\nyour English Score!'
                                      : 'Another great practice session!',
                                  textAlign: TextAlign.center,
                                  style: headingStyle,
                                ),
                              ] else if (step == 3) ...[
                                const ReferenceArt(
                                  LearningArt.streak,
                                  width: 125,
                                  height: 220,
                                ),
                                Text(
                                  '${progress.streak}',
                                  style: const TextStyle(
                                    fontSize: 112,
                                    color: LearningColors.orange,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                const Text(
                                  'day streak',
                                  style: TextStyle(
                                    fontSize: 30,
                                    color: LearningColors.orange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                _week(progress.streak > 0),
                                const SizedBox(height: 18),
                                const Text(
                                  'Practicing daily grows your streak,\nbut skipping a day resets it!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: ReferenceColors.muted,
                                  ),
                                ),
                              ] else if (step == 4) ...[
                                const Text(
                                  'Daily Quest update!',
                                  style: TextStyle(
                                    color: LearningColors.yellow,
                                    fontSize: 29,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                LearningCard(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: LearningColors.green,
                                        size: 44,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Complete your next\n2 lessons',
                                              style: headingStyle,
                                            ),
                                            const SizedBox(height: 18),
                                            LinearProgressIndicator(
                                              value:
                                                  (progress.completedLessons /
                                                          2)
                                                      .clamp(0, 1),
                                              minHeight: 18,
                                              color: LearningColors.yellow,
                                              backgroundColor:
                                                  ReferenceColors.border,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${progress.completedLessons.clamp(0, 2)} / 2',
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (step == 5) ...[
                                const ReferenceArt(
                                  LearningArt.friendsChest,
                                  width: 270,
                                  height: 209,
                                ),
                                const SizedBox(height: 34),
                                const Text(
                                  'Don’t miss out! Team up on\nFriends Quests to win rewards.',
                                  textAlign: TextAlign.center,
                                  style: headingStyle,
                                ),
                              ] else ...[
                                const ReferenceArt(
                                  LearningArt.superDuo,
                                  width: 165,
                                  height: 171,
                                ),
                                const SizedBox(height: 25),
                                const Text(
                                  'Strengthen your English\nvocabulary with a quick lesson!',
                                  textAlign: TextAlign.center,
                                  style: headingStyle,
                                ),
                                const SizedBox(height: 24),
                                for (final word in const [
                                  ('enchanté', 'nice to meet you'),
                                  ('au revoir', 'goodbye'),
                                  ('à bientôt', 'see you soon'),
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: LearningCard(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.volume_up_rounded,
                                            color: LearningColors.blue,
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  word.$1,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(
                                                  word.$2,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    color: ReferenceColors
                                                        .disabled,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReferenceButton(
                      label: step == 0
                          ? 'CLAIM XP'
                          : step == 3
                          ? 'I’M COMMITTED'
                          : step == 5
                          ? 'ADD FRIENDS'
                          : step >= 6
                          ? 'PRACTICE MY WORDS'
                          : 'CONTINUE',
                      backgroundColor: LearningColors.blue,
                      edgeColor: LearningColors.blueDark,
                      onPressed: () async {
                        if (step == 0) {
                          await controller.claim();
                          if (context.mounted) next();
                        } else if (step == 5) {
                          next();
                          context.push('/friends');
                        } else if (step >= 6) {
                          context.go('/practice/words');
                        } else {
                          next();
                        }
                      },
                    ),
                    if (step == 1)
                      TextButton(
                        onPressed: () => context.push('/score'),
                        child: const Text(
                          'MORE ABOUT SCORE',
                          style: TextStyle(
                            color: LearningColors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (step >= 5)
                      TextButton(
                        onPressed: step == 5 ? next : () => context.go('/home'),
                        child: Text(
                          step == 5 ? 'MAYBE LATER' : 'NOT NOW',
                          style: const TextStyle(
                            color: LearningColors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _week(bool practiced) => LearningCard(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][i],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ReferenceColors.disabled,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0 && practiced
                        ? LearningColors.orange
                        : ReferenceColors.border,
                  ),
                  child: i == 0 && practiced
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
