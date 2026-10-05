import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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

  final String asset;
  final double startFrame;
  final double endFrame;
  final bool loop;
  final double? restFrame;
}

extension DuoPoseSpec on DuoPose {
  DuoMotionSpec get spec => switch (this) {
    DuoPose.wave => const DuoMotionSpec(
      asset: 'assets/motion/duo-wave.json',
      startFrame: 600,
      endFrame: 755,
      restFrame: 635,
      loop: false,
    ),
    DuoPose.idle => const DuoMotionSpec(
      asset: 'assets/motion/duo-idle.json',
      startFrame: 0,
      endFrame: 220,
      loop: true,
    ),
    DuoPose.scribble => const DuoMotionSpec(
      asset: 'assets/motion/duo-idle.json',
      startFrame: 220,
      endFrame: 360,
      loop: true,
    ),
    DuoPose.pencil => const DuoMotionSpec(
      asset: 'assets/motion/duo-pencil.json',
      startFrame: 0,
      endFrame: 213,
      restFrame: 25,
      loop: false,
    ),
    DuoPose.celebrate => const DuoMotionSpec(
      asset: 'assets/motion/duo-celebrate.json',
      startFrame: 759,
      endFrame: 965,
      restFrame: 965,
      loop: false,
    ),
    DuoPose.clipboard => const DuoMotionSpec(
      asset: 'assets/motion/duo-celebrate.json',
      startFrame: 966,
      endFrame: 1079,
      restFrame: 1079,
      loop: false,
    ),
    DuoPose.reading => const DuoMotionSpec(
      asset: 'assets/motion/duo-reading.json',
      startFrame: 0,
      endFrame: 365,
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

class DuoMotion extends StatefulWidget {
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

  @override
  State<DuoMotion> createState() => _DuoMotionState();
}

class _DuoMotionState extends State<DuoMotion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static final Map<String, Future<LottieComposition>> _compositionCache = {};

  late final AnimationController _controller;
  LottieComposition? _composition;
  LottieDrawable? _drawable;
  Object? _loadError;
  int _loadRevision = 0;
  bool _motionAllowed = false;
  bool _appActive = true;

  DuoMotionSpec get _spec => widget.spec ?? widget.pose.spec;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allowed = _calculateMotionAllowed();
    if (_composition == null && _loadError == null && allowed) {
      unawaited(_loadComposition());
    }
    if (_motionAllowed != allowed) {
      _motionAllowed = allowed;
      if (allowed && _composition != null) {
        _play();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void didUpdateWidget(DuoMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSpec = oldWidget.spec ?? oldWidget.pose.spec;
    if (oldWidget.enabled != widget.enabled) {
      _motionAllowed = _calculateMotionAllowed();
      if (!_motionAllowed) {
        _controller.stop();
      }
    }
    if (oldSpec.asset != _spec.asset) {
      _loadRevision++;
      _controller.stop();
      _composition = null;
      _drawable = null;
      _loadError = null;
      if (_motionAllowed) unawaited(_loadComposition());
    } else if (oldSpec != _spec) {
      _play(fromStart: true);
    } else if (_motionAllowed && !_controller.isAnimating) {
      if (_composition == null && _loadError == null) {
        unawaited(_loadComposition());
      } else {
        _play();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    _motionAllowed = _calculateMotionAllowed();
    if (_motionAllowed) {
      if (_composition == null && _loadError == null) {
        unawaited(_loadComposition());
      } else {
        _play();
      }
    } else {
      _controller.stop();
    }
  }

  bool _calculateMotionAllowed() =>
      widget.enabled &&
      _appActive &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  Future<void> _loadComposition() async {
    final revision = ++_loadRevision;
    try {
      final composition = await _compositionCache.putIfAbsent(
        _spec.asset,
        () => AssetLottie(_spec.asset).load(context: context),
      );
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _composition = composition;
        _drawable = LottieDrawable(composition, frameRate: FrameRate.max);
      });
      _play(fromStart: true);
    } on Object catch (error) {
      _compositionCache.remove(_spec.asset);
      if (!mounted || revision != _loadRevision) return;
      setState(() => _loadError = error);
    }
  }

  void _play({bool fromStart = false}) {
    final composition = _composition;
    if (!_motionAllowed || composition == null) return;
    final segmentFrames = math.max(0, _spec.endFrame - _spec.startFrame);
    _controller.duration = Duration(
      microseconds: (segmentFrames / composition.frameRate * 1000000).round(),
    );
    if (fromStart) _controller.value = 0;
    if (_spec.loop) {
      _controller.repeat();
    } else {
      _controller.forward().whenComplete(() {
        if (mounted && _motionAllowed) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _loadRevision++;
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_motionAllowed || _loadError != null) return _fallback();
    final composition = _composition;
    final drawable = _drawable;
    if (composition == null || drawable == null) return _fallback();
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final completed =
                !_spec.loop && _controller.status == AnimationStatus.completed;
            final frame = completed
                ? _spec.restFrame ?? _spec.endFrame
                : _spec.startFrame +
                      (_spec.endFrame - _spec.startFrame) * _controller.value;
            return CustomPaint(
              painter: DuoMotionPainter(
                composition: composition,
                drawable: drawable,
                frame: frame,
                viewport: widget.viewport,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fallback() => SizedBox(
    width: widget.width,
    height: widget.height,
    child: widget.fallback,
  );
}

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
