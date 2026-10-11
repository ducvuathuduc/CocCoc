import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../../core/design/reward_motion.dart';
import '../domain/results_models.dart';
import 'results_theme.dart';

typedef MotionBuilder = Widget Function(
  BuildContext context,
  double t,
  Widget? child,
);

/// Runs one delayed, one-shot animation (0→1). With reduced motion or a
/// disabled ticker it renders the final frame immediately.
class DelayedMotion extends StatefulWidget {
  const DelayedMotion({
    required this.builder,
    this.delayMs = 0,
    this.durationMs = ResultsMotion.slide,
    this.curve = ResultsMotion.curve,
    this.child,
    super.key,
  });
  final MotionBuilder builder;
  final int delayMs;
  final int durationMs;
  final Curve curve;
  final Widget? child;

  @override
  State<DelayedMotion> createState() => _DelayedMotionState();
}

class _DelayedMotionState extends State<DelayedMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.delayMs + widget.durationMs),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delayMs / (widget.delayMs + widget.durationMs),
      1,
      curve: widget.curve,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) =>
        widget.builder(context, _animation.value, child),
  );
}

/// Staggered slide + fade entrance used by every result tile and row.
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    required this.index,
    required this.child,
    this.offset = const Offset(0, 24),
    super.key,
  });
  final int index;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) => DelayedMotion(
    delayMs: index * ResultsMotion.stagger,
    child: child,
    builder: (context, t, child) => Opacity(
      opacity: t.clamp(0, 1),
      child: Transform.translate(offset: offset * (1 - t), child: child),
    ),
  );
}

/// Pop-in with an overshoot, used for chests and hero art ("chest open bounce").
class BounceIn extends StatelessWidget {
  const BounceIn({required this.child, this.delayMs = 0, super.key});
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) => DelayedMotion(
    delayMs: delayMs,
    durationMs: ResultsMotion.chest,
    curve: Curves.elasticOut,
    child: child,
    builder: (context, t, child) => Transform.scale(
      scale: .55 + .45 * t,
      child: Transform.rotate(
        angle: math.sin(t * math.pi * 3) * .06 * (1 - t.clamp(0, 1)),
        child: child,
      ),
    ),
  );
}

/// Filled pill progress bar with count label; fills from zero on entrance.
class ResultProgressBar extends StatelessWidget {
  const ResultProgressBar({
    required this.fraction,
    required this.label,
    this.delayMs = 0,
    this.height = 25,
    super.key,
  });
  final double fraction;
  final String label;
  final int delayMs;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Progress $label',
    excludeSemantics: true,
    child: SizedBox(
      height: height,
      child: DelayedMotion(
        delayMs: delayMs,
        durationMs: ResultsMotion.fill,
        builder: (context, t, _) => LayoutBuilder(
          builder: (context, constraints) {
            final value = fraction * t;
            final width = value <= 0
                ? 0.0
                : math.max(height, constraints.maxWidth * value);
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: ResultsColors.border,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(height / 2),
                    ),
                  ),
                ),
                if (width > 0)
                  Container(
                    width: width,
                    decoration: BoxDecoration(
                      color: ResultsColors.quest,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(height / 2),
                        right: Radius.circular(
                          fraction >= 1 && t >= 1 ? 0 : height / 2,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      height * .32,
                      height * .14,
                      height * .32,
                      0,
                    ),
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: height * .17,
                      decoration: BoxDecoration(
                        color: ResultsColors.questGleam,
                        borderRadius: BorderRadius.circular(height),
                      ),
                    ),
                  ),
                Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: height * .62,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: fraction >= 1
                          ? ResultsColors.surface
                          : ResultsColors.trackText,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// One daily-quest tile: title, filling bar and its reward chest.
class QuestProgressTile extends StatelessWidget {
  const QuestProgressTile({
    required this.quest,
    required this.index,
    super.key,
  });
  final QuestProgressItem quest;
  final int index;

  ArtRegion get _chest => switch (quest.chest) {
    QuestChestState.opened => ResultsArt.questOpened,
    QuestChestState.locked => ResultsArt.questLocked,
    QuestChestState.gold => ResultsArt.questGold,
  };

  @override
  Widget build(BuildContext context) {
    final chest = _chest;
    final aspect = chest.source.height / chest.source.width;
    return StaggerIn(
      index: index,
      child: Padding(
        key: ValueKey('results-quest-${quest.id}'),
        padding: const EdgeInsets.fromLTRB(29, 20, 31, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: const TextStyle(
                      fontSize: 21.4,
                      height: 1.32,
                      fontWeight: FontWeight.w700,
                      color: ResultsColors.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ResultProgressBar(
                    fraction: quest.fraction,
                    label: '${quest.current} / ${quest.target}',
                    delayMs: 250 + index * ResultsMotion.stagger * 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            Transform.translate(
              offset: Offset(0, quest.chest == QuestChestState.opened ? 1 : 4),
              child: BounceIn(
                delayMs: quest.complete ? 250 + ResultsMotion.fill : 0,
                child: ReferenceArt(chest, width: 45, height: 45 * aspect),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// League standings row; the learner's own row slides in from the side.
class LeagueRankTile extends StatelessWidget {
  const LeagueRankTile({required this.row, required this.index, super.key});
  final LeagueRankRow row;
  final int index;

  @override
  Widget build(BuildContext context) {
    final avatar = ResultsArt.avatars[row.avatarKey];
    final muted = !row.isUser;
    final tile = Container(
      key: ValueKey('results-rank-${row.rank}'),
      color: row.isUser ? ResultsColors.userRow : null,
      constraints: const BoxConstraints(minHeight: 87),
      padding: const EdgeInsets.only(left: 14, right: 20),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${row.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: muted ? ResultsColors.muted : ResultsColors.rankInk,
              ),
            ),
          ),
          const SizedBox(width: 3),
          if (avatar != null)
            ReferenceArt(avatar, width: 74, height: 74 * 185 / 202)
          else
            Padding(
              padding: const EdgeInsets.only(right: 13),
              child: CircleAvatar(
                radius: 30.5,
                backgroundColor: row.name.length.isOdd
                    ? ResultsColors.avatarPurple
                    : ResultsColors.avatarOrange,
                child: Text(
                  row.initial ?? row.name.characters.first,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: ResultsColors.surface,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.2,
                    color: ResultsColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    ReferenceArt(
                      row.flagKey == 'fr'
                          ? ResultsArt.flagFr
                          : ResultsArt.flagUs,
                      width: 20,
                      height: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${row.streak}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: ResultsColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          RewardCount(
            value: row.xp,
            suffix: ' XP',
            style: TextStyle(
              fontSize: 22,
              color: muted ? ResultsColors.muted : ResultsColors.rankInk,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: 'Rank ${row.rank}, ${row.name}, ${row.xp} XP',
      excludeSemantics: true,
      child: StaggerIn(
        index: index,
        offset: row.isUser ? const Offset(-60, 0) : const Offset(0, 18),
        child: tile,
      ),
    );
  }
}

/// Shared primary CTA used across result screens (results/04, 11, 12).
class ResultsPrimaryButton extends StatelessWidget {
  const ResultsPrimaryButton({
    required this.label,
    required this.onPressed,
    this.content,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;

  /// Replaces the plain label (e.g. label + gem + cost).
  final Widget? content;

  @override
  Widget build(BuildContext context) => ReferenceButton(
    label: content == null ? label : '',
    leading: content,
    onPressed: onPressed,
    minHeight: 48,
    backgroundColor: ResultsColors.blue,
    edgeColor: ResultsColors.blueEdge,
    foregroundColor: ResultsColors.surface,
    textStyle: const TextStyle(fontSize: 18),
  );
}

/// Shared scaffold: scrollable body with a pinned footer CTA.
class ResultsFrame extends StatelessWidget {
  const ResultsFrame({
    required this.body,
    required this.footer,
    this.background = ResultsColors.surface,
    this.bottom = 54,
    super.key,
  });
  final Widget body;
  final Widget footer;
  final Color background;
  final double bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(child: body),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, bottom),
            child: footer,
          ),
        ],
      ),
    ),
  );
}

const resultsHeadline = TextStyle(
  fontSize: 26.8,
  height: 1.12,
  fontWeight: FontWeight.w700,
  color: ResultsColors.ink,
);

/// Flat blue link CTA ("MAYBE LATER") under a primary button.
class ResultsLinkButton extends StatelessWidget {
  const ResultsLinkButton({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    width: double.infinity,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: ResultsColors.blue,
        textStyle: const TextStyle(
          fontFamily: 'DuolingoSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
        ),
      ),
      child: Text(label),
    ),
  );
}

/// Rounded speech bubble with a tail pointing down at the illustration.
class ResultsSpeechBubble extends StatelessWidget {
  const ResultsSpeechBubble({required this.text, this.tailX = 233, super.key});
  final String text;
  final double tailX;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ResultsBubblePainter(tailX),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(17, 20, 17, 34),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 21,
          height: 1.4,
          color: ResultsColors.ink,
        ),
      ),
    ),
  );
}

class _ResultsBubblePainter extends CustomPainter {
  _ResultsBubblePainter(this.tailX);
  final double tailX;

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 14.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - tail - 2),
      const Radius.circular(16),
    );
    final path = Path()
      ..addRRect(body)
      ..moveTo(tailX - 13, body.bottom)
      ..lineTo(tailX, body.bottom + tail)
      ..lineTo(tailX + 3, body.bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = ResultsColors.surface);
    final stroke = Paint()
      ..color = ResultsColors.bubbleBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(Path()..addRRect(body), stroke);
    canvas.drawRect(
      Rect.fromLTWH(tailX - 12, body.bottom - 1.5, 14, 3),
      Paint()..color = ResultsColors.surface,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tailX - 13, body.bottom)
        ..lineTo(tailX, body.bottom + tail)
        ..lineTo(tailX + 3, body.bottom),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_ResultsBubblePainter oldDelegate) =>
      oldDelegate.tailX != tailX;
}

/// Friends-quest bar: pink fill over a slate track with a centered count.
class FriendsQuestBar extends StatelessWidget {
  const FriendsQuestBar({
    required this.fraction,
    required this.label,
    this.delayMs = 0,
    super.key,
  });
  final double fraction;
  final String label;
  final int delayMs;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Friends Quest progress $label',
    excludeSemantics: true,
    child: DelayedMotion(
      delayMs: delayMs,
      durationMs: ResultsMotion.fill,
      builder: (context, t, _) => LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: ResultsColors.questTrack,
                  borderRadius: BorderRadius.circular(h / 2),
                ),
              ),
              Container(
                width: math.max(h, constraints.maxWidth * fraction * t),
                decoration: BoxDecoration(
                  color: ResultsColors.questFill,
                  borderRadius: BorderRadius.circular(h / 2),
                ),
              ),
              Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: h * .62,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: ResultsColors.questBarText,
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
