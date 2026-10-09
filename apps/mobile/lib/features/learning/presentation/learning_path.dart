import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/duo_motion.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/learning_controller.dart';
import '../application/course_navigation_controller.dart';
import '../domain/course_catalog.dart';
import '../domain/course_review.dart';
import '../domain/learning_models.dart';
import '../../progress/application/extended_controller.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/domain/score_information.dart';
import 'learning_visuals.dart';

export 'unit_guide_screen.dart' show UnitGuideScreen;

class LearningPath extends ConsumerStatefulWidget {
  const LearningPath({super.key});
  @override
  ConsumerState<LearningPath> createState() => _LearningPathState();
}

class _LearningPathState extends ConsumerState<LearningPath> {
  int? _selected;
  bool _courses = false;
  CourseTarget get _active => ref.read(courseNavigationProvider).active;
  bool get _review => _active != const CourseTarget(1, 1);
  bool _pausedFor(int node, LessonState draft) =>
      draft.stage == LessonStage.paused &&
      draft.nodeId == courseNodeId(_active, node);
  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(learningStateProvider);
    final draft = ref.watch(lessonControllerProvider);
    final energy = ref.watch(extendedControllerProvider);
    final active = ref.watch(courseNavigationProvider).active;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 10,
              children: [
                _status(
                  'Courses',
                  ReferenceArt(LearningArt.english, width: 30, height: 24),
                  progress.score == 0 ? '' : '${progress.score}',
                  ReferenceColors.ink,
                  () => setState(() => _courses = !_courses),
                ),
                _status(
                  'Streak',
                  const ReferenceArt(LearningArt.flame, width: 24, height: 28),
                  '${progress.streak}',
                  LearningColors.orange,
                  () => context.push('/streak'),
                ),
                _status(
                  'Shop',
                  const ReferenceArt(LearningArt.gem, width: 23, height: 26),
                  '${ref.watch(previewWalletProvider)}',
                  LearningColors.blue,
                  () => context.push('/shop'),
                ),
                _status(
                  'Energy',
                  const ReferenceArt(
                    ArtRegion('energy-02', Rect.fromLTWH(977, 350, 160, 110)),
                    width: 30,
                    height: 23,
                  ),
                  energy.unlimited ? '∞' : '${energy.energy}',
                  energy.unlimited
                      ? const Color(0xFFBD4CF5)
                      : const Color(0xFFFF80CE),
                  () => context.push('/energy'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selected = null),
                child: ListView(
                  key: const PageStorageKey('learning-path'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    _unitBanner(context, active.unit, unitGuide(active).title),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return SizedBox(
                          height: 750,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: width * .62,
                                top: 210,
                                child: DuoMotion(
                                  pose: DuoPose.reading,
                                  spec: const DuoMotionSpec(
                                    asset: 'assets/motion/duo-path-jump.json',
                                    startFrame: 0,
                                    endFrame: 220,
                                    loop: true,
                                  ),
                                  width: 118,
                                  height: 126,
                                  viewport: const Rect.fromLTWH(
                                    228,
                                    173,
                                    625,
                                    667,
                                  ),
                                  fallback: const ReferenceArt(
                                    LearningArt.pathDuo,
                                    width: 102,
                                    height: 105,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: width * .7,
                                top: 347,
                                child: Row(
                                  children: List.generate(
                                    3,
                                    (i) => Icon(
                                      Icons.star_rounded,
                                      size: 23,
                                      color:
                                          i == 0 &&
                                              progress.completedLessons > 0
                                          ? LearningColors.yellow
                                          : ReferenceColors.border,
                                    ),
                                  ),
                                ),
                              ),
                              for (var i = 0; i < 8; i++)
                                _node(context, progress, draft, i, width),
                              if (_selected != null)
                                Positioned(
                                  top: _selected! * 86 + 138,
                                  left: 8,
                                  right: 8,
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey(_selected),
                                    tween: Tween(begin: .9, end: 1),
                                    duration: motionDuration(context),
                                    curve: Curves.easeOutBack,
                                    builder: (context, scale, child) =>
                                        Transform.scale(
                                          scale: scale,
                                          alignment: Alignment.topCenter,
                                          child: child,
                                        ),
                                    child: _popup(
                                      context,
                                      progress,
                                      draft,
                                      _selected!,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (active.unit < 8) ...[
                      _unitBanner(
                        context,
                        active.unit + 1,
                        unitGuide(CourseTarget(active.section, active.unit + 1))
                            .title,
                      ),
                      const SizedBox(height: 25),
                      Center(
                        child: Column(
                          children: [
                            const SpeechBubble(
                              below: true,
                              child: Text(
                                'JUMP HERE?',
                                style: TextStyle(
                                  color: Color(0xFFBA4095),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            PathNode(
                              current: false,
                              completed: false,
                              icon: Icons.fast_forward_rounded,
                              color: const Color(0xFFBA4095),
                              edgeColor: const Color(0xFF962877),
                              tooltip: 'Jump to Unit ${active.unit + 1}',
                              onTap: () => context.push(
                                '/units/unit-${active.unit + 1}/skip?section=${active.section}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_courses)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _courses = false),
                    child: Container(color: Colors.black45),
                  ),
                ),
              if (_courses)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _coursePanel(context, progress),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _status(
    String label,
    Widget art,
    String value,
    Color color,
    VoidCallback action,
  ) => Semantics(
    label: label,
    button: true,
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              art,
              const SizedBox(width: 7),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _unitBanner(BuildContext context, int unit, String title) => Container(
    decoration: BoxDecoration(
      color: unit == 2 ? const Color(0xFFBA4095) : LearningColors.green,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: unit == 2 ? const Color(0xFF962877) : LearningColors.greenDark,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SECTION ${ref.watch(courseNavigationProvider).active.section}, UNIT $unit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: unit == 2
                        ? const Color(0xFFFFC9E9)
                        : const Color(0xFFD7FFB8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: unit == 2
                    ? const Color(0xFF962877)
                    : LearningColors.greenDark,
                width: 2,
              ),
            ),
          ),
          child: IconButton(
            tooltip: 'Unit $unit guidebook',
            onPressed: () => context.push(
              '/units/unit-$unit/guide?section=${ref.read(courseNavigationProvider).active.section}',
            ),
            icon: unit == 2
                ? const CustomPaint(
                    size: Size(30, 29),
                    painter: _GuideIconPainter(Color(0xFFBA4095)),
                  )
                : const ReferenceArt(LearningArt.guide, width: 30, height: 29),
            padding: const EdgeInsets.all(20),
          ),
        ),
      ],
    ),
  );

  Widget _node(
    BuildContext context,
    LearningState progress,
    LessonState draft,
    int i,
    double width,
  ) {
    const offsets = [.5, .36, .29, .36, .5, .65, .5, .36];
    final current = i == (_review ? 0 : progress.currentNode);
    final completed = !_review && progress.completedNodes.contains('node-$i');
    final centerX = width * offsets[i];
    return Positioned(
      left: centerX - 50,
      top: i * 86.0 + (current ? 0 : 46),
      width: 100,
      child: Column(
        children: [
          if (current)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              decoration: BoxDecoration(
                color: ReferenceColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ReferenceColors.border, width: 2),
              ),
              child: Text(
                _pausedFor(i, draft)
                    ? 'RESUME'
                    : !_review && progress.completedLessons > 0
                    ? 'CONTINUE'
                    : 'START',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _active.unit == 2
                      ? const Color(0xFF962877)
                      : LearningColors.greenDark,
                ),
              ),
            ),
          PathNode(
            current: current,
            completed: completed,
            color: current && _active.unit == 2
                ? const Color(0xFFBA4095)
                : null,
            edgeColor: current && _active.unit == 2
                ? const Color(0xFF962877)
                : null,
            progress: _review ? .2 : (progress.lessonInNode + 1) / 5,
            icon: i == 2
                ? Icons.headphones_rounded
                : i == 3
                ? Icons.mic_rounded
                : i == 5
                ? Icons.inventory_2_rounded
                : Icons.star_rounded,
            tooltip: current
                ? 'Start lesson ${_review ? 1 : progress.lessonInNode + 1}'
                : completed
                ? 'Replay lesson $i'
                : 'Locked lesson $i',
            onTap: () {
              if (!current && !completed) {
                showLearningNotice(
                  context,
                  'Not quite yet!',
                  'Finish the previous lessons to unlock this one.',
                );
                return;
              }
              setState(() => _selected = _selected == i ? null : i);
            },
          ),
        ],
      ),
    );
  }

  Widget _popup(
    BuildContext context,
    LearningState progress,
    LessonState draft,
    int i,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: LearningColors.green,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          unitGuide(ref.watch(courseNavigationProvider).active).title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _review
              ? 'Practice key phrases'
              : 'Lesson ${progress.lessonInNode + 1} of 5',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        const SizedBox(height: 16),
        ReferenceButton(
          label: _pausedFor(i, draft)
              ? 'RESUME LESSON'
              : _review
              ? 'START'
              : 'START +20 XP',
          backgroundColor: Colors.white,
          edgeColor: const Color(0xFFD7FFB8),
          foregroundColor: LearningColors.green,
          onPressed: () {
            ref.read(courseNavigationProvider.notifier).startLesson(i);
            setState(() => _selected = null);
            context.push('/lesson/${courseNodeId(_active, i)}');
          },
        ),
      ],
    ),
  );

  Widget _coursePanel(BuildContext context, LearningState progress) {
    final band = scoreBandIndex(progress.score);
    final start = scoreBandStarts[band];
    final next = scoreBandNext[band];
    final value = ((progress.score - start) / (next - start))
        .clamp(0, 1)
        .toDouble();
    return Material(
      color: ReferenceColors.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: LearningColors.blue,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const ReferenceArt(
                          LearningArt.english,
                          width: 52,
                          height: 40,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text('English', style: headingStyle),
                    ],
                  ),
                  const SizedBox(width: 30),
                  InkWell(
                    onTap: () {
                      setState(() => _courses = false);
                      context.push('/courses');
                    },
                    child: const Column(
                      children: [
                        Icon(
                          Icons.add_box_outlined,
                          size: 52,
                          color: ReferenceColors.disabled,
                        ),
                        Text('Course', style: headingStyle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LearningCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '$start',
                          key: const ValueKey('course-score-start'),
                          style: headingStyle,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: LinearProgressIndicator(
                            key: const ValueKey('course-score-progress'),
                            value: value,
                            minHeight: 16,
                            borderRadius: BorderRadius.circular(20),
                            color: LearningColors.green,
                            backgroundColor: ReferenceColors.border,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('$next', style: headingStyle),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your English Score is ${progress.score}',
                      style: const TextStyle(
                        fontSize: 17,
                        color: ReferenceColors.muted,
                      ),
                    ),
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
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _courses = false);
                  context.push('/sections');
                },
                child: const Text(
                  'VIEW SECTIONS',
                  style: TextStyle(
                    color: LearningColors.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PathNode extends StatelessWidget {
  const PathNode({
    required this.current,
    required this.completed,
    required this.icon,
    required this.onTap,
    this.progress = .25,
    this.tooltip = 'Lesson',
    this.color,
    this.edgeColor,
    super.key,
  });
  final bool current, completed;
  final double progress;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;
  final Color? edgeColor;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 100,
          height: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (current)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: motionDuration(context, 450),
                  builder: (context, value, _) => CustomPaint(
                    size: const Size(98, 87),
                    painter: _NodeRing(value, color ?? LearningColors.green),
                  ),
                ),
              Container(
                width: 70,
                height: 62,
                decoration: BoxDecoration(
                  color:
                      color ??
                      (current || completed
                          ? completed
                                ? LearningColors.yellow
                                : LearningColors.green
                          : ReferenceColors.border),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color:
                          edgeColor ??
                          (current || completed
                              ? completed
                                    ? const Color(0xFFE5A400)
                                    : LearningColors.greenDark
                              : const Color(0xFFBCBABC)),
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Icon(
                  completed ? Icons.check_rounded : icon,
                  size: 36,
                  color: color != null || current || completed
                      ? Colors.white
                      : ReferenceColors.disabled,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NodeRing extends CustomPainter {
  _NodeRing(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 3, size.width - 8, size.height - 7);
    final paint = Paint()
      ..color = ReferenceColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(rect, paint);
    paint.color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(_NodeRing oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _GuideIconPainter extends CustomPainter {
  const _GuideIconPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paper = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 2, 22, 25),
        const Radius.circular(3),
      ),
      paper,
    );
    final ink = Paint()..color = color;
    for (final y in [8.0, 14.0, 20.0]) {
      canvas.drawCircle(Offset(8, y), 2.5, ink);
      canvas.drawCircle(Offset(4, y), 1.5, paper);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(14, y - 1.5, 9, 3),
          const Radius.circular(1.5),
        ),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(_GuideIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
