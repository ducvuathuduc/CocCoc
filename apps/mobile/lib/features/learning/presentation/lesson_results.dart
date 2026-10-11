import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../../core/design/reward_motion.dart';
import '../application/completion_providers.dart';
import '../application/learning_controller.dart';
import '../domain/completion_summary.dart';
import 'completion_colors.dart';
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
    final completion = ref.watch(
      completionSummaryProvider((
        receipt,
        lesson.attempted - lesson.originalCorrect,
      )),
    );
    void next() {
      controller.nextResult();
    }

    final streak = ref.watch(completionStreakProvider(progress.streak));
    final scale = (MediaQuery.sizeOf(context).width / 390).clamp(.8, 430 / 390);
    final sourceScale = scale * 390 / 1179;
    final topInset = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: step == 3 ? Colors.white : null,
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
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                alignment: step == 3
                                    ? Alignment.topCenter
                                    : Alignment.center,
                                children: [...previousChildren, ?currentChild],
                              ),
                          child: Column(
                            key: ValueKey(step),
                            mainAxisAlignment: step == 3
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              if (step == 0) ...[
                                SizedBox(height: 52.5 * scale),
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
                                SizedBox(
                                  height: (359 * sourceScale - topInset).clamp(
                                    0,
                                    double.infinity,
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(2 * sourceScale, 0),
                                  child: ReferenceArt(
                                    LearningArt.streak,
                                    width: 329 * sourceScale,
                                    height: 586 * sourceScale,
                                  ),
                                ),
                                Semantics(
                                  label: streak.semanticLabel,
                                  excludeSemantics: true,
                                  child: ShaderMask(
                                    blendMode: BlendMode.srcIn,
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            CompletionColors.streakHighlight,
                                            LearningColors.orange,
                                          ],
                                        ).createShader(bounds),
                                    child: RewardCount(
                                      value: streak.days,
                                      style: TextStyle(
                                        fontSize: 132 * scale,
                                        color: LearningColors.orange,
                                        fontWeight: FontWeight.w700,
                                        height: 1.03,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  streak.title,
                                  style: TextStyle(
                                    fontSize: 32 * scale,
                                    height: 1.1,
                                    color: LearningColors.orange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 32 * scale),
                                _week(streak, scale),
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
                padding: EdgeInsets.fromLTRB(
                  step == 0 || step == 3 ? 16 * scale : 16,
                  15,
                  step == 0 || step == 3 ? 16 * scale : 16,
                  step == 0 || step == 3 ? 21 : 17,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReferenceButton(
                      minHeight: step == 0 || step == 3
                          ? (44 * scale).clamp(48, double.infinity)
                          : null,
                      textStyle: step == 0 || step == 3
                          ? TextStyle(fontSize: 16 * scale)
                          : null,
                      contentPadding: step == 0 || step == 3
                          ? const EdgeInsets.fromLTRB(12, 14, 12, 10)
                          : null,
                      label: step == 0
                          ? completion.claimLabel
                          : step == 3
                          ? streak.commitLabel
                          : step == 5
                          ? 'ADD FRIENDS'
                          : step >= 6
                          ? 'PRACTICE MY WORDS'
                          : 'CONTINUE',
                      backgroundColor: step == 0
                          ? CompletionColors.blue
                          : LearningColors.blue,
                      edgeColor: step == 0
                          ? CompletionColors.blueEdge
                          : LearningColors.blueDark,
                      onPressed: () async {
                        if (step == 0) {
                          final before = ref.read(learningStateProvider).streak;
                          await controller.claim();
                          if (!context.mounted) return;
                          final router = GoRouter.maybeOf(context);
                          if (router == null) {
                            next();
                            return;
                          }
                          // Duolingo order: streak → gems/quests → league,
                          // then the guest create-profile prompt.
                          final grew =
                              ref.read(learningStateProvider).streak > before;
                          router.go(
                            '/results/${receipt.id}/rewards'
                            '${grew ? '?streak=1' : ''}',
                          );
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

  Widget _week(CompletionStreak streak, double scale) => Container(
    margin: EdgeInsets.symmetric(horizontal: 16 * (scale - 1).clamp(0, 1)),
    decoration: BoxDecoration(
      border: Border.all(color: ReferenceColors.border, width: 2),
      borderRadius: BorderRadius.circular(16 * scale),
    ),
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24 * scale,
            vertical: 16 * scale,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in streak.week)
                Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          day.label,
                          style: TextStyle(
                            fontSize: 14 * scale,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: day.current
                                ? LearningColors.orange
                                : ReferenceColors.disabled,
                          ),
                        ),
                      ),
                      SizedBox(height: 10 * scale),
                      Container(
                        width: 28 * scale,
                        height: 28 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: day.practiced
                              ? LearningColors.orange
                              : ReferenceColors.border,
                        ),
                        child: day.practiced
                            ? Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22 * scale,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: ReferenceColors.border),
        Padding(
          padding: EdgeInsets.fromLTRB(
            12 * scale,
            16 * scale,
            12 * scale,
            11.8 * scale,
          ),
          child: Text(
            streak.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20 * scale,
              height: 1.18,
              color: CompletionColors.streakDescription,
            ),
          ),
        ),
      ],
    ),
  );
}
