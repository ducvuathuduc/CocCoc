import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../learning/presentation/learning_visuals.dart';

abstract final class HeartsColors {
  // earn_heart_09 page sample (20,1500): pure white, so the heart crop has no box.
  static const page = Color(0xFFFFFFFF);
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
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                LearningColors.green,
                LearningColors.blue,
                LearningColors.purple,
              ],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            // Convert the white backdrop to transparency; keep the original
            // illustration silhouette. No screenshot numbers are painted.
            child: ColorFiltered(
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
            ),
          ),
          Text(
            '$superCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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
