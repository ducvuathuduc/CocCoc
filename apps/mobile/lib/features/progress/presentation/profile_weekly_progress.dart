import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_theme.dart';
import '../application/profile_weekly_progress_provider.dart';
import '../domain/profile_weekly_progress.dart';

const _ownerBlue = Color(0xFF1CB0F6);
const _ownerLine = Color(0xFF89DBF6);
const _youLine = Color(0xFFD1D0D1);

class ProfileWeeklyProgress extends ConsumerWidget {
  const ProfileWeeklyProgress({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(profileWeeklyProgressProvider(userId));
    if (progress == null) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    final chartHeight = 190.0 + math.max(0.0, scaler.scale(14) - 14) * 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Weekly progress',
          style: TextStyle(
            color: ReferenceColors.ink,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: ReferenceColors.border, width: 2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              _LegendRow(
                label: progress.owner.label,
                totalXp: progress.owner.totalXp,
                color: _ownerBlue,
                semanticsLabel:
                    '${progress.owner.label} weekly progress, ${progress.owner.totalXp} XP',
              ),
              const SizedBox(height: 4),
              _LegendRow(
                label: 'You',
                totalXp: progress.you.totalXp,
                color: ReferenceColors.disabled,
                semanticsLabel:
                    'You weekly progress, ${progress.you.totalXp} XP',
              ),
              const SizedBox(height: 8),
              Semantics(
                label: _chartSemantics(progress),
                image: true,
                excludeSemantics: true,
                child: SizedBox(
                  height: chartHeight,
                  width: double.infinity,
                  child: CustomPaint(
                    key: const ValueKey('profile-weekly-chart'),
                    painter: _WeeklyProgressPainter(
                      progress: progress,
                      textScaler: scaler,
                      textDirection: Directionality.of(context),
                      textStyle: DefaultTextStyle.of(context).style,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.totalXp,
    required this.color,
    required this.semanticsLabel,
  });

  final String label;
  final int totalXp;
  final Color color;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(18) > 27;
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
    final totalWidget = Text(
      '$totalXp XP',
      style: TextStyle(
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    );
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labelWidget,
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: totalWidget),
              ],
            )
          : Row(
              children: [
                Expanded(child: labelWidget),
                const SizedBox(width: 8),
                totalWidget,
              ],
            ),
    );
  }
}

String _chartSemantics(ProfileWeeklyProgressData progress) {
  String series(WeeklyXpSeries value) => List.generate(
    weeklyDayNames.length,
    (index) => '${weeklyDayNames[index]} ${value.points[index]} XP',
  ).join(', ');
  return 'Weekly XP chart. ${progress.owner.label}: ${series(progress.owner)}. '
      'You: ${series(progress.you)}.';
}

class _WeeklyProgressPainter extends CustomPainter {
  const _WeeklyProgressPainter({
    required this.progress,
    required this.textScaler,
    required this.textDirection,
    required this.textStyle,
  });

  final ProfileWeeklyProgressData progress;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final TextStyle textStyle;

  TextPainter _text(String value, {required double fontSize}) => TextPainter(
    text: TextSpan(
      text: value,
      style: textStyle.copyWith(
        color: ReferenceColors.disabled,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final tickPainters = [
      for (final tick in progress.axisTicks) _text('$tick', fontSize: 14),
    ];
    final dayPainters = [
      for (final day in weeklyDayLabels) _text(day, fontSize: 14),
    ];
    final left =
        tickPainters.fold<double>(
          0,
          (width, painter) => math.max(width, painter.width),
        ) +
        10;
    final bottom =
        dayPainters.fold<double>(
          0,
          (height, painter) => math.max(height, painter.height),
        ) +
        8;
    final plot = Rect.fromLTRB(
      left,
      6,
      size.width - dayPainters.last.width / 2 - 2,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = ReferenceColors.border
      ..strokeWidth = 2;
    for (var index = 0; index < progress.axisTicks.length; index++) {
      final y = plot.bottom - plot.height * index / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final label = tickPainters[index];
      label.paint(
        canvas,
        Offset(plot.left - label.width - 8, y - label.height / 2),
      );
    }
    for (var index = 0; index < dayPainters.length; index++) {
      final x = plot.left + plot.width * index / 6;
      final label = dayPainters[index];
      label.paint(canvas, Offset(x - label.width / 2, plot.bottom + 8));
    }
    _paintSeries(
      canvas,
      plot,
      progress.you.points,
      _youLine,
      ReferenceColors.disabled,
    );
    _paintSeries(canvas, plot, progress.owner.points, _ownerLine, _ownerBlue);
  }

  void _paintSeries(
    Canvas canvas,
    Rect plot,
    List<int> points,
    Color lineColor,
    Color pointColor,
  ) {
    final path = Path();
    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = plot.left + plot.width * index / 6;
      final ratio = progress.axisMaximum == 0
          ? 0.0
          : (points[index] / progress.axisMaximum).clamp(0.0, 1.0);
      final point = Offset(x, plot.bottom - plot.height * ratio);
      offsets.add(point);
      index == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final pointPaint = Paint()..color = pointColor;
    for (final point in offsets) {
      canvas.drawCircle(point, 6, pointPaint);
    }
  }

  @override
  bool shouldRepaint(_WeeklyProgressPainter oldDelegate) =>
      oldDelegate.textScaler != textScaler ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textStyle != textStyle ||
      !listEquals(oldDelegate.progress.owner.points, progress.owner.points) ||
      !listEquals(oldDelegate.progress.you.points, progress.you.points) ||
      !listEquals(oldDelegate.progress.axisTicks, progress.axisTicks) ||
      oldDelegate.progress.owner.label != progress.owner.label;
}
