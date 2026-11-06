import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'cocenglish_brand.dart';

enum DuoPose { wave, idle, scribble, pencil, celebrate, clipboard, reading }

@immutable
class DuoMotionSpec {
  const DuoMotionSpec({
    required this.asset,
    required this.startFrame,
    required this.endFrame,
    required this.loop,
    this.restFrame,
  });

  /// Retained so older callers can keep their timing metadata during migration.
  /// The app no longer loads motion files from another brand.
  final String asset;
  final double startFrame;
  final double endFrame;
  final bool loop;
  final double? restFrame;
}

extension DuoPoseSpec on DuoPose {
  DuoMotionSpec get spec => switch (this) {
    DuoPose.wave => const DuoMotionSpec(
      asset: '',
      startFrame: 0,
      endFrame: 1,
      loop: false,
    ),
    DuoPose.idle => const DuoMotionSpec(
      asset: '',
      startFrame: 0,
      endFrame: 1,
      loop: true,
    ),
    DuoPose.scribble => const DuoMotionSpec(
      asset: '',
      startFrame: 0,
      endFrame: 1,
      loop: true,
    ),
    DuoPose.pencil => const DuoMotionSpec(
      asset: '',
      startFrame: 0,
      endFrame: 1,
      loop: false,
    ),
    DuoPose.celebrate => const DuoMotionSpec(
      asset: '',
      startFrame: 0,
      endFrame: 1,
      loop: false,
    ),
    DuoPose.clipboard => const DuoMotionSpec(
      asset: '',
      startFrame: 0,
      endFrame: 1,
      loop: false,
    ),
    DuoPose.reading => const DuoMotionSpec(
      asset: '',
      startFrame: 0,
      endFrame: 1,
      loop: true,
    ),
  };
}

double duoFrameProgress({
  required double frame,
  required double compositionStartFrame,
  required double compositionEndFrame,
}) {
  final duration = compositionEndFrame - compositionStartFrame;
  if (duration <= 0) return 0;
  return ((frame - compositionStartFrame) / duration).clamp(0.0, 1.0);
}

/// Keeps the measured layout while displaying the CocEnglish mascot in a
/// matching still pose. No third-party character or animation is loaded.
class DuoMotion extends StatelessWidget {
  const DuoMotion({
    required this.pose,
    required this.width,
    required this.height,
    required this.fallback,
    this.spec,
    this.viewport,
    this.enabled = const bool.fromEnvironment(
      'ENABLE_MASCOT_MOTION',
      defaultValue: true,
    ),
    super.key,
  });

  final DuoPose pose;
  final DuoMotionSpec? spec;
  final double width;
  final double height;
  final Widget fallback;
  final Rect? viewport;
  final bool enabled;

  @visibleForTesting
  static bool debugSingleCycleLoops = false;

  @override
  Widget build(BuildContext context) => CocEnglishMascot(
    width: width,
    height: height,
    pose: switch (pose) {
      DuoPose.wave || DuoPose.idle => CocEnglishMascotPose.wave,
      DuoPose.celebrate => CocEnglishMascotPose.celebrate,
      DuoPose.scribble ||
      DuoPose.pencil ||
      DuoPose.clipboard ||
      DuoPose.reading => CocEnglishMascotPose.study,
    },
  );
}

/// Geometry utility retained for the local animation QA helpers.
class DuoMotionPainter extends CustomPainter {
  DuoMotionPainter({
    required this.composition,
    required this.drawable,
    required this.frame,
    this.viewport,
  }) : progress = duoFrameProgress(
         frame: frame,
         compositionStartFrame: composition.startFrame,
         compositionEndFrame: composition.endFrame,
       );

  final LottieComposition composition;
  final LottieDrawable drawable;
  final double frame;
  final double progress;
  final Rect? viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(
      composition.bounds.left.toDouble(),
      composition.bounds.top.toDouble(),
      composition.bounds.width.toDouble(),
      composition.bounds.height.toDouble(),
    );
    final source = viewport == null || viewport!.isEmpty ? bounds : viewport!;
    final scale = math.min(
      size.width / source.width,
      size.height / source.height,
    );
    final visibleSize = Size(source.width * scale, source.height * scale);
    final visibleLeft = (size.width - visibleSize.width) / 2;
    final visibleTop = (size.height - visibleSize.height) / 2;
    final destination = Rect.fromLTWH(
      visibleLeft - (source.left - bounds.left) * scale,
      visibleTop - (source.top - bounds.top) * scale,
      bounds.width * scale,
      bounds.height * scale,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawable
      ..setProgress(progress)
      ..draw(
        canvas,
        destination,
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
      );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DuoMotionPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.viewport != viewport ||
      oldDelegate.drawable != drawable;
}
