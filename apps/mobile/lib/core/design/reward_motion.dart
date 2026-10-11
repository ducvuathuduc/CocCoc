import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class RewardMotionTokens {
  static const countDuration = Duration(milliseconds: 500);
  static const celebrationDuration = Duration(milliseconds: 600);
  static const countCurve = Curves.easeOutCubic;
  static const particleCount = 18;
  static const particleWidth = 5.0;
  static const particleHeight = 9.0;
  static const particleRadius = 2.0;
  static const particleDrift = 20.0;
  static const colors = [
    Color(0xFFFFC800),
    Color(0xFF58CC02),
    Color(0xFF1CB0F6),
    Color(0xFFCE82FF),
  ];
}

/// Display-only interpolation. The caller supplies the final receipt semantics.
class RewardCount extends StatelessWidget {
  const RewardCount({
    required this.value,
    this.suffix = '',
    this.style,
    super.key,
  });
  final int value;
  final String suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : RewardMotionTokens.countDuration,
    curve: RewardMotionTokens.countCurve,
    builder: (context, count, _) => Text(
      '${count.round()}$suffix',
      maxLines: 1,
      textAlign: TextAlign.center,
      style: style,
    ),
  );
}

/// Authored geometric confetti; bundled character artwork stays unchanged.
class LessonCelebration extends StatefulWidget {
  const LessonCelebration({required this.child, super.key});
  final Widget child;
  @override
  State<LessonCelebration> createState() => _LessonCelebrationState();
}

class _LessonCelebrationState extends State<LessonCelebration>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RewardMotionTokens.celebrationDuration,
  );
  bool _started = false;
  bool _active = true;

  bool get _allowed =>
      _active &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_allowed) {
      _started = true;
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) _controller.value = 1;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Stack(
      children: [
        child!,
        if (_allowed && _controller.value < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(
                  key: const ValueKey('lesson-completion-confetti'),
                  painter: _ConfettiPainter(_controller.value),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var index = 0; index < RewardMotionTokens.particleCount; index++) {
      final lane =
          ((index * 7) % RewardMotionTokens.particleCount + .5) /
          RewardMotionTokens.particleCount;
      final start = (index % 3) * size.height * .08;
      final x =
          size.width * lane +
          math.sin(progress * math.pi * 2 + index) *
              RewardMotionTokens.particleDrift;
      final y = start + progress * size.height * .75;
      paint.color = RewardMotionTokens
          .colors[index % RewardMotionTokens.colors.length]
          .withValues(alpha: 1 - progress);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(index + progress * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: RewardMotionTokens.particleWidth,
            height: RewardMotionTokens.particleHeight,
          ),
          const Radius.circular(RewardMotionTokens.particleRadius),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
