import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/course_navigation_controller.dart';
import '../application/learning_controller.dart';
import '../domain/course_catalog.dart';
import 'learning_visuals.dart';
import 'unit_guide_screen.dart';
import 'course_unavailable_screen.dart';

export 'course_unavailable_screen.dart';

class SectionsScreen extends ConsumerWidget {
  const SectionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigation = ref.watch(courseNavigationProvider);
    final score = ref.watch(learningStateProvider).score;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ReferenceColors.border, width: 2),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 30),
                  ),
                  const Expanded(
                    child: Text(
                      'English',
                      textAlign: TextAlign.center,
                      style: headingStyle,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const PageStorageKey('english-sections'),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  for (final section in englishSections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _SectionCard(
                        section: section,
                        compact: section.number == 1 && score >= 10,
                        progress: section.number == 1
                            ? (score / 10).clamp(0, 1)
                            : 0,
                        unlocked: navigation.sectionUnlocked(section.number),
                        onContinue: () {
                          ref
                              .read(courseNavigationProvider.notifier)
                              .select(CourseTarget(section.number, 1));
                          context.go('/home');
                        },
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: ReferenceColors.border,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.lock_rounded,
                            color: ReferenceColors.disabled,
                            semanticLabel: 'Daily Refresh locked',
                          ),
                        ),
                        const Center(
                          child: ReferenceArt(
                            ArtRegion(
                              'section-more-source',
                              Rect.fromLTWH(338, 1640, 500, 423),
                            ),
                            width: 166,
                            height: 140.436,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Daily Refresh',
                          style: headingStyle.copyWith(
                            fontSize: 26,
                            color: ReferenceColors.disabled,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Complete the course to unlock this section!',
                          style: TextStyle(
                            fontSize: 18,
                            color: ReferenceColors.disabled,
                          ),
                        ),
                      ],
                    ),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.compact,
    required this.progress,
    required this.unlocked,
    required this.onContinue,
  });
  final CourseSection section;
  final bool compact;
  final double progress;
  final bool unlocked;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ReferenceColors.surface,
        border: Border.all(color: ReferenceColors.border, width: 2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: ReferenceColors.border, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact)
            Container(
              color: ReferenceColors.blueFill,
              child: large
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionBubble(
                            child: Text(
                              section.phrase,
                              style: const TextStyle(fontSize: 21, height: 1.2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _SectionDuo(section: section.number),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: large
                          ? 320
                          : section.number == 8
                          ? 244
                          : 173,
                      child: Stack(
                        children: [
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: _SectionDuo(section: section.number),
                          ),
                          Positioned(
                            left: 20,
                            top: 20,
                            right: large ? 20 : 70,
                            child: _SectionBubble(
                              minHeight: section.number == 8 ? 166 : 0,
                              child: Text(
                                section.phrase,
                                style: const TextStyle(
                                  fontSize: 21,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => context.push('/sections/${section.number}'),
                  child: Tooltip(
                    message: 'Section ${section.number} details',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          Text(
                            'Section ${section.number}',
                            style: headingStyle.copyWith(fontSize: 27),
                          ),
                          _ScoreBadge(range: section.range),
                        ],
                      ),
                    ),
                  ),
                ),
                if (unlocked) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Section ${section.number} progress',
                    value: '${(progress * 100).round()}%',
                    child: LinearProgressIndicator(
                      value: progress,
                      color: LearningColors.green,
                      backgroundColor: ReferenceColors.border,
                      minHeight: 18,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  if (!compact)
                    TextButton(
                      onPressed: onContinue,
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CONTINUE',
                          style: TextStyle(
                            color: LearningColors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                ] else
                  TextButton(
                    key: ValueKey('jump-section-${section.number}'),
                    onPressed: () =>
                        context.push('/sections/${section.number}/check'),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'JUMP HERE',
                        style: TextStyle(
                          color: LearningColors.blue,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
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

class _SectionBubble extends StatelessWidget {
  const _SectionBubble({required this.child, this.minHeight = 0});
  final Widget child;
  final double minHeight;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minHeight),
    child: CustomPaint(
      painter: const _SectionBubblePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
        child: child,
      ),
    ),
  );
}

class _SectionBubblePainter extends CustomPainter {
  const _SectionBubblePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ReferenceColors.surface;
    final bottom = size.height - 10;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, bottom),
        const Radius.circular(16),
      ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 48, bottom - 1)
        ..lineTo(size.width - 30, size.height)
        ..lineTo(size.width - 30, bottom - 1)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SectionBubblePainter oldDelegate) => false;
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.range});
  final String range;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ReferenceArt(LearningArt.english, width: 22, height: 17),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            range,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: ReferenceColors.muted,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionDuo extends StatelessWidget {
  const _SectionDuo({required this.section});
  final int section;
  @override
  Widget build(BuildContext context) => ReferenceArt(
    section == 8
        ? const ArtRegion(
            'section-more-source',
            Rect.fromLTWH(790, 770, 341, 450),
          )
        : section >= 3
        ? const ArtRegion(
            'section-list-source',
            Rect.fromLTWH(790, 1790, 341, 340),
          )
        : const ArtRegion(
            'section-list-source',
            Rect.fromLTWH(809, 921, 322, 331),
          ),
    width: 113,
    height: section == 8
        ? 149.12
        : section >= 3
        ? 112.67
        : 116.16,
  );
}

class SectionDetailScreen extends ConsumerWidget {
  const SectionDetailScreen({required this.section, super.key});
  final int section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (section < 1 || section > englishSections.length) {
      return const CourseUnavailableScreen();
    }
    final data = englishSections[section - 1];
    final unlocked = ref
        .watch(courseNavigationProvider)
        .sectionUnlocked(section);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            Container(
              color: LearningColors.blue,
              child: Stack(
                children: [
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: ReferenceArt(
                      ArtRegion(
                        'section-detail-source',
                        Rect.fromLTWH(861, 320, 318, 325),
                      ),
                      width: 105,
                      height: 107.31,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/sections'),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Section $section',
                          style: headingStyle.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            const ReferenceArt(
                              LearningArt.english,
                              width: 22,
                              height: 17,
                            ),
                            Text(
                              '${data.range} • CEFR ${data.cefr}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${data.description}\n\nHere’s how someone at this level might communicate:',
                style: const TextStyle(fontSize: 21, height: 1.4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: GuidePhraseBubble(
                phrase: data.example,
                showTranslation: false,
              ),
            ),
            ExpansionTile(
              title: const Text('All CEFR levels', style: headingStyle),
              children: [
                for (final example in _cefrExamples)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(
                            example.$1,
                            style: headingStyle.copyWith(fontSize: 20),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            example.$2,
                            style: TextStyle(
                              fontSize: 20,
                              color: example.$1 == data.cefr
                                  ? ReferenceColors.ink
                                  : ReferenceColors.disabled,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(thickness: 2),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ReferenceArt(
                    ArtRegion(
                      'section-detail-source',
                      Rect.fromLTWH(50, 1697, 91, 108),
                    ),
                    width: 28,
                    height: 33.23,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Grammar concepts',
                      style: headingStyle.copyWith(fontSize: 24),
                    ),
                  ),
                ],
              ),
            ),
            for (final topic in data.grammar) ...[
              ExpansionTile(
                title: Text(
                  topic.title,
                  style: headingStyle.copyWith(fontSize: 21),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      topic.explanation,
                      style: const TextStyle(fontSize: 19, height: 1.35),
                    ),
                  ),
                ],
              ),
              const Divider(thickness: 2),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: ReferenceButton(
                label: unlocked ? 'CONTINUE' : 'JUMP HERE',
                onPressed: () {
                  if (unlocked) {
                    ref
                        .read(courseNavigationProvider.notifier)
                        .select(CourseTarget(section, 1));
                    context.go('/home');
                  } else {
                    context.push('/sections/$section/check');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _cefrExamples = [
  ('A1', 'I am from Vietnam. I speak Vietnamese.'),
  (
    'A2',
    'I was born in Vietnam, but I live in Osaka now. I moved here five years ago.',
  ),
  (
    'B1',
    'Cairo is beside the Nile, a famous river. What do you know about its history?',
  ),
  (
    'B2',
    'If the proposal had been reviewed earlier, the team could have avoided the delay.',
  ),
];
