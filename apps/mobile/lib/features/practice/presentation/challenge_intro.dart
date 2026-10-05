import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/duo_motion.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/journey_controller.dart';
import '../data/journey_repository.dart';

const rapidCampfire = ArtRegion(
  'rapid-intro',
  Rect.fromLTWH(350, 750, 470, 690),
);
const legendaryGold = ArtRegion(
  'legendary-intro',
  Rect.fromLTWH(80, 550, 1010, 866),
);

class ChallengeIntroScreen extends ConsumerWidget {
  const ChallengeIntroScreen({required this.kind, super.key});
  final String kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = kind == 'legendary';
    return Scaffold(
      backgroundColor: gold ? Colors.black : null,
      body: SafeArea(
        child: Column(
          children: [
            if (!gold)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/practice'),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 30,
                        color: ReferenceColors.disabled,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        titleFor(kind),
                        textAlign: TextAlign.center,
                        style: headingStyle.copyWith(
                          fontSize: 21,
                          color: ReferenceColors.disabled,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, gold ? 40 : 60, 16, 24),
                child: Column(
                  children: [
                    if (gold)
                      const SizedBox(height: 65)
                    else
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: LearningColors.yellow,
                            size: 40,
                          ),
                          Icon(
                            Icons.star_rounded,
                            color: Color(0xFFE5E5E5),
                            size: 40,
                          ),
                          Icon(
                            Icons.star_rounded,
                            color: Color(0xFFE5E5E5),
                            size: 40,
                          ),
                        ],
                      ),
                    if (gold)
                      const ReferenceArt(legendaryGold, width: 335, height: 287)
                    else
                      const DuoMotion(
                        pose: DuoPose.reading,
                        width: 185,
                        height: 250,
                        viewport: Rect.fromLTWH(150, 65, 740, 990),
                        spec: DuoMotionSpec(
                          asset: 'assets/motion/bea-smores.json',
                          startFrame: 0,
                          endFrame: 440,
                          loop: true,
                        ),
                        fallback: ReferenceArt(
                          rapidCampfire,
                          width: 185,
                          height: 250,
                        ),
                      ),
                    const SizedBox(height: 25),
                    Text(
                      gold
                          ? 'Review this level by completing a Legendary challenge!'
                          : 'Get every exercise correct in time to collect the second star!',
                      textAlign: TextAlign.center,
                      style: headingStyle.copyWith(
                        fontSize: gold ? 25 : 21,
                        color: gold ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (!gold)
                      LearningCard(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            const Expanded(
                              child: _LevelStat('LEVEL', '2 of 3'),
                            ),
                            Container(
                              height: 43,
                              width: 2,
                              color: ReferenceColors.border,
                            ),
                            const Expanded(
                              child: _LevelStat('EARN UP TO', '20 XP'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: ReferenceButton(
                label: gold ? 'START +40 XP' : 'PLAY',
                backgroundColor: gold
                    ? LearningColors.yellow
                    : LearningColors.blue,
                edgeColor: gold
                    ? LearningColors.orange
                    : LearningColors.blueDark,
                foregroundColor: gold ? const Color(0xFF945000) : null,
                onPressed: () {
                  ref.read(journeyControllerProvider(kind).notifier).start();
                  context.push('/journeys/$kind/session');
                },
              ),
            ),
            if (gold)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/practice'),
                  child: const Text(
                    'MAYBE LATER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LevelStat extends StatelessWidget {
  const _LevelStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ReferenceColors.disabled,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: LearningColors.blue,
        ),
      ),
    ],
  );
}
