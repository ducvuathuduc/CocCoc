import 'package:flutter/material.dart';

import 'duo_motion.dart';
import 'reference_art.dart';

/// Keeps measured layout dimensions while playing the original vector timeline.
class DuoIllustration extends StatelessWidget {
  const DuoIllustration(
    this.region, {
    required this.width,
    required this.height,
    super.key,
  });
  final ArtRegion region;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final (pose, viewport) = switch (region) {
      ReferenceArtRegions.welcomeDuo => (
        DuoPose.wave,
        const Rect.fromLTWH(256, 555, 382, 377),
      ),
      ReferenceArtRegions.waving => (
        DuoPose.wave,
        const Rect.fromLTWH(269, 549, 363, 392),
      ),
      ReferenceArtRegions.excited => (
        DuoPose.celebrate,
        const Rect.fromLTWH(260, 542, 408, 415),
      ),
      ReferenceArtRegions.questionDuo => (
        DuoPose.idle,
        const Rect.fromLTWH(75, -72, 454, 560),
      ),
      ReferenceArtRegions.writing => (
        DuoPose.pencil,
        const Rect.fromLTWH(69, -25, 571, 545),
      ),
      ReferenceArtRegions.building => (
        DuoPose.reading,
        const Rect.fromLTWH(295, 288, 512, 711),
      ),
      _ => (null, null),
    };
    final still = ReferenceArt(region, width: width, height: height);
    if (pose == null) return still;
    return DuoMotion(
      key: ValueKey(region),
      pose: pose,
      width: width,
      height: height,
      viewport: viewport,
      spec: region == ReferenceArtRegions.welcomeDuo
          ? const DuoMotionSpec(
              asset: 'assets/motion/duo-wave.json',
              startFrame: 600,
              endFrame: 755,
              restFrame: 600,
              loop: false,
            )
          : null,
      fallback: still,
    );
  }
}
