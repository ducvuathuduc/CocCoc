import 'package:flutter/material.dart';

import '../../domain/learning_models.dart';
import '../learning_visuals.dart';
import '../widgets/lesson_choice_tile.dart';
import '../widgets/lesson_exercise_colors.dart';

/// "Tap the matching pairs" (reference lesson/10). Left column is text or,
/// for [Exercise.audioPairs], an audio clip; right column order comes from
/// [Exercise.tokens] when present.
///
/// Motion: correct pair flashes green then fades to disabled; a wrong pair
/// flashes red and shakes. Reduced motion jumps to the end state.
class MatchPairsExercise extends StatefulWidget {
  const MatchPairsExercise({
    required this.exercise,
    required this.matched,
    required this.selectedLeft,
    required this.editable,
    required this.onLeft,
    required this.onRight,
    super.key,
  });

  final Exercise exercise;
  final Map<String, String> matched;
  final String? selectedLeft;
  final bool editable;
  final ValueChanged<String> onLeft;
  final ValueChanged<String> onRight;

  @override
  State<MatchPairsExercise> createState() => _MatchPairsExerciseState();
}

class _MatchPairsExerciseState extends State<MatchPairsExercise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addStatusListener(_onFlashDone);
  String? _flashLeft, _flashRight;
  bool _flashCorrect = false;
  int _shakeEpoch = 0;

  void _onFlashDone(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _flashLeft = _flashRight = null);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  void _tapRight(String value) {
    final left = widget.selectedLeft;
    if (left != null && !MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _flashLeft = left;
        _flashRight = value;
        _flashCorrect = widget.exercise.pairs[left] == value;
        if (!_flashCorrect) _shakeEpoch += 1;
      });
      _flash.forward(from: 0);
    }
    widget.onRight(value);
  }

  ChoiceTileTone _tone({
    required bool matched,
    required bool selected,
    required bool flashing,
  }) {
    if (flashing) {
      return _flashCorrect ? ChoiceTileTone.correct : ChoiceTileTone.wrong;
    }
    if (matched) return ChoiceTileTone.disabled;
    return selected ? ChoiceTileTone.selected : ChoiceTileTone.idle;
  }

  Widget _faded({required bool matched, required Widget child}) =>
      AnimatedOpacity(
        duration: motionDuration(context, 220),
        opacity: matched && _flashLeft == null ? .5 : 1,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final lefts = exercise.pairs.keys.toList();
    final rights = exercise.tokens.isNotEmpty
        ? exercise.tokens.map((t) => t.id).toList()
        : exercise.pairs.values.toList();
    final rows = lefts.length > rights.length ? lefts.length : rights.length;
    return Column(
      children: [
        const SizedBox(height: 90),
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: i < lefts.length
                      ? _leftTile(lefts[i], i)
                      : const SizedBox(),
                ),
                const SizedBox(width: 27),
                Expanded(
                  child: i < rights.length
                      ? _rightTile(rights[i])
                      : const SizedBox(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _leftTile(String key, int index) {
    final matched = widget.matched.containsKey(key);
    final flashing = _flashLeft == key;
    final tone = _tone(
      matched: matched,
      selected: widget.selectedLeft == key,
      flashing: flashing,
    );
    final audio = widget.exercise.audioPairs;
    return _faded(
      matched: matched,
      child: LessonChoiceTile(
        key: ValueKey('pair-left-$key'),
        tone: tone,
        selected: widget.selectedLeft == key,
        shakeEpoch: flashing && !_flashCorrect ? _shakeEpoch : 0,
        semanticLabel: audio ? 'Audio clip ${index + 1}' : null,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onTap: widget.editable && !matched ? () => widget.onLeft(key) : null,
        child: SizedBox(
          height: 70,
          child: Center(
            child: audio
                ? _AudioWave(seed: key, tone: tone)
                : _label(key, tone),
          ),
        ),
      ),
    );
  }

  Widget _rightTile(String value) {
    final matched = widget.matched.containsValue(value);
    final flashing = _flashRight == value;
    final tone = _tone(matched: matched, selected: false, flashing: flashing);
    return _faded(
      matched: matched,
      child: LessonChoiceTile(
        key: ValueKey('pair-right-$value'),
        tone: tone,
        shakeEpoch: flashing && !_flashCorrect ? _shakeEpoch : 0,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onTap: widget.editable && !matched ? () => _tapRight(value) : null,
        child: SizedBox(height: 70, child: Center(child: _label(value, tone))),
      ),
    );
  }

  Widget _label(String text, ChoiceTileTone tone) => Text(
    text,
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 20, color: _textColor(tone)),
  );
}

Color _textColor(ChoiceTileTone tone) => switch (tone) {
  ChoiceTileTone.selected => LessonExerciseColors.audioBlue,
  ChoiceTileTone.correct => LessonExerciseColors.matchedText,
  ChoiceTileTone.wrong => LessonExerciseColors.wrongText,
  ChoiceTileTone.disabled => LessonExerciseColors.disabledText,
  ChoiceTileTone.idle => LessonExerciseColors.ink,
};

/// Speaker + deterministic waveform bars (graphic only, no answer text).
class _AudioWave extends StatelessWidget {
  const _AudioWave({required this.seed, required this.tone});
  final String seed;
  final ChoiceTileTone tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == ChoiceTileTone.idle || tone == ChoiceTileTone.selected
        ? LessonExerciseColors.audioBlue
        : _textColor(tone);
    final hash = seed.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xffff);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.volume_up_rounded, color: color, size: 26),
        const SizedBox(width: 10),
        for (var i = 0; i < _bars; i++)
          Container(
            width: 2.5,
            height: _barHeight(i, hash),
            margin: const EdgeInsets.symmetric(horizontal: 1.6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }

  static const _bars = 15;

  static double _barHeight(int i, int hash) {
    const mid = (_bars - 1) / 2;
    final center = 1 - (i - mid).abs() / mid; // 0 at edges, 1 in the middle
    if (center < .2) return 2.5; // dotted tail like lesson/10
    final jitter = ((hash * (i + 3)) >> 3 & 7) / 7;
    return 6 + center * 14 + jitter * 12;
  }
}
