import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../domain/quest_models.dart';
import 'quest_art.dart';

/// Daily-quest chest opening (audit row 17, Gummble "Claiming a reward").
///
/// Motion follows Duolingo's chest claim: the chest pops in, wiggles three
/// times, the lid bursts off with a flash and turning light rays, then the
/// gems rise out of the chest and the reward line and CONTINUE fade in.
/// The Android capture of this flow is not cached, so timings are authored
/// ([ChestOpeningMotion]); art is the existing quests-06 chest crop and gem.
Future<void> showChestOpening(
  BuildContext context, {
  required QuestChestType type,
  required int gems,
  ChestRewardCopy copy = const ChestRewardCopy(),
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: ReferenceColors.surface,
    transitionDuration: reduced
        ? Duration.zero
        : const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => ChestOpening(type: type, gems: gems, copy: copy),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

abstract final class ChestOpeningMotion {
  static const total = Duration(milliseconds: 1800);
  // Fractions of [total].
  static const popEnd = .17; // 300 ms pop-in, easeOutBack
  static const wiggleEnd = .5; // 3 wiggles, decaying ±0.14 rad
  static const burstEnd = .64; // lid off + flash
  static const gemsEnd = .86; // gems rise, easeOutBack
  static const raysTurn = Duration(seconds: 8); // one ray revolution
}

class ChestOpening extends StatefulWidget {
  const ChestOpening({
    required this.type,
    required this.gems,
    this.copy = const ChestRewardCopy(),
    super.key,
  });
  final QuestChestType type;
  final int gems;
  final ChestRewardCopy copy;
  @override
  State<ChestOpening> createState() => _ChestOpeningState();
}

class _ChestOpeningState extends State<ChestOpening>
    with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: ChestOpeningMotion.total,
  );
  late final AnimationController _rays = AnimationController(
    vsync: this,
    duration: ChestOpeningMotion.raysTurn,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _open.value = 1;
    } else {
      _open.forward();
      // One slow revolution, then the rays rest (keeps the page settleable).
      _rays.forward();
    }
  }

  @override
  void dispose() {
    _open.dispose();
    _rays.dispose();
    super.dispose();
  }

  ArtRegion get _art => switch (widget.type) {
    QuestChestType.bronze => QuestArt.chestBronze,
    QuestChestType.silver => QuestArt.chestSilver,
    QuestChestType.gold => QuestArt.chestGold,
  };

  double _phase(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final art = _art;
    const chestWidth = 170.0;
    final chestHeight = chestWidth * art.source.height / art.source.width;
    return Scaffold(
      key: const ValueKey('chest-opening'),
      backgroundColor: ReferenceColors.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_open, _rays]),
          builder: (context, _) {
            final t = _open.value;
            final pop = Curves.easeOutBack.transform(
              _phase(t, 0, ChestOpeningMotion.popEnd),
            );
            final w = _phase(
              t,
              ChestOpeningMotion.popEnd,
              ChestOpeningMotion.wiggleEnd,
            );
            final wiggle = math.sin(w * math.pi * 6) * .14 * (1 - w);
            final burst = Curves.easeOutCubic.transform(
              _phase(
                t,
                ChestOpeningMotion.wiggleEnd,
                ChestOpeningMotion.burstEnd,
              ),
            );
            final rise = Curves.easeOutBack.transform(
              _phase(
                t,
                ChestOpeningMotion.burstEnd - .04,
                ChestOpeningMotion.gemsEnd,
              ),
            );
            final copy = _phase(t, ChestOpeningMotion.gemsEnd - .06, 1);
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      height: 340,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Turning light rays behind the open chest.
                          Opacity(
                            opacity: burst * .9,
                            child: Transform.rotate(
                              angle: _rays.value * 2 * math.pi,
                              child: const CustomPaint(
                                size: Size(320, 320),
                                painter: _RaysPainter(),
                              ),
                            ),
                          ),
                          // Flash when the lid bursts.
                          if (burst > 0 && burst < 1)
                            Opacity(
                              opacity: (1 - burst) * .7,
                              child: Container(
                                width: 80 + 220 * burst,
                                height: 80 + 220 * burst,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: LearningColors.yellow,
                                ),
                              ),
                            ),
                          // Gems rise out of the chest.
                          Transform.translate(
                            offset: Offset(0, 30 - 120 * rise),
                            child: Transform.scale(
                              scale: rise,
                              child: const _KnockOutWhite(
                                child: ReferenceArt(
                                  LearningArt.gem,
                                  width: 54,
                                  height: 64,
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, 60),
                            child: Transform.rotate(
                              angle: wiggle,
                              alignment: Alignment.bottomCenter,
                              child: Transform.scale(
                                scale: .4 + .6 * pop,
                                child: _SplitChest(
                                  art: art,
                                  width: chestWidth,
                                  height: chestHeight,
                                  lid: burst,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: copy,
                  child: Column(
                    children: [
                      Text(
                        widget.copy.amount(widget.gems),
                        key: const ValueKey('chest-gems'),
                        style: headingStyle.copyWith(
                          color: LearningColors.blue,
                          fontSize: 34,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          widget.copy.earned(widget.gems),
                          textAlign: TextAlign.center,
                          style: headingStyle.copyWith(fontSize: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  child: IgnorePointer(
                    ignoring: copy < 1,
                    child: Opacity(
                      opacity: copy,
                      child: ReferenceButton(
                        label: widget.copy.continueAction,
                        backgroundColor: LearningColors.blue,
                        edgeColor: LearningColors.blueDark,
                        onPressed: () => Navigator.pop(context),
                      ),
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
}

/// The chest crop split at its lid line: the lid flies up and tips back as
/// [lid] goes 0→1 while the base stays put.
class _SplitChest extends StatelessWidget {
  const _SplitChest({
    required this.art,
    required this.width,
    required this.height,
    required this.lid,
  });
  final ArtRegion art;
  final double width, height, lid;
  static const split = .42;
  @override
  Widget build(BuildContext context) {
    final image = _KnockOutWhite(
      child: ReferenceArt(art, width: width, height: height),
    );
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRect(clipper: const _Band(split, 1), child: image),
          Transform.translate(
            offset: Offset(18 * lid, -70 * lid),
            child: Transform.rotate(
              angle: .5 * lid,
              child: Opacity(
                opacity: 1 - lid * .5,
                child: ClipRect(clipper: const _Band(0, split), child: image),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The crops sit on white; alpha = 10·(A − R) keeps the chest's light metal
/// (R 229) opaque and drops white, so the rays show around the chest rather
/// than behind a white box. The silver crop's #FAF8FC tile edge stays faint.
class _KnockOutWhite extends StatelessWidget {
  const _KnockOutWhite({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: const ColorFilter.matrix([
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      // alpha' = 10·(A − R): transparent stays transparent, white → 0.
      -10, 0, 0, 10, 0, //
    ]),
    child: child,
  );
}

class _Band extends CustomClipper<Rect> {
  const _Band(this.from, this.to);
  final double from, to;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, size.height * from, size.width, size.height * to);
  @override
  bool shouldReclip(_Band oldClipper) =>
      oldClipper.from != from || oldClipper.to != to;
}

class _RaysPainter extends CustomPainter {
  const _RaysPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          LearningColors.yellow.withValues(alpha: .45),
          LearningColors.yellow.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * math.cos(a - .12),
          center.dy + radius * math.sin(a - .12),
        )
        ..lineTo(
          center.dx + radius * math.cos(a + .12),
          center.dy + radius * math.sin(a + .12),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}
