import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'reference_theme.dart';

/// Geometry from the archived lesson captures; timings from the UI task.
abstract final class LessonMotionTokens {
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

  /// Transient glow around the bar when a combo answer lands (fades to none).
  static const comboGlowDuration = Duration(milliseconds: 650);
  static const comboGlowBlur = 12.0;

  /// "N IN A ROW" pop-in and the feedback icon pop (Duolingo-style bounce).
  static const popDuration = Duration(milliseconds: 420);
  static const popCurve = Curves.elasticOut;
  static const popFrom = 0.55;

  /// A lost heart floats up and fades from the counter.
  static const heartGhostScale = 0.7;
  static const heartGhostRise = 14.0;
}

/// Scales [child] in from [LessonMotionTokens.popFrom] with an elastic
/// overshoot each time [trigger] changes (and on first build); the resting
/// frame is the child untouched, so goldens of settled screens do not change.
class LessonPop extends StatelessWidget {
  const LessonPop({required this.trigger, required this.child, super.key});

  final Object trigger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: LessonMotionTokens.popFrom, end: 1),
      duration: LessonMotionTokens.popDuration,
      curve: LessonMotionTokens.popCurve,
      child: child,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
    );
  }
}

class LessonProgressBar extends StatelessWidget {
  const LessonProgressBar({
    required this.value,
    required this.color,
    required this.shineColor,
    this.comboPulse,
    super.key,
  });

  final double value;
  final Color color;
  final Color shineColor;

  /// Changes (e.g. the streak count) while a combo is running: each change
  /// flashes a glow in [shineColor] around the bar that fades back to none.
  final Object? comboPulse;

  @override
  Widget build(BuildContext context) {
    final bar = _bar(context);
    if (comboPulse == null || MediaQuery.disableAnimationsOf(context)) {
      return bar;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(comboPulse),
      tween: Tween(begin: 1, end: 0),
      duration: LessonMotionTokens.comboGlowDuration,
      curve: Curves.easeOut,
      child: bar,
      builder: (context, glow, child) => glow == 0
          ? child!
          : DecoratedBox(
              key: const ValueKey('lesson-progress-glow'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  LessonMotionTokens.progressHeight / 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shineColor.withValues(alpha: .85 * glow),
                    blurRadius: LessonMotionTokens.comboGlowBlur * glow,
                    spreadRadius: 2 * glow,
                  ),
                ],
              ),
              child: child,
            ),
    );
  }

  Widget _bar(BuildContext context) => Semantics(
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
                  const Positioned.fill(
                    child: ColoredBox(color: ReferenceColors.border),
                  ),
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
    this.ghost,
    super.key,
  });
  final int hearts;
  final Widget child;

  /// What floats away when a heart is lost (defaults to [child]); aligned to
  /// the counter's leading edge.
  final Widget? ghost;

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
          final shaken = Transform.translate(
            key: const ValueKey('lesson-heart-shake'),
            offset: Offset(offset, 0),
            child: child,
          );
          if (t == 1) return shaken;
          // The lost heart: a copy that rises, grows and fades out.
          return Stack(
            clipBehavior: Clip.none,
            children: [
              shaken,
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    key: const ValueKey('lesson-heart-ghost'),
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -LessonMotionTokens.heartGhostRise * t),
                      child: Transform.scale(
                        scale: 1 + LessonMotionTokens.heartGhostScale * t,
                        alignment: widget.ghost == null
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: widget.ghost == null
                            ? child
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: widget.ghost,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
