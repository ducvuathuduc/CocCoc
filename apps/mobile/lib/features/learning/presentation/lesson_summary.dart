import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../domain/learning_models.dart';
import 'learning_visuals.dart';

class LessonSummary extends StatelessWidget {
  const LessonSummary({
    required this.receipt,
    required this.mistakeCount,
    super.key,
  });

  final SessionReceipt receipt;
  final int mistakeCount;

  @override
  Widget build(BuildContext context) {
    final perfect = receipt.accuracy == 1;
    final practice = receipt.guest || receipt.placement;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).width < 350 || textScale > 1.5;
    final stats = <Widget>[
      _SummaryStat(
        key: const Key('lesson-summary-stat-xp'),
        label: 'TOTAL XP',
        semanticLabel: 'Total XP, ${receipt.xp}',
        value: '${receipt.xp}',
        icon: Icons.bolt_rounded,
        color: LearningColors.yellow,
      ),
      _SummaryStat(
        key: const Key('lesson-summary-stat-accuracy'),
        label: 'ACCURACY',
        semanticLabel: 'Accuracy, ${(receipt.accuracy * 100).round()} percent',
        value: '${(receipt.accuracy * 100).round()}%',
        icon: Icons.track_changes_rounded,
        color: LearningColors.green,
      ),
      _SummaryStat(
        key: const Key('lesson-summary-stat-time'),
        label: 'TIME',
        semanticLabel: 'Time, ${_spokenElapsed(receipt.elapsed)}',
        value: _elapsed(receipt.elapsed),
        icon: Icons.timer_outlined,
        color: LearningColors.blue,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReferenceArt(
            perfect ? LearningArt.medalDuo : LearningArt.completed,
            width: perfect ? 245 : 245 * 404 / 545,
            height: 245,
          ),
          const SizedBox(height: 22),
          Text(
            practice
                ? 'Practice complete'
                : perfect
                ? 'Flawless'
                : 'Lesson complete!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: LearningColors.yellow,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!practice) ...[
            const SizedBox(height: 17),
            Text(
              perfect
                  ? '0 mistakes. You’re like a pristine, freshwater pearl.'
                  : _mistakeDescription(mistakeCount),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                height: 1.45,
                color: ReferenceColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 40),
          if (compact)
            Column(
              children: [
                for (var index = 0; index < stats.length; index++) ...[
                  SizedBox(width: double.infinity, child: stats[index]),
                  if (index != stats.length - 1) const SizedBox(height: 12),
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < stats.length; index++) ...[
                  Expanded(child: stats[index]),
                  if (index != stats.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.semanticLabel,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: SizedBox(
                width: double.infinity,
                height: 20 * MediaQuery.textScalerOf(context).scale(1),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 3),
              decoration: BoxDecoration(
                color: ReferenceColors.surface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: SizedBox(
                height: 24 * MediaQuery.textScalerOf(context).scale(1),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(width: 3),
                      Text(
                        value,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _mistakeDescription(int mistakeCount) {
  final count = mistakeCount < 0 ? 0 : mistakeCount;
  final noun = count == 1 ? 'mistake' : 'mistakes';
  return '$count $noun reviewed. Keep up the great work!';
}

String _elapsed(Duration elapsed) {
  final seconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

String _spokenElapsed(Duration elapsed) {
  final seconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  final parts = <String>[];
  if (hours > 0) parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
  if (minutes > 0) {
    parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
  }
  if (remainder > 0 || parts.isEmpty) {
    parts.add('$remainder ${remainder == 1 ? 'second' : 'seconds'}');
  }
  return parts.join(' ');
}
