import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reward_motion.dart';
import '../application/completion_providers.dart';
import '../domain/learning_models.dart';
import 'completion_colors.dart';
import 'learning_visuals.dart';

class LessonSummary extends ConsumerWidget {
  const LessonSummary({
    required this.receipt,
    required this.mistakeCount,
    super.key,
  });

  final SessionReceipt receipt;
  final int mistakeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(
      completionSummaryProvider((receipt, mistakeCount)),
    );
    final perfect = content.perfect;
    final scale = (MediaQuery.sizeOf(context).width / 390).clamp(.8, 430 / 390);
    final sourceScale = scale * 390 / 1180;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).width < 350 || textScale > 1.5;
    final stats = <Widget>[
      _SummaryStat(
        key: const Key('lesson-summary-stat-xp'),
        label: content.xp.label,
        semanticLabel: content.xp.semanticLabel,
        value: content.xp.value,
        animatedValue: content.xp.animatedValue,
        suffix: content.xp.suffix,
        icon: const ArtRegion('results-02', Rect.fromLTWH(165, 1917, 64, 73)),
        scale: scale,
        color: CompletionColors.xp,
      ),
      _SummaryStat(
        key: const Key('lesson-summary-stat-accuracy'),
        label: content.accuracy.label,
        semanticLabel: content.accuracy.semanticLabel,
        value: content.accuracy.value,
        animatedValue: content.accuracy.animatedValue,
        suffix: content.accuracy.suffix,
        icon: const ArtRegion('results-02', Rect.fromLTWH(478, 1916, 70, 73)),
        scale: scale,
        color: ReferenceColors.green,
        gleam: true,
      ),
      _SummaryStat(
        key: const Key('lesson-summary-stat-time'),
        label: content.time.label,
        semanticLabel: content.time.semanticLabel,
        value: content.time.value,
        animatedValue: content.time.animatedValue,
        suffix: content.time.suffix,
        icon: const ArtRegion('results-02', Rect.fromLTWH(838, 1917, 73, 72)),
        scale: scale,
        color: CompletionColors.blue,
      ),
    ];

    return LessonCelebration(
      key: ValueKey(receipt.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(
                perfect ? 5 * sourceScale : 0,
                perfect ? -2 * scale : 0,
              ),
              child: ReferenceArt(
                perfect ? LearningArt.medalDuo : LearningArt.completed,
                width: perfect ? 772 * sourceScale : 245 * 404 / 545,
                height: perfect ? 771 * sourceScale : 245,
              ),
            ),
            SizedBox(height: 22 * scale),
            Transform.translate(
              offset: const Offset(2, 1),
              child: Text(
                content.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CompletionColors.xp,
                  fontSize: 32 * scale,
                  letterSpacing: .6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (content.description != null) ...[
              SizedBox(height: 11.5 * scale),
              Transform.translate(
                offset: const Offset(3, -1),
                child: Text(
                  content.description!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20 * scale,
                    letterSpacing: .95,
                    height: 1.5,
                    color: ReferenceColors.muted,
                  ),
                ),
              ),
            ],
            SizedBox(height: 44 * scale),
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
                    if (index != stats.length - 1)
                      SizedBox(width: 52 * sourceScale),
                  ],
                ],
              ),
          ],
        ),
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
    required this.scale,
    required this.color,
    this.animatedValue,
    this.suffix = '',
    this.gleam = false,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final String value;
  final ArtRegion icon;
  final double scale;
  final Color color;
  final int? animatedValue;
  final String suffix;
  final bool gleam;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: gleam ? const _StatGleam() : null,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 1.5 * scale,
                  horizontal: 2,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height:
                      16 * scale * MediaQuery.textScalerOf(context).scale(1),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13 * scale,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: 17.5 * scale,
                horizontal: 3,
              ),
              decoration: BoxDecoration(
                color: ReferenceColors.surface,
                borderRadius: BorderRadius.circular(13 * scale),
              ),
              child: SizedBox(
                height: 24 * scale * MediaQuery.textScalerOf(context).scale(1),
                child: Transform.translate(
                  offset: Offset(0, -2 * scale),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReferenceArt(
                          icon,
                          width:
                              22 *
                              scale *
                              icon.source.width /
                              icon.source.height,
                          height: 22 * scale,
                        ),
                        const SizedBox(width: 3),
                        if (animatedValue != null)
                          RewardCount(
                            value: animatedValue!,
                            suffix: suffix,
                            style: TextStyle(
                              color: color,
                              fontSize: 20 * scale,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          Text(
                            value,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: 20 * scale,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
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

class _StatGleam extends CustomPainter {
  const _StatGleam();

  @override
  void paint(Canvas canvas, Size size) {
    // results/02: header x440..738; bands at y1806 are x523..559,
    // x578..642 and x664..700. At y1858 each shifts 42px left.
    for (final stripe in [
      (83 / 298, 120 / 298, .3),
      (138 / 298, 203 / 298, .2),
      (224 / 298, 261 / 298, .3),
    ]) {
      final paint = Paint()
        ..color = ReferenceColors.surface.withValues(alpha: stripe.$3);
      canvas.drawPath(
        Path()
          ..moveTo(size.width * stripe.$1, 0)
          ..lineTo(size.width * stripe.$2, 0)
          ..lineTo(size.width * (stripe.$2 - 48 / 298), size.height)
          ..lineTo(size.width * (stripe.$1 - 48 / 298), size.height)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StatGleam oldDelegate) => false;
}
