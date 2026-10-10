import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../domain/learning_models.dart';
import 'learning_visuals.dart';

class ImageChoiceExercise extends StatelessWidget {
  const ImageChoiceExercise({
    required this.exercise,
    required this.state,
    required this.availableHeight,
    required this.onSelect,
    required this.audio,
    super.key,
  });
  final Exercise exercise;
  final LessonState state;
  final double availableHeight;
  final ValueChanged<String>? onSelect;
  final Widget audio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          audio,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              exercise.prompt,
              style: const TextStyle(
                color: LearningColors.purple,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dashed,
                decorationColor: LearningColors.purple,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: ImageChoiceGeometry.gap,
          runSpacing: ImageChoiceGeometry.gap,
          children: [
            for (var i = 0; i < exercise.choices.length; i++)
              _choice(
                exercise.choices[i],
                i,
                (constraints.maxWidth - ImageChoiceGeometry.gap) / 2,
              ),
          ],
        ),
      ),
    ],
  );

  Widget _choice(ExerciseChoice option, int index, double width) {
    final selected = state.selectedId == option.id;
    final graded = selected && state.stage == LessonStage.feedback;
    final fill = !selected
        ? ExerciseTileTokens.surface
        : graded
        ? state.correct == true
              ? ExerciseTileTokens.correctFill
              : ExerciseTileTokens.incorrectFill
        : ExerciseTileTokens.selectedFill;
    final ink = !selected
        ? ExerciseTileTokens.ink
        : graded
        ? state.correct == true
              ? ExerciseTileTokens.correctInk
              : ExerciseTileTokens.incorrectInk
        : ExerciseTileTokens.selectedInk;
    final artHeight = width * ImageChoiceGeometry.artHeightRatio;
    final border = !selected
        ? ExerciseTileTokens.border
        : graded
        ? state.correct == true
              ? ExerciseTileTokens.correctBorder
              : ExerciseTileTokens.incorrectInk
        : ExerciseTileTokens.selectedBorder;
    // Reuse the existing state-specific source art. Its background matches the
    // source fill, avoiding an opaque white crop on selected/correct cards.
    final art = option.art == 'woman'
        ? ArtRegion(
            graded && state.correct == true
                ? 'lesson-06'
                : selected && !graded
                ? 'lesson-05'
                : 'lesson-03',
            selected && (!graded || state.correct == true)
                ? const Rect.fromLTWH(125, 896, 355, 389)
                : const Rect.fromLTWH(700, 1624, 355, 388),
          )
        : option.art == 'girl'
        ? const ArtRegion('lesson-03', Rect.fromLTWH(672, 887, 411, 416))
        : LearningArt.character(option.art);
    final factor = width / ImageChoiceGeometry.sourceCardWidth;
    return SizedBox(
      width: width,
      child: ExerciseTile(
        key: Key('image_choice_card_$index'),
        label: option.text,
        selected: selected,
        fill: fill,
        border: border,
        radius: 16,
        onTap: onSelect == null ? null : () => onSelect!(option.id),
        padding: const EdgeInsets.fromLTRB(12, 17, 12, 13),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    width * ImageChoiceGeometry.cardAspect -
                    ExerciseTileTokens.edge -
                    30,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    height: artHeight,
                    child: Center(
                      child: ReferenceArt(
                        art,
                        width: art.source.width * factor,
                        height: art.source.height * factor,
                      ),
                    ),
                  ),
                  Text(
                    option.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, color: ink),
                  ),
                ],
              ),
            ),
            if (graded && state.correct == true)
              PositionedDirectional(
                end: 0,
                top: 0,
                child: Icon(Icons.auto_awesome, color: ink, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
