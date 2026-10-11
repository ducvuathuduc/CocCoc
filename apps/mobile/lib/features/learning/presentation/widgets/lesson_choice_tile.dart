import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/reference_theme.dart';
import '../learning_visuals.dart';
import 'lesson_exercise_colors.dart';

enum ChoiceTileTone { idle, selected, correct, wrong, disabled }

/// Shared 3D answer tile used by every choice-style exercise.
///
/// Motion (all skipped under reduced motion):
/// * press-down: face sinks onto its 3px edge while the finger is down;
/// * select bounce: 0.94 → 1.04 → 1 scale when the tile becomes selected;
/// * wrong shake: horizontal shake when [shakeEpoch] changes.
class LessonChoiceTile extends StatefulWidget {
  const LessonChoiceTile({
    required this.child,
    this.onTap,
    this.selected = false,
    this.correct,
    this.tone,
    this.shakeEpoch = 0,
    this.padding = const EdgeInsets.all(16),
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final bool? correct;

  /// Overrides the tone derived from [selected]/[correct].
  final ChoiceTileTone? tone;
  final int shakeEpoch;
  final EdgeInsets padding;
  final String? semanticLabel;

  ChoiceTileTone get effectiveTone =>
      tone ??
      (!selected
          ? ChoiceTileTone.idle
          : correct == true
          ? ChoiceTileTone.correct
          : correct == false
          ? ChoiceTileTone.wrong
          : ChoiceTileTone.selected);

  @override
  State<LessonChoiceTile> createState() => _LessonChoiceTileState();
}

class _LessonChoiceTileState extends State<LessonChoiceTile>
    with TickerProviderStateMixin {
  static const _edge = 3.0;
  bool _pressed = false;
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  static final _bounceScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: .94), weight: 25),
    TweenSequenceItem(tween: Tween(begin: .94, end: 1.04), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: 1), weight: 35),
  ]);

  bool get _animate => !MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(LessonChoiceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameSelected =
        widget.effectiveTone == ChoiceTileTone.selected &&
        oldWidget.effectiveTone != ChoiceTileTone.selected;
    if (becameSelected && _animate) _bounce.forward(from: 0);
    if (widget.shakeEpoch != oldWidget.shakeEpoch && _animate) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.effectiveTone;
    final (border, fill) = switch (tone) {
      ChoiceTileTone.idle => (ReferenceColors.border, ReferenceColors.surface),
      ChoiceTileTone.selected => (
        ReferenceColors.blueBorder,
        ReferenceColors.blueFill,
      ),
      ChoiceTileTone.correct => (
        LessonExerciseColors.matchedBorder,
        LearningColors.correct,
      ),
      ChoiceTileTone.wrong => (LearningColors.red, LearningColors.incorrect),
      ChoiceTileTone.disabled => (
        ReferenceColors.border,
        ReferenceColors.surface,
      ),
    };
    final enabled = widget.onTap != null;
    final pressed = _pressed && enabled;
    final duration = motionDuration(context, 90);
    return Semantics(
      selected: widget.selected,
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        child: AnimatedBuilder(
          animation: Listenable.merge([_bounce, _shake]),
          builder: (context, child) {
            final t = _shake.value;
            final dx = t >= 1 ? 0.0 : math.sin(t * math.pi * 6) * (1 - t) * 6;
            final scale = _bounce.value >= 1
                ? 1.0
                : _bounceScale.transform(_bounce.value);
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 4),
            transform: Matrix4.translationValues(0, pressed ? _edge : 0, 0),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: border,
                  offset: Offset(0, pressed ? 0 : _edge),
                ),
              ],
            ),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
