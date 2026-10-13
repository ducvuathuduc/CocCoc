import 'package:flutter/material.dart';

import '../../../../core/design/reference_theme.dart';
import '../../../../core/design/reference_widgets.dart';
import '../../domain/learning_models.dart';
import '../learning_visuals.dart';
import 'lesson_exercise_colors.dart';

/// Row of [total] hearts, the first [filled] red and the rest grey
/// (reference lesson/08). Newly lost heart pops in grey when animated.
class LessonHeartsRow extends StatelessWidget {
  const LessonHeartsRow({required this.filled, required this.total, super.key});
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$filled of $total hearts',
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: i < filled
                  ? const Icon(
                      Icons.favorite_rounded,
                      key: ValueKey('heart-full'),
                      color: LessonExerciseColors.wrongBorder,
                      size: 40,
                    )
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: i == filled ? .6 : 1, end: 1),
                      duration: motionDuration(context, 360),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: const Icon(
                        Icons.favorite_rounded,
                        key: ValueKey('heart-empty'),
                        color: LessonExerciseColors.tileBorder,
                        size: 40,
                      ),
                    ),
            ),
        ],
      ),
    ),
  );
}

Future<void> _lessonSheet(
  BuildContext context, {
  required Widget child,
  bool dismissible = true,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  isDismissible: dismissible,
  enableDrag: dismissible,
  showDragHandle: true,
  barrierColor: LessonExerciseColors.barrier,
  backgroundColor: ReferenceColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: child,
    ),
  ),
);

Widget _sheetBody(
  BuildContext context, {
  required int hearts,
  required String title,
  String? body,
  required String action,
  required VoidCallback onAction,
}) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    LessonHeartsRow(filled: hearts, total: LessonState.maxHearts),
    const SizedBox(height: 28),
    Text(
      title,
      textAlign: TextAlign.center,
      style: headingStyle.copyWith(
        fontSize: 22,
        height: 1.4,
        color: LessonExerciseColors.ink,
      ),
    ),
    if (body != null) ...[
      const SizedBox(height: 10),
      Text(
        body,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17, color: LessonExerciseColors.ink),
      ),
    ],
    const SizedBox(height: 40),
    ReferenceButton(
      label: action,
      backgroundColor: LessonExerciseColors.keepGoing,
      edgeColor: LessonExerciseColors.keepGoingEdge,
      onPressed: onAction,
    ),
  ],
);

/// One-time explanation after the first heart is lost (reference lesson/08).
Future<void> showHeartsIntroSheet(
  BuildContext context, {
  required int hearts,
}) => _lessonSheet(
  context,
  child: Builder(
    builder: (sheet) => _sheetBody(
      sheet,
      hearts: hearts,
      title:
          'Each mistake costs 1 heart. You need hearts to finish a '
          'lesson!',
      action: 'KEEP GOING',
      onAction: () => Navigator.pop(sheet),
    ),
  ),
);

/// Yellow feedback panel after "CAN'T LISTEN NOW" (reference lesson/11).
class SkipListeningPanel extends StatelessWidget {
  const SkipListeningPanel({
    required this.onContinue,
    required this.onReport,
    super.key,
  });
  final VoidCallback? onContinue;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: LessonExerciseColors.skipFill,
    padding: EdgeInsets.fromLTRB(
      16,
      22,
      8,
      16 + MediaQuery.paddingOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'We’ll skip listening for '
                '${listeningSkipDuration.inMinutes} minutes.',
                style: headingStyle.copyWith(
                  color: LessonExerciseColors.skipTitle,
                  fontSize: 24,
                  height: 1.25,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Report exercise',
              onPressed: onReport,
              icon: const Icon(
                Icons.outlined_flag_rounded,
                color: LessonExerciseColors.skipTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ReferenceButton(
            label: 'CONTINUE',
            backgroundColor: LessonExerciseColors.skipButton,
            edgeColor: LessonExerciseColors.skipEdge,
            onPressed: onContinue,
          ),
        ),
      ],
    ),
  );
}
