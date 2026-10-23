import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../domain/call_models.dart';
import 'call_visuals.dart';

const _bold = TextStyle(
  fontFamily: 'DuolingoSans',
  fontWeight: FontWeight.w700,
  color: CallColors.white,
);

/// Shared press-down behaviour: the face sinks onto its 3D edge.
class _PressDepth extends StatefulWidget {
  const _PressDepth({
    required this.onTap,
    required this.builder,
    required this.semanticLabel,
  });
  final VoidCallback? onTap;
  final Widget Function(bool pressed) builder;
  final String semanticLabel;

  @override
  State<_PressDepth> createState() => _PressDepthState();
}

class _PressDepthState extends State<_PressDepth> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onTap != null && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.semanticLabel,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: ExcludeSemantics(child: widget.builder(_pressed)),
    ),
  );
}

/// Red round hang-up button with a 3D edge (refs 03–05).
class HangUpButton extends StatelessWidget {
  const HangUpButton({required this.onPressed, this.size = 62, super.key});
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final duration = CallMotion.reduced(context)
        ? Duration.zero
        : CallMotion.press;
    const edge = 4.0;
    return _PressDepth(
      onTap: onPressed,
      semanticLabel: 'Hang up',
      builder: (pressed) => SizedBox(
        width: size,
        height: size + edge,
        child: Stack(
          children: [
            Positioned(
              top: edge,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: CallColors.hangUpEdge,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeOut,
              top: pressed ? edge : 0,
              child: Container(
                key: const ValueKey('hang-up-face'),
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: CallColors.hangUp,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.call_end_rounded,
                  color: CallColors.white,
                  size: size * .5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Learner mic. Pressing on your turn starts mock listening.
class CallMicButton extends StatelessWidget {
  const CallMicButton({
    required this.enabled,
    required this.listening,
    required this.onPressed,
    this.size = 56,
    super.key,
  });
  final bool enabled;
  final bool listening;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reduced = CallMotion.reduced(context);
    return _PressDepth(
      onTap: enabled ? onPressed : null,
      semanticLabel: listening ? 'Listening' : 'Speak',
      builder: (pressed) => AnimatedScale(
        scale: pressed && !reduced ? .9 : 1,
        duration: reduced ? Duration.zero : CallMotion.press,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          key: const ValueKey('call-mic'),
          duration: reduced ? Duration.zero : CallMotion.caption,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening ? CallColors.cyan : CallColors.bubble,
            border: Border.all(
              color: enabled ? CallColors.cyan : CallColors.bubbleBorder,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.mic_rounded,
            size: size * .5,
            color: listening
                ? CallColors.dock
                : enabled
                ? CallColors.cyan
                : CallColors.bubbleBorder,
          ),
        ),
      ),
    );
  }
}

/// Bouncing listening bars shown while the mic is open.
class ListeningWaveform extends StatefulWidget {
  const ListeningWaveform({this.bars = 5, this.height = 28, super.key});
  final int bars;
  final double height;

  @override
  State<ListeningWaveform> createState() => _ListeningWaveformState();
}

class _ListeningWaveformState extends State<ListeningWaveform>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: CallMotion.wave,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CallMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = .5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('listening-waveform'),
    height: widget.height,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.bars; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 5,
              height:
                  widget.height *
                  (.3 +
                      .7 *
                          (.5 +
                                  .5 *
                                      math.sin(
                                        (_controller.value + i / widget.bars) *
                                            math.pi *
                                            2,
                                      ))
                              .abs()),
              decoration: BoxDecoration(
                color: CallColors.cyan,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Lily's circular portrait with expanding cyan pulse rings while ringing.
class RingingAvatar extends StatefulWidget {
  const RingingAvatar({
    required this.art,
    this.diameter = 188,
    this.pulsing = true,
    super.key,
  });
  final ArtRegion art;
  final double diameter;
  final bool pulsing;

  @override
  State<RingingAvatar> createState() => _RingingAvatarState();
}

class _RingingAvatarState extends State<RingingAvatar>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: CallMotion.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RingingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (!widget.pulsing || CallMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    return SizedBox(
      width: d * 1.5,
      height: d * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('ringing-pulse'),
              size: Size.square(d * 1.5),
              painter: _PulsePainter(_controller, d / 2),
            ),
          ),
          ClipOval(
            child: ReferenceArt(widget.art, width: d, height: d),
          ),
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.animation, this.radius) : super(repaint: animation);
  final Animation<double> animation;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (animation.value == 0 && !animation.isAnimating) return;
    final center = size.center(Offset.zero);
    for (final offset in const [0.0, .5]) {
      final t = (animation.value + offset) % 1;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = CallColors.cyan.withValues(alpha: (1 - t) * .7);
      canvas.drawCircle(center, radius + t * radius * .45, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) => false;
}

/// Glowing cyan side bars from refs 03/06, gently breathing.
class GlowBars extends StatefulWidget {
  const GlowBars({required this.heights, super.key});
  final List<double> heights;

  @override
  State<GlowBars> createState() => _GlowBarsState();
}

class _GlowBarsState extends State<GlowBars>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: CallMotion.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CallMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.heights.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 10, top: i * 18.0),
              child: Container(
                width: 10,
                height:
                    widget.heights[i] *
                    (.75 + .25 * ((_controller.value + i * .3) % 1)),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [CallColors.cyan, CallColors.night],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Caption overlay for the current line. Fades + rises in on each new line.
class CallCaption extends StatelessWidget {
  const CallCaption({required this.line, super.key});
  final CallLine? line;

  @override
  Widget build(BuildContext context) {
    final reduced = CallMotion.reduced(context);
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: reduced ? Duration.zero : CallMotion.caption,
        switchInCurve: Curves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: line == null
            ? const SizedBox.shrink(key: ValueKey('caption-empty'))
            : Container(
                key: ValueKey('caption-${line!.text}-${line!.speaker.name}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CallColors.dock.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  line!.text,
                  textAlign: TextAlign.center,
                  style: _bold.copyWith(
                    fontSize: 20,
                    color: line!.speaker == CallSpeaker.learner
                        ? CallColors.cyan
                        : CallColors.white,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Full-width cyan→mint gradient CONTINUE button (refs 06–08).
class GlowButton extends StatelessWidget {
  const GlowButton({required this.label, required this.onPressed, super.key});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reduced = CallMotion.reduced(context);
    return _PressDepth(
      onTap: onPressed,
      semanticLabel: label,
      builder: (pressed) => AnimatedScale(
        scale: pressed && !reduced ? .97 : 1,
        duration: reduced ? Duration.zero : CallMotion.press,
        child: Container(
          height: 53,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [CallColors.glowStart, CallColors.glowEnd],
            ),
          ),
          child: Text(
            label,
            style: _bold.copyWith(
              color: CallColors.night,
              fontSize: 17,
              letterSpacing: .8,
            ),
          ),
        ),
      ),
    );
  }
}

/// White 3D pill button (UPGRADE TO MAX) and plain text button (NO THANKS).
class CallSolidButton extends StatelessWidget {
  const CallSolidButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final duration = CallMotion.reduced(context)
        ? Duration.zero
        : CallMotion.press;
    const edge = 4.0;
    return _PressDepth(
      onTap: onPressed,
      semanticLabel: label,
      builder: (pressed) => SizedBox(
        height: filled ? 52 : 48,
        child: !filled
            ? Center(
                child: Text(
                  label,
                  style: _bold.copyWith(fontSize: 16.5, letterSpacing: .8),
                ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    top: edge,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CallColors.buttonEdge,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: duration,
                    left: 0,
                    right: 0,
                    top: pressed ? edge : 0,
                    bottom: pressed ? 0 : edge,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: CallColors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        label,
                        style: _bold.copyWith(
                          color: CallColors.phoneScreen,
                          fontSize: 16.5,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// One transcript row of the review screen (refs 07/08).
class ReviewBubble extends StatelessWidget {
  const ReviewBubble({
    required this.line,
    required this.learnerInitial,
    super.key,
  });
  final CallLine line;
  final String learnerInitial;

  @override
  Widget build(BuildContext context) {
    final partner = line.speaker == CallSpeaker.partner;
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: partner ? CallColors.bubble : CallColors.night,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: partner ? CallColors.bubbleBorder : CallColors.bubbleBorder,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (partner) ...[
              const Icon(
                Icons.volume_up_rounded,
                size: 22,
                color: CallColors.cyan,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                line.text,
                style: _bold.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w400,
                  decoration: partner ? TextDecoration.underline : null,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationColor: CallColors.bubbleBorder,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: partner
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: partner
            ? [
                const ReferenceArt(CallArt.reviewAvatar, width: 46, height: 44),
                const SizedBox(width: 22),
                bubble,
                const SizedBox(width: 48),
              ]
            : [
                const SizedBox(width: 64),
                bubble,
                const SizedBox(width: 14),
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: CallColors.bubbleBorder,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    learnerInitial,
                    style: _bold.copyWith(fontSize: 18),
                  ),
                ),
              ],
      ),
    );
  }
}

/// Path pop-over offering the call (ref 02). Embeddable by the path screen.
class VideoCallIntroCard extends StatelessWidget {
  const VideoCallIntroCard({
    required this.copy,
    required this.onCall,
    required this.onLater,
    super.key,
  });
  final CallCopy copy;
  final VoidCallback onCall;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
    decoration: BoxDecoration(
      color: CallColors.introGreen,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(copy.introTitle, style: _bold.copyWith(fontSize: 21)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: CallColors.introGreen,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: CallColors.white, width: 2),
              ),
              child: Text(
                copy.maxBadge,
                style: _bold.copyWith(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _IntroButton(
          label: copy.introCallLabel,
          filled: true,
          onPressed: onCall,
        ),
        const SizedBox(height: 12),
        _IntroButton(
          label: copy.introLaterLabel,
          filled: false,
          onPressed: onLater,
        ),
      ],
    ),
  );
}

class _IntroButton extends StatelessWidget {
  const _IntroButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });
  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final duration = CallMotion.reduced(context)
        ? Duration.zero
        : CallMotion.press;
    const edge = 4.0;
    final face = filled ? CallColors.introSurface : CallColors.introGreen;
    return _PressDepth(
      onTap: onPressed,
      semanticLabel: label,
      builder: (pressed) => SizedBox(
        height: 52,
        child: Stack(
          children: [
            Positioned.fill(
              top: edge,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: filled ? CallColors.buttonEdge : CallColors.introEdge,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: duration,
              left: 0,
              right: 0,
              top: pressed ? edge : 0,
              bottom: pressed ? 0 : edge,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: face,
                  borderRadius: BorderRadius.circular(12),
                  border: filled
                      ? null
                      : Border.all(color: CallColors.introEdge, width: 2),
                ),
                child: Text(
                  label,
                  style: _bold.copyWith(
                    fontSize: 16.5,
                    letterSpacing: .8,
                    color: filled ? CallColors.introGreen : CallColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
