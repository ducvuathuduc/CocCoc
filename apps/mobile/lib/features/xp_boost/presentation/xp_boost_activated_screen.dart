import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../shop/presentation/shop_visuals.dart';
import '../application/boost_controller.dart';
import '../domain/boost.dart';

abstract final class _BoostColors {
  // xp_boost_activated.png sampled at (10,200), (10,800), (10,2200).
  static const top = Color(0xFF8251C5);
  static const middle = Color(0xFF8856CA);
  static const bottom = Color(0xFF5F36A9);
  // Rim/button edge (530,750), nearest reference palette sample (delta 1).
  static const edge = Color(0xFFECCFFF);
  // Continue ink sampled at (482,2340); palette #9460D2 (delta <= 2).
  static const buttonInk = Color(0xFF9460D2);
}

class XpBoostActivatedScreen extends ConsumerWidget {
  const XpBoostActivatedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boostControllerProvider);
    final copy = ref.watch(boostCopyProvider);
    final boost = state.value;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _BoostColors.top,
              _BoostColors.middle,
              _BoostColors.bottom,
            ],
            stops: [0, .4, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: BoostBubbles(moving: !reduced)),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final factor = MediaQuery.sizeOf(context).width / 393;
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: boost == null
                                ? Center(
                                    child: state.isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : Text(
                                            copy.emptyMessage,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                  )
                                : _celebration(context, boost, factor, reduced),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      20,
                      16,
                      10 * MediaQuery.sizeOf(context).width / 393,
                    ),
                    child: ReferenceButton(
                      label: boost?.continueLabel ?? copy.continueLabel,
                      backgroundColor: Colors.white,
                      edgeColor: _BoostColors.edge,
                      foregroundColor: _BoostColors.buttonInk,
                      minHeight: 48,
                      cornerRadius: 14,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _celebration(
    BuildContext context,
    Boost boost,
    double factor,
    bool reduced,
  ) => Padding(
    padding: EdgeInsets.fromLTRB(16 * factor, 165 * factor, 16 * factor, 24),
    child: Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: reduced ? 1 : .7, end: 1),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Align(
            heightFactor: .82,
            child: ClipPath(
              clipper: _FlaskClipper(),
              child: ReferenceArt(
                ShopArt.xpBoost,
                width: 169 * factor,
                height: 196 * factor,
              ),
            ),
          ),
        ),
        SizedBox(height: 12 * factor),
        Text(
          boost.multiplierLabel,
          style: TextStyle(
            fontSize: 60 * factor,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        SizedBox(height: 37 * factor),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: boost.message),
              TextSpan(
                text: boost.durationLabel,
                style: const TextStyle(color: LearningColors.yellow),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24 * factor,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

// Silhouette around the existing shop-02 flask: removes white backing and the
// ground shadow without adding assets. Coordinates are relative to ShopArt.xpBoost.
class _FlaskClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(69, 12)
      ..lineTo(110, 12)
      ..quadraticBezierTo(119, 13, 115, 30)
      ..lineTo(120, 32)
      ..quadraticBezierTo(127, 35, 122, 54)
      ..lineTo(110, 60)
      ..lineTo(110, 80)
      ..lineTo(149, 143)
      ..quadraticBezierTo(163, 179, 126, 190)
      ..lineTo(59, 190)
      ..quadraticBezierTo(18, 178, 32, 144)
      ..lineTo(70, 79)
      ..lineTo(70, 61)
      ..lineTo(58, 55)
      ..lineTo(58, 34)
      ..lineTo(69, 30)
      ..close();
    return path.transform(
      Matrix4.diagonal3Values(size.width / 180, size.height / 232, 1).storage,
    );
  }

  @override
  bool shouldReclip(_FlaskClipper oldClipper) => false;
}

class BoostBubbles extends StatefulWidget {
  const BoostBubbles({required this.moving, super.key});
  final bool moving;
  @override
  State<BoostBubbles> createState() => _BoostBubblesState();
}

class _BoostBubblesState extends State<BoostBubbles>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void didUpdateWidget(BoostBubbles oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.moving && _foreground) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      if (!widget.moving) _controller.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(painter: _BubblePainter(_controller)),
    ),
  );
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    const bubbles = [
      (.53, .09, .10),
      (.08, .37, .14),
      (.97, .33, .045),
      (-.06, .62, .10),
      (1.08, .82, .14),
      (.58, .96, .20),
    ];
    for (var i = 0; i < bubbles.length; i++) {
      final (x, y, radius) = bubbles[i];
      final drift =
          math.sin(animation.value * math.pi * 2 + i) * size.height * .025;
      final center = Offset(x * size.width, y * size.height - drift);
      final r = radius * size.width;
      canvas.drawCircle(
        center,
        r,
        Paint()..color = Colors.white.withValues(alpha: .08),
      );
      canvas.drawCircle(
        center,
        r * .82,
        Paint()..color = Colors.white.withValues(alpha: .04),
      );
      canvas.drawCircle(
        center + Offset(r * .28, -r * .25),
        r * .28,
        Paint()..color = Colors.white.withValues(alpha: .14),
      );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) =>
      oldDelegate.animation != animation;
}
