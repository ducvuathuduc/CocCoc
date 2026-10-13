import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';

abstract final class HeartsColors {
  // earn_heart_09 page sample (20,1500): pure white, so the heart crop has no box.
  static const page = Color(0xFFFFFFFF);
  // sc_1ae5ddcf 0-hearts pill heart and count (#E5E5E5).
  static const emptyInk = Color(0xFFE5E5E5);
}

/// Super trial colours sampled from sc_1ae5ddcf / sc_fb07ca98 (snapped to the
/// nearest palette_from_refs entries; no new colours).
abstract final class SuperColors {
  // Card/heart gradient: mint top-left (20,100 ≈ #26E280), blue lower-left
  // (20,700 #288BFC), magenta right edge (540,400 #FB55FF).
  static const green = Color(0xFF2EE79F);
  static const blue = Color(0xFF3881FE);
  static const magenta = Color(0xFFFB55FF);
  // "FREE TRIAL" text (#E71BE0 in sc_1ae5ddcf).
  static const trialInk = Color(0xFFFE00EE);
  static const gradient = [green, blue, magenta];
  static const header = LinearGradient(colors: gradient, stops: [0, .45, 1]);
  // Selected border: left edge runs mint→blue top to bottom, right edge stays
  // magenta (sc_1ae5ddcf samples above).
  static const border = LinearGradient(
    // Pixel-space gradient on the ~150×230 lesson card: bottom-left lands
    // at .4 (blue) and the whole right edge at ≥.8 (magenta).
    begin: Alignment(-1, -1),
    end: Alignment(1.25, -.52),
    colors: gradient,
    stops: [0, .42, .8],
  );
  static const heart = LinearGradient(
    begin: Alignment(-.3, -1),
    end: Alignment(.3, 1),
    colors: gradient,
    stops: [.05, .55, 1],
  );
}

abstract final class HeartsArt {
  // sc_2cdcb710, graphic at (324,789). No count or text is in this crop.
  static const heart = ArtRegion(
    'gap-heart-earned',
    Rect.fromLTWH(324, 789, 534, 435),
  );
}

/// Reuses the bundled heart silhouette. Super's counter remains native data.
class HeartGraphic extends StatelessWidget {
  const HeartGraphic({
    required this.width,
    this.superCount,
    this.empty = false,
    super.key,
  });
  final double width;
  final int? superCount;
  final bool empty;
  Widget _silhouette(Widget art) => ColorFiltered(
    colorFilter: const ColorFilter.matrix([
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
      255,
      0,
      -1.37,
      0,
      0,
      349.35,
    ]),
    child: art,
  );
  @override
  Widget build(BuildContext context) {
    if (empty) {
      return SizedBox(
        width: width,
        height: width,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.favorite_outline_rounded,
              size: width,
              color: ReferenceColors.border,
            ),
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                ReferenceColors.disabled,
                BlendMode.srcATop,
              ),
              child: _silhouette(
                ReferenceArt(
                  HeartsArt.heart,
                  width: width * .68,
                  height: width * .55,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final art = ReferenceArt(
      HeartsArt.heart,
      width: width,
      height: width * 435 / 534,
    );
    if (superCount == null) return art;
    return SizedBox(
      width: width,
      height: width * 435 / 534,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: SuperColors.heart.createShader,
            blendMode: BlendMode.srcIn,
            // Alpha from the green channel: the red body (G 72) and the pink
            // highlight disc (G 121) both become opaque, the white backdrop
            // transparent, so the Super heart is one flat gradient (ref).
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0, 0, 0, 0, 255, //
                0, 0, 0, 0, 255, //
                0, 0, 0, 0, 255, //
                0, -2, 0, 0, 500, //
              ]),
              child: art,
            ),
          ),
          // Shine strokes at the top right of the Super heart (sc_1ae5ddcf).
          Positioned.fill(
            child: CustomPaint(painter: const _SuperSparklePainter()),
          ),
          Text(
            '$superCount',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Colors.white,
              // Digits are ~1/3 of the heart width in both refs.
              fontSize: width * .32,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuperSparklePainter extends CustomPainter {
  const _SuperSparklePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * .045;
    // A dot and a slanted stroke just under the right lobe's top edge.
    canvas.drawLine(
      Offset(size.width * .375, size.height * .05),
      Offset(size.width * .38, size.height * .08),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .63, size.height * .04),
      Offset(size.width * .585, size.height * .17),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SuperSparklePainter oldDelegate) => false;
}

/// Washes art to the pale disabled grey (hearts_02 Refill gem) without
/// flooding the crop's opaque box the way BlendMode.srcIn would.
class GreyWhenDisabled extends StatelessWidget {
  const GreyWhenDisabled({
    required this.enabled,
    required this.child,
    super.key,
  });
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? child
      : ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            .1063, .3576, .0361, 0, 127.5, //
            .1063, .3576, .0361, 0, 127.5, //
            .1063, .3576, .0361, 0, 127.5, //
            0, 0, 0, 1, 0, //
          ]),
          child: child,
        );
}
