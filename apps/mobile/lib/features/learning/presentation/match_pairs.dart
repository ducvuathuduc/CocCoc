import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/lesson_motion.dart';
import '../domain/learning_models.dart';
import 'learning_visuals.dart';

class MatchPairsExercise extends StatefulWidget {
  const MatchPairsExercise({
    required this.exercise,
    required this.state,
    required this.onLeft,
    required this.onRight,
    required this.onFinish,
    super.key,
  });
  final Exercise exercise;
  final LessonState state;
  final ValueChanged<String>? onLeft, onRight;
  final ValueChanged<int> onFinish;

  @override
  State<MatchPairsExercise> createState() => _MatchPairsExerciseState();
}

class _MatchPairsExerciseState extends State<MatchPairsExercise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _effect;
  late List<String> _left, _right;
  int? _revision;

  @override
  void initState() {
    super.initState();
    _effect = AnimationController(vsync: this)..addStatusListener(_status);
    _order();
  }

  void _order() {
    final seed = widget.exercise.id.codeUnits.fold(0, (a, b) => a * 31 + b);
    _left = widget.exercise.pairs.keys.toList()..shuffle(math.Random(seed));
    _right = widget.exercise.pairs.values.toList()
      ..shuffle(math.Random(seed + 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MatchPairsExercise oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) _order();
    _sync();
  }

  void _sync() {
    final attempt = widget.state.pairAttempt;
    if (attempt == null || widget.state.stage != LessonStage.answering) {
      _revision = null;
      _effect.stop();
      return;
    }
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_revision == attempt.revision && !reduced) return;
    _revision = attempt.revision;
    _effect.stop();
    if (reduced) {
      _finishAfterFrame(attempt.revision);
    } else {
      _effect.duration = attempt.outcome == PairOutcome.matched
          ? LessonMotionTokens.matchFlash + LessonMotionTokens.matchSettle
          : LessonMotionTokens.mismatchShake;
      _effect.forward(from: 0);
    }
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed && _revision != null) {
      _finishAfterFrame(_revision!);
    }
  }

  void _finishAfterFrame(int revision) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.state.pairAttempt?.revision == revision) {
        widget.onFinish(revision);
      }
    });
  }

  @override
  void dispose() {
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 55 + 25 / 3),
    child: AnimatedBuilder(
      animation: _effect,
      builder: (context, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _column(_left, true)),
          const SizedBox(width: 24),
          Expanded(child: _column(_right, false)),
        ],
      ),
    ),
  );

  Widget _column(List<String> ids, bool left) => Column(
    children: [
      for (var i = 0; i < ids.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _tile(ids[i], left, i),
        ),
    ],
  );

  Widget _tile(String id, bool left, int index) {
    final state = widget.state;
    final attempt = state.pairAttempt;
    final active =
        attempt != null &&
        (left ? attempt.leftId == id : attempt.rightId == id);
    final matched = left
        ? state.matchedPairs.containsKey(id)
        : state.matchedPairs.containsValue(id);
    final selected =
        (left ? state.selectedPairLeft : state.selectedPairRight) == id;
    final reduced = MediaQuery.disableAnimationsOf(context);
    Color fill = MatchTileTokens.surface;
    Color border = MatchTileTokens.border;
    Color ink = matched ? MatchTileTokens.border : MatchTileTokens.ink;
    double shake = 0;
    var settled = matched;
    if (active && !reduced) {
      settled = false;
      if (attempt.outcome == PairOutcome.mismatched) {
        fill = ExerciseTileTokens.incorrectFill;
        border = ink = ExerciseTileTokens.incorrectInk;
        shake = math.sin(_effect.value * math.pi * 6) * 6;
      } else {
        final elapsed = _effect.value * _effect.duration!.inMilliseconds;
        final settle =
            ((elapsed - LessonMotionTokens.matchFlash.inMilliseconds) /
                    LessonMotionTokens.matchSettle.inMilliseconds)
                .clamp(0.0, 1.0);
        final eased = LessonMotionTokens.ease.transform(settle);
        fill = Color.lerp(
          MatchTileTokens.correctFill,
          MatchTileTokens.surface,
          eased,
        )!;
        border = Color.lerp(
          MatchTileTokens.correctBorder,
          MatchTileTokens.border,
          eased,
        )!;
        ink = Color.lerp(
          MatchTileTokens.correctInk,
          MatchTileTokens.border,
          eased,
        )!;
        settled = settle > 0;
      }
    } else if (selected) {
      fill = ExerciseTileTokens.selectedFill;
      border = ExerciseTileTokens.selectedBorder;
      ink = ExerciseTileTokens.selectedInk;
    }
    final command = left ? widget.onLeft : widget.onRight;
    return Transform.translate(
      offset: Offset(shake, 0),
      child: ExerciseTile(
        key: Key('match_${left ? 'left' : 'right'}_$index'),
        label: matched ? '$id, matched' : id,
        selected: selected,
        settled: settled,
        fill: fill,
        border: border,
        onTap: command == null || matched || attempt != null
            ? null
            : () => command(id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Text(
              id,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}
