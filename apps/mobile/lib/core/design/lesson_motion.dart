import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'reference_theme.dart';

/// Geometry from the archived lesson captures; timings from the UI task.
abstract final class LessonMotionTokens {
  static const pressDuration = Duration(milliseconds: 100);
  static const matchFlash = Duration(milliseconds: 150);
  static const matchSettle = Duration(milliseconds: 200);
  static const mismatchShake = Duration(milliseconds: 300);
  static const progressDuration = Duration(milliseconds: 300);
  static const feedbackDuration = Duration(milliseconds: 250);
  static const heartDuration = Duration(milliseconds: 300);
  static const ease = Curves.easeOutCubic;
  static const progressHeight = 16.0;
  static const shineInset = 4.0;
  static const shineHeight = 4.0;
  static const shineHorizontalInset = 8.0;
  static const greenShine = Color(0xFF78D42B);
  static const orangeShine = Color(0xFFFFB347);
  static const heartDisplacement = 4.0;
  static const heartOscillations = 3;
}

class LessonProgressBar extends StatelessWidget {
  const LessonProgressBar({
    required this.value,
    required this.color,
    required this.shineColor,
    this.trackColor = ReferenceColors.border,
    super.key,
  });

  final double value;
  final Color color;
  final Color shineColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Lesson progress',
    value: '${(value.clamp(0, 1) * 100).round()} percent',
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : LessonMotionTokens.progressDuration,
      curve: LessonMotionTokens.ease,
      builder: (context, fill, _) => SizedBox(
        height: LessonMotionTokens.progressHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth * fill;
            return ClipRRect(
              borderRadius: BorderRadius.circular(
                LessonMotionTokens.progressHeight / 2,
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: trackColor)),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: DecoratedBox(
                      key: const ValueKey('lesson-progress-fill'),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(
                          LessonMotionTokens.progressHeight / 2,
                        ),
                      ),
                    ),
                  ),
                  if (width > LessonMotionTokens.shineHorizontalInset * 2)
                    Positioned(
                      left: LessonMotionTokens.shineHorizontalInset,
                      top: LessonMotionTokens.shineInset,
                      width:
                          width - LessonMotionTokens.shineHorizontalInset * 2,
                      height: LessonMotionTokens.shineHeight,
                      child: DecoratedBox(
                        key: const ValueKey('lesson-progress-shine'),
                        decoration: BoxDecoration(
                          color: shineColor,
                          borderRadius: BorderRadius.circular(
                            LessonMotionTokens.shineHeight / 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// Only a decrease plays the loss effect; rebuilds and new questions do not.
class LessonHeartCounter extends StatefulWidget {
  const LessonHeartCounter({
    required this.hearts,
    required this.child,
    super.key,
  });
  final int hearts;
  final Widget child;

  @override
  State<LessonHeartCounter> createState() => _LessonHeartCounterState();
}

class _LessonHeartCounterState extends State<LessonHeartCounter>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LessonMotionTokens.heartDuration,
    value: 1,
  );
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
    if (!_allowed) _controller.value = 1;
  }

  @override
  void didUpdateWidget(LessonHeartCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hearts < oldWidget.hearts && _allowed) {
      _controller.forward(from: 0);
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
  Widget build(BuildContext context) => Semantics(
    label: '${widget.hearts} hearts remaining',
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _controller.value;
          final offset = t == 1
              ? 0.0
              : math.sin(
                      t * math.pi * 2 * LessonMotionTokens.heartOscillations,
                    ) *
                    (1 - t) *
                    LessonMotionTokens.heartDisplacement;
          return Transform.translate(
            key: const ValueKey('lesson-heart-shake'),
            offset: Offset(offset, 0),
            child: child,
          );
        },
      ),
    ),
  );
}

class LessonFeedbackEntrance extends StatelessWidget {
  const LessonFeedbackEntrance({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : LessonMotionTokens.feedbackDuration,
      curve: LessonMotionTokens.ease,
      child: child,
      builder: (context, value, child) =>
          FractionalTranslation(translation: Offset(0, value), child: child),
    ),
  );
}
