import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/duo_motion.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/learning_controller.dart';
import '../domain/learning_models.dart';
import '../../progress/application/extended_controller.dart';
import '../../progress/application/preview_controller.dart';
import 'learning_visuals.dart';

class LearningPath extends ConsumerStatefulWidget {
  const LearningPath({super.key});
  @override
  ConsumerState<LearningPath> createState() => _LearningPathState();
}

class _LearningPathState extends ConsumerState<LearningPath> {
  int? _selected;
  bool _courses = false;
  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(learningStateProvider);
    final draft = ref.watch(lessonControllerProvider);
    final energy = ref.watch(extendedControllerProvider);
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
                    _unitBanner(context, 1, 'Use basic phrases'),
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
                    _unitBanner(context, 2, 'Introduce yourself'),
                    const SizedBox(height: 25),
                    Center(
                      child: PathNode(
                        current: false,
                        completed: false,
                        icon: Icons.lock_rounded,
                        onTap: () => showLearningNotice(
                          context,
                          'Keep learning!',
                          'Complete Unit 1 to unlock this unit.',
                        ),
                      ),
                    ),
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
      color: LearningColors.green,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(color: LearningColors.greenDark, offset: Offset(0, 4)),
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
                  'SECTION 1, UNIT $unit',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD7FFB8),
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
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: LearningColors.greenDark, width: 2),
            ),
          ),
          child: IconButton(
            tooltip: 'Unit $unit guidebook',
            onPressed: () => context.push('/units/unit-$unit/guide'),
            icon: const ReferenceArt(LearningArt.guide, width: 30, height: 29),
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
    final current = i == progress.currentNode;
    final completed = progress.completedNodes.contains('node-$i');
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
                draft.stage == LessonStage.paused
                    ? 'RESUME'
                    : progress.completedLessons > 0
                    ? 'CONTINUE'
                    : 'START',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: LearningColors.greenDark,
                ),
              ),
            ),
          PathNode(
            current: current,
            completed: completed,
            progress: (progress.lessonInNode + 1) / 5,
            icon: i == 2
                ? Icons.headphones_rounded
                : i == 3
                ? Icons.mic_rounded
                : i == 5
                ? Icons.inventory_2_rounded
                : Icons.star_rounded,
            tooltip: current
                ? 'Start lesson ${progress.lessonInNode + 1}'
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
        const Text(
          'Use basic phrases',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Lesson ${progress.lessonInNode + 1} of 5',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        const SizedBox(height: 16),
        ReferenceButton(
          label: draft.stage == LessonStage.paused
              ? 'RESUME LESSON'
              : 'START +20 XP',
          backgroundColor: Colors.white,
          edgeColor: const Color(0xFFD7FFB8),
          foregroundColor: LearningColors.green,
          onPressed: () {
            final controller = ref.read(lessonControllerProvider.notifier);
            if (draft.stage == LessonStage.paused) {
              controller.resume();
            } else {
              controller.start(nodeId: 'node-$i');
            }
            setState(() => _selected = null);
            context.push('/lesson/node-$i');
          },
        ),
      ],
    ),
  );

  Widget _coursePanel(BuildContext context, LearningState progress) => Material(
    color: ReferenceColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                children: [
                  ReferenceArt(LearningArt.english, width: 72, height: 54),
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
                      size: 64,
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
                LinearProgressIndicator(
                  value: .1,
                  minHeight: 16,
                  borderRadius: BorderRadius.circular(20),
                  color: LearningColors.green,
                  backgroundColor: ReferenceColors.border,
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
              'SECTIONS',
              style: TextStyle(
                color: LearningColors.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class PathNode extends StatelessWidget {
  const PathNode({
    required this.current,
    required this.completed,
    required this.icon,
    required this.onTap,
    this.progress = .25,
    this.tooltip = 'Lesson',
    super.key,
  });
  final bool current, completed;
  final double progress;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
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
                    painter: _NodeRing(value),
                  ),
                ),
              Container(
                width: 70,
                height: 62,
                decoration: BoxDecoration(
                  color: current || completed
                      ? completed
                            ? LearningColors.yellow
                            : LearningColors.green
                      : ReferenceColors.border,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: current || completed
                          ? completed
                                ? const Color(0xFFE5A400)
                                : LearningColors.greenDark
                          : const Color(0xFFBCBABC),
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Icon(
                  completed ? Icons.check_rounded : icon,
                  size: 36,
                  color: current || completed
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
  _NodeRing(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 3, size.width - 8, size.height - 7);
    final paint = Paint()
      ..color = ReferenceColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(rect, paint);
    paint.color = LearningColors.green;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(_NodeRing oldDelegate) => oldDelegate.progress != progress;
}

class UnitGuideScreen extends StatelessWidget {
  const UnitGuideScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          LearningHeader(
            title: 'SECTION 1, UNIT 1',
            onClose: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SizedBox(height: 22),
                const Center(
                  child: ReferenceArt(
                    LearningArt.guideCharacter,
                    width: 145,
                    height: 197,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Use basic phrases',
                  textAlign: TextAlign.center,
                  style: headingStyle,
                ),
                const SizedBox(height: 28),
                const Divider(thickness: 2),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'KEY PHRASES',
                    style: TextStyle(
                      color: LearningColors.blue,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final phrase in const [
                  ('Hello!', 'Xin chào!'),
                  ('Thank you very much.', 'Cảm ơn bạn rất nhiều.'),
                  ('Goodbye.', 'Tạm biệt.'),
                  ('Nice to meet you.', 'Rất vui được gặp bạn.'),
                ])
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    child: SpeechBubble(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            tooltip: 'Listen to ${phrase.$1}',
                            onPressed: () => showLearningNotice(
                              context,
                              'Audio preview',
                              'The bundled text is available offline. Recorded phrase audio is not connected in this mock preview.',
                            ),
                            icon: const Icon(
                              Icons.volume_up_rounded,
                              color: LearningColors.blue,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  phrase.$1,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  phrase.$2,
                                  style: const TextStyle(
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
                  ),
                Container(
                  color: ReferenceColors.blueFill,
                  padding: const EdgeInsets.all(20),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIP',
                        style: TextStyle(
                          color: LearningColors.blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 15),
                      Text('Hello!', style: headingStyle),
                      SizedBox(height: 12),
                      Text(
                        'Use hello to greet someone. You can also say good morning, good afternoon or good evening.',
                        style: TextStyle(fontSize: 18),
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
