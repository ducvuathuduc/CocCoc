import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';

const _welcomeLeagueArt = ArtRegion(
  'league-welcome-source',
  Rect.fromLTWH(145, 500, 890, 850),
);

class LeagueEntrySurface extends StatelessWidget {
  const LeagueEntrySurface({
    required this.remainingLessons,
    required this.onStartLesson,
    required this.onContinue,
    super.key,
  });

  final int remainingLessons;
  final VoidCallback onStartLesson;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final locked = remainingLessons > 0;
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = math.max(0.0, constraints.maxWidth - 32);
            return SingleChildScrollView(
              key: const PageStorageKey('league-entry'),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0.0, constraints.maxHeight - 36),
                ),
                child: IntrinsicHeight(
                  child: locked
                      ? _LockedLeagueEntry(
                          remainingLessons: remainingLessons,
                          artWidth: math.min(290.0, contentWidth),
                          onStartLesson: onStartLesson,
                        )
                      : _WelcomeLeagueEntry(
                          artWidth: math.min(294.0, contentWidth),
                          onContinue: onContinue,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LockedLeagueEntry extends StatelessWidget {
  const _LockedLeagueEntry({
    required this.remainingLessons,
    required this.artWidth,
    required this.onStartLesson,
  });

  final int remainingLessons;
  final double artWidth;
  final VoidCallback onStartLesson;

  @override
  Widget build(BuildContext context) {
    final lessonLabel = remainingLessons == 1 ? 'lesson' : 'lessons';
    return Column(
      children: [
        const Spacer(),
        const SizedBox(height: 24),
        ReferenceArt(
          LearningArt.leagueLocked,
          width: artWidth,
          height: artWidth * 578 / 880,
        ),
        const SizedBox(height: 32),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Finish '),
              TextSpan(
                text: '$remainingLessons $lessonLabel',
                style: const TextStyle(color: LearningColors.orange),
              ),
              const TextSpan(text: ' to start\ncompeting on Leaderboards!'),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ReferenceColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const Spacer(),
        const SizedBox(height: 28),
        ReferenceButton(
          label: 'START A LESSON',
          backgroundColor: LearningColors.blue,
          edgeColor: LearningColors.blueDark,
          onPressed: onStartLesson,
        ),
      ],
    );
  }
}

class _WelcomeLeagueEntry extends StatelessWidget {
  const _WelcomeLeagueEntry({required this.artWidth, required this.onContinue});

  final double artWidth;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Spacer(),
      ReferenceArt(
        _welcomeLeagueArt,
        width: artWidth,
        height: artWidth * 850 / 890,
      ),
      const SizedBox(height: 26),
      const Text(
        'Welcome to Leaderboards!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: ReferenceColors.ink,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Join other learners in a weekly contest.\n'
        'Earn XP from lessons to climb the ranks!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: ReferenceColors.muted,
          fontSize: 20,
          height: 1.35,
        ),
      ),
      const Spacer(),
      const SizedBox(height: 28),
      ReferenceButton(
        label: 'CONTINUE',
        backgroundColor: LearningColors.blue,
        edgeColor: LearningColors.blueDark,
        onPressed: onContinue,
      ),
    ],
  );
}
