import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/character_motion.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/unit_skip_controller.dart';
import '../domain/unit_skip.dart';
import 'learning_visuals.dart';

abstract final class _UnitSkipArt {
  static const intro = ArtRegion(
    'unit-skip-intro',
    Rect.fromLTWH(340, 680, 500, 570),
  );
  static const exercise = ArtRegion(
    'unit-skip-exercise',
    Rect.fromLTWH(78, 484, 270, 510),
  );
  static const warning = ArtRegion(
    'unit-skip-warning',
    Rect.fromLTWH(890, 1090, 289, 500),
  );
  static const failed = ArtRegion(
    'unit-skip-failed',
    Rect.fromLTWH(290, 835, 600, 455),
  );
  static const passed = ArtRegion(
    'unit-skip-result',
    Rect.fromLTWH(265, 490, 600, 670),
  );
}

class UnitSkipScreen extends ConsumerStatefulWidget {
  const UnitSkipScreen({
    required this.unit,
    required this.onClose,
    required this.onPassed,
    this.section = 1,
    this.sectionCheck = false,
    this.targetLabel,
    super.key,
  });

  final int unit;
  final int section;
  final bool sectionCheck;
  final VoidCallback onClose;
  final VoidCallback onPassed;
  final String? targetLabel;

  @override
  ConsumerState<UnitSkipScreen> createState() => _UnitSkipScreenState();
}

class _UnitSkipScreenState extends ConsumerState<UnitSkipScreen> {
  bool _closing = false;
  bool _finished = false;

  @override
  void didUpdateWidget(UnitSkipScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unit != widget.unit ||
        oldWidget.section != widget.section ||
        oldWidget.sectionCheck != widget.sectionCheck) {
      _closing = false;
      _finished = false;
    }
  }

  void _close() {
    if (_closing || _finished) return;
    _closing = true;
    widget.onClose();
  }

  void _complete(UnitSkipController controller) {
    if (_closing || _finished || !controller.acknowledgePass()) return;
    _finished = true;
    widget.onPassed();
  }

  @override
  Widget build(BuildContext context) {
    final provider = unitSkipControllerProvider(
      widget.unit,
      section: widget.section,
      sectionCheck: widget.sectionCheck,
    );
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final target = widget.targetLabel ?? 'Unit ${widget.unit}';
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: ReferenceColors.surface,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: motionDuration(context, 220),
            child: KeyedSubtree(
              key: ValueKey<UnitSkipStage>(state.stage),
              child: switch (state.stage) {
                UnitSkipStage.intro => _Intro(
                  target: target,
                  onStart: controller.start,
                  onClose: _close,
                ),
                UnitSkipStage.answering || UnitSkipStage.feedback => _Exercise(
                  state: state,
                  onClose: _close,
                  onToggle: controller.toggleToken,
                  onCheck: controller.check,
                  onContinue: controller.continueAfterFeedback,
                ),
                UnitSkipStage.lastHeartWarning => _Warning(
                  state: state,
                  onClose: _close,
                  onContinue: controller.continueAfterWarning,
                ),
                UnitSkipStage.failed => _Terminal(
                  art: _UnitSkipArt.failed,
                  artWidth: 230,
                  artHeight: 174.42,
                  title:
                      "You didn't unlock $target, but you can try again later!",
                  buttonLabel: 'CONTINUE',
                  onPressed: _close,
                ),
                UnitSkipStage.passed => _Passed(
                  state: state,
                  target: target,
                  onPressed: () => _complete(controller),
                ),
                UnitSkipStage.unavailable => _Unavailable(onClose: _close),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    required this.target,
    required this.onStart,
    required this.onClose,
  });

  final String target;
  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => _ScrollableStage(
    child: Column(
      children: [
        const Spacer(),
        const ReferenceArt(_UnitSkipArt.intro, width: 167, height: 190),
        const SizedBox(height: 30),
        Text(
          'Pass this test to jump ahead to $target!',
          textAlign: TextAlign.center,
          style: headingStyle.copyWith(fontSize: 28),
        ),
        const Spacer(flex: 2),
        ReferenceButton(
          label: "LET'S GO",
          minHeight: 52,
          backgroundColor: LearningColors.blue,
          edgeColor: LearningColors.blueDark,
          onPressed: onStart,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: TextButton(
            onPressed: onClose,
            child: const Text(
              'NOT NOW',
              style: TextStyle(
                color: LearningColors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Exercise extends StatelessWidget {
  const _Exercise({
    required this.state,
    required this.onClose,
    required this.onToggle,
    required this.onCheck,
    required this.onContinue,
  });

  final UnitSkipState state;
  final VoidCallback onClose;
  final ValueChanged<String> onToggle;
  final VoidCallback onCheck;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final question = state.currentQuestion!;
    final feedback = state.stage == UnitSkipStage.feedback;
    final reaction = !feedback
        ? CharacterReaction.reset
        : state.correct == true
        ? CharacterReaction.correct
        : CharacterReaction.incorrect;
    final epoch =
        'unit-skip:section=${state.section}:unit=${state.unit}:'
        'sectionCheck=${state.sectionCheck}:question=${state.questionIndex}';
    Widget character(double width, double height) => CharacterMotion(
      character: LessonCharacter.lin,
      reaction: reaction,
      epoch: epoch,
      width: width,
      height: height,
      fallback: ReferenceArt(
        _UnitSkipArt.exercise,
        width: width,
        height: height,
      ),
    );
    return Column(
      children: [
        _ExerciseHeader(state: state, onClose: onClose),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              20,
              18,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Translate this sentence',
                      style: headingStyle.copyWith(fontSize: 27),
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final prompt = SpeechBubble(
                          child: Text(
                            question.prompt,
                            style: const TextStyle(fontSize: 20),
                          ),
                        );
                        if (constraints.maxWidth < 350) {
                          return Column(
                            children: [
                              character(86, 162),
                              const SizedBox(height: 10),
                              prompt,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            character(92, 174),
                            const SizedBox(width: 12),
                            Expanded(child: prompt),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Container(
                      constraints: const BoxConstraints(minHeight: 94),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: ReferenceColors.border,
                            width: 2,
                          ),
                          bottom: BorderSide(
                            color: ReferenceColors.border,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: state.selectedTokenIds
                            .map(
                              (id) => question.tokens.firstWhere(
                                (token) => token.id == id,
                              ),
                            )
                            .map(
                              (token) => _WordToken(
                                token: token,
                                selected: true,
                                enabled: !feedback,
                                onTap: () => onToggle(token.id),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 12,
                      children: question.tokens
                          .where(
                            (token) =>
                                !state.selectedTokenIds.contains(token.id),
                          )
                          .map(
                            (token) => _WordToken(
                              token: token,
                              selected: false,
                              enabled: !feedback,
                              onTap: () => onToggle(token.id),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 36),
                    if (feedback)
                      _Feedback(
                        correct: state.correct!,
                        answer: question.answerText,
                        onContinue: onContinue,
                      )
                    else
                      ReferenceButton(
                        label: 'CHECK',
                        minHeight: 52,
                        onPressed: state.canCheck ? onCheck : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseHeader extends StatelessWidget {
  const _ExerciseHeader({required this.state, required this.onClose});

  final UnitSkipState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              size: 34,
              color: ReferenceColors.disabled,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Semantics(
            label: 'Test progress',
            value:
                '${((state.questionIndex + (state.correct == true ? 1 : 0)) / state.questions.length * 100).round()}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 16,
                value:
                    (state.questionIndex + (state.correct == true ? 1 : 0)) /
                    state.questions.length,
                color: LearningColors.green,
                backgroundColor: ReferenceColors.border,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: '${state.hearts} hearts remaining',
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(
                5,
                (index) => Icon(
                  Icons.favorite_rounded,
                  size: 19,
                  color: index < state.hearts
                      ? LearningColors.orange
                      : ReferenceColors.border,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _WordToken extends StatelessWidget {
  const _WordToken({
    required this.token,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final UnitSkipToken token;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: selected ? '${token.text}, selected' : token.text,
    selected: selected,
    button: enabled,
    child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: LearningCard(
          selected: selected,
          onTap: enabled ? onTap : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Text(token.text, style: const TextStyle(fontSize: 18)),
        ),
      ),
    ),
  );
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.correct,
    required this.answer,
    required this.onContinue,
  });

  final bool correct;
  final String answer;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final color = correct ? LearningColors.greenDark : LearningColors.redDark;
    return Semantics(
      liveRegion: true,
      label: correct ? 'Correct' : 'Incorrect. Correct answer: $answer',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: correct ? LearningColors.correct : LearningColors.incorrect,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              correct ? 'Excellent!' : 'Incorrect',
              style: headingStyle.copyWith(color: color),
            ),
            if (!correct) ...[
              const SizedBox(height: 8),
              Text(
                'Correct answer: $answer',
                style: TextStyle(color: color, fontSize: 18),
              ),
            ],
            const SizedBox(height: 16),
            ReferenceButton(
              label: 'CONTINUE',
              minHeight: 52,
              backgroundColor: correct
                  ? LearningColors.green
                  : LearningColors.red,
              edgeColor: color,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({
    required this.state,
    required this.onClose,
    required this.onContinue,
  });

  final UnitSkipState state;
  final VoidCallback onClose;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    const message = _WarningBubble(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Careful! You can only make '),
            TextSpan(
              text: '1 more mistake',
              style: TextStyle(
                color: LearningColors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: '!'),
          ],
        ),
      ),
    );
    return Column(
      children: [
        _ExerciseHeader(state: state, onClose: onClose),
        Expanded(
          child: _ScrollableStage(
            child: Column(
              children: [
                const Spacer(),
                if (compact)
                  const Column(
                    children: [
                      message,
                      SizedBox(height: 14),
                      ReferenceArt(
                        _UnitSkipArt.warning,
                        width: 96,
                        height: 166,
                      ),
                    ],
                  )
                else
                  const Row(
                    children: [
                      Expanded(child: message),
                      SizedBox(width: 10),
                      ReferenceArt(
                        _UnitSkipArt.warning,
                        width: 96,
                        height: 166,
                      ),
                    ],
                  ),
                const Spacer(),
                ReferenceButton(
                  label: 'CONTINUE',
                  minHeight: 52,
                  onPressed: onContinue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WarningBubble extends StatelessWidget {
  const _WarningBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _WarningBubblePainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 28, 14),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontSize: 20,
          height: 1.42,
          color: ReferenceColors.ink,
        ),
        child: child,
      ),
    ),
  );
}

class _WarningBubblePainter extends CustomPainter {
  const _WarningBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width - 12, size.height);
    final shape = RRect.fromRectAndRadius(body, const Radius.circular(13));
    final fill = Paint()..color = ReferenceColors.surface;
    final stroke = Paint()
      ..color = ReferenceColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas
      ..drawRRect(shape, fill)
      ..drawRRect(shape, stroke);
    final y = size.height * .62;
    final tail = Path()
      ..moveTo(body.right - 1, y - 10)
      ..lineTo(size.width, y + 1)
      ..quadraticBezierTo(size.width + 1, y + 4, size.width - 4, y + 4)
      ..lineTo(body.right - 1, y + 4);
    canvas
      ..drawPath(tail, fill)
      ..drawPath(tail, stroke)
      ..drawLine(
        Offset(body.right, y - 9),
        Offset(body.right, y + 3),
        Paint()
          ..color = ReferenceColors.surface
          ..strokeWidth = 3,
      );
  }

  @override
  bool shouldRepaint(covariant _WarningBubblePainter oldDelegate) => false;
}

class _Passed extends StatelessWidget {
  const _Passed({
    required this.state,
    required this.target,
    required this.onPressed,
  });

  final UnitSkipState state;
  final String target;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final mistakes = 5 - state.hearts;
    final attempts = state.questions.length + mistakes;
    final good = attempts == 0
        ? 0
        : (state.questions.length / attempts * 100).round();
    final metrics = <Widget>[
      const _ResultMetric(
        label: 'TOTAL XP',
        value: '0',
        icon: Icons.bolt_rounded,
        color: LearningColors.yellow,
      ),
      _ResultMetric(
        label: 'GOOD',
        value: '$good%',
        icon: Icons.track_changes_rounded,
        color: LearningColors.green,
      ),
      _ResultMetric(
        label: 'QUESTIONS',
        value: '${state.questions.length}',
        icon: Icons.quiz_rounded,
        color: LearningColors.blue,
      ),
    ];
    return _ScrollableStage(
      child: Column(
        children: [
          const Spacer(),
          const ReferenceArt(_UnitSkipArt.passed, width: 200, height: 223),
          const SizedBox(height: 14),
          const Text(
            'Speedrun vibes',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LearningColors.yellow,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You passed the test and unlocked $target.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReferenceColors.muted,
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  metrics[index],
                  if (index < metrics.length - 1) const SizedBox(height: 10),
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  Expanded(child: metrics[index]),
                  if (index < metrics.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          const Spacer(),
          ReferenceButton(
            label: 'CONTINUE',
            minHeight: 52,
            backgroundColor: LearningColors.blue,
            edgeColor: LearningColors.blueDark,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label, $value',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 9, 8, 11),
        decoration: BoxDecoration(
          color: ReferenceColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Icon(icon, color: color, size: 25),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Terminal extends StatelessWidget {
  const _Terminal({
    required this.art,
    required this.artWidth,
    required this.artHeight,
    required this.title,
    required this.buttonLabel,
    required this.onPressed,
  });

  final ArtRegion art;
  final double artWidth;
  final double artHeight;
  final String title;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _ScrollableStage(
    child: Column(
      children: [
        const Spacer(),
        ReferenceArt(art, width: artWidth, height: artHeight),
        const SizedBox(height: 24),
        Text(title, textAlign: TextAlign.center, style: headingStyle),
        const Spacer(flex: 2),
        ReferenceButton(
          label: buttonLabel,
          minHeight: 52,
          backgroundColor: LearningColors.blue,
          edgeColor: LearningColors.blueDark,
          onPressed: onPressed,
        ),
      ],
    ),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => _ScrollableStage(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 72,
          color: ReferenceColors.disabled,
        ),
        const SizedBox(height: 20),
        const Text(
          'This unit test is unavailable.',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 32),
        ReferenceButton(label: 'CLOSE', minHeight: 52, onPressed: onClose),
      ],
    ),
  );
}

class _ScrollableStage extends StatelessWidget {
  const _ScrollableStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            minHeight: constraints.maxHeight - 40,
          ),
          child: IntrinsicHeight(child: child),
        ),
      ),
    ),
  );
}
