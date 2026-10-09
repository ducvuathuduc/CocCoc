import 'package:flutter/material.dart';

import '../../../core/design/character_motion.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../domain/learning_models.dart';
import 'learning_visuals.dart';

const lessonLilyArt = ArtRegion(
  'lesson-lily-source',
  Rect.fromLTWH(426, 930, 330, 690),
);

/// Presentation only: media availability and grading stay with the lesson owner.
class LilyDialogueExercise extends StatelessWidget {
  const LilyDialogueExercise({
    required this.exercise,
    required this.state,
    required this.textController,
    required this.onChanged,
    required this.onListen,
    required this.availableHeight,
    super.key,
  });
  final Exercise exercise;
  final LessonState state;
  final TextEditingController textController;
  final ValueChanged<String> onChanged;
  final VoidCallback? onListen;
  final double availableHeight;

  @override
  Widget build(BuildContext context) {
    final reaction = state.stage != LessonStage.feedback
        ? CharacterReaction.reset
        : state.correct == true
        ? CharacterReaction.correct
        : CharacterReaction.incorrect;
    final editable = state.stage == LessonStage.answering && !state.busy;
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          SizedBox(
            height: state.textAlternative
                ? 8
                : (availableHeight * .16).clamp(24, 90),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: _LilySpeechBubble(
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Listen to Lily',
                    onPressed: onListen,
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      color: LearningColors.blue,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.prompt,
                      style: const TextStyle(
                        fontSize: 20,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: ReferenceColors.disabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          CharacterMotion(
            character: LessonCharacter.lily,
            contentScale: 2,
            contentAlignment: const Alignment(0, .19),
            epoch: '${exercise.id}:${state.retryPass}',
            reaction: reaction,
            width: 112,
            height: 234,
            fallback: const ReferenceArt(
              lessonLilyArt,
              width: 112,
              height: 234,
            ),
          ),
          if (state.textAlternative) ...[
            const SizedBox(height: 20),
            TextField(
              controller: textController,
              readOnly: !editable,
              onChanged: onChanged,
              maxLength: 512,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                hintText: 'Reply in English',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SpeakingWordsExercise extends StatelessWidget {
  const SpeakingWordsExercise({
    required this.prompt,
    required this.onSpeak,
    required this.availableHeight,
    super.key,
  });
  final String prompt;
  final VoidCallback? onSpeak;
  final double availableHeight;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(height: (availableHeight * .12).clamp(24, 70)),
      Center(
        child: SizedBox(
          width: 276,
          child: Stack(
            children: [
              for (final offset in [0.0, 8.0, 16.0])
                Padding(
                  padding: EdgeInsets.only(
                    left: offset / 2,
                    right: offset / 2,
                    top: offset,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 225),
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 45,
                    ),
                    decoration: BoxDecoration(
                      color: ReferenceColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ReferenceColors.border,
                        width: 2,
                      ),
                    ),
                    child: offset == 16
                        ? Text(
                            prompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 27),
      Center(
        child: SizedBox(
          width: 220,
          child: Tooltip(
            message: 'Speak the sentence',
            child: ReferenceButton(
              label: '',
              backgroundColor: LearningColors.blue,
              edgeColor: LearningColors.blueDark,
              onPressed: onSpeak,
              minHeight: 90,
              leading: const Icon(
                Icons.graphic_eq_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _LilySpeechBubble extends StatelessWidget {
  const _LilySpeechBubble({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LilyBubblePainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 22),
      child: child,
    ),
  );
}

class _LilyBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - 12;
    final fill = Paint()..color = ReferenceColors.surface;
    final stroke = Paint()
      ..color = ReferenceColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final bounds = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, bottom),
      const Radius.circular(20),
    );
    canvas.drawRRect(bounds, fill);
    canvas.drawRRect(bounds, stroke);
    final anchor = size.width * .32;
    final tail = Path()
      ..moveTo(anchor - 12, bottom - 1)
      ..lineTo(anchor + 6, size.height)
      ..quadraticBezierTo(
        anchor + 9,
        size.height + 1,
        anchor + 9,
        size.height - 3,
      )
      ..lineTo(anchor + 10, bottom - 1);
    canvas.drawPath(tail, fill);
    canvas.drawPath(tail, stroke);
    canvas.drawLine(
      Offset(anchor - 11, bottom),
      Offset(anchor + 9, bottom),
      Paint()
        ..color = ReferenceColors.surface
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_LilyBubblePainter oldDelegate) => false;
}
