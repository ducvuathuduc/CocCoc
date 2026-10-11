import 'package:flutter/material.dart';

/// Motion timings for the onboarding flow (Duolingo-like, documented in
/// specs/onboarding.md). Every widget here collapses to a static frame when
/// [MediaQuery.disableAnimationsOf] is true.
abstract final class OnboardingMotion {
  static const page = Duration(milliseconds: 300);
  static const select = Duration(milliseconds: 260);
  static const bubble = Duration(milliseconds: 320);
  static const mascot = Duration(milliseconds: 420);
}

bool _reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Slides the incoming step in from the right (or left when going back).
class OnboardingPageSwitcher extends StatelessWidget {
  const OnboardingPageSwitcher({
    required this.pageKey,
    required this.forward,
    required this.child,
    super.key,
  });
  final Key pageKey;
  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = _reduced(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : OnboardingMotion.page,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final incoming = child.key == pageKey;
        final dx = (forward ? 1.0 : -1.0) * (incoming ? 1 : -1);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(
              Tween(begin: Offset(dx * .35, 0), end: Offset.zero),
            ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: pageKey, child: child),
    );
  }
}

/// Squash-and-overshoot when an option becomes selected.
class SelectBounce extends StatefulWidget {
  const SelectBounce({required this.selected, required this.child, super.key});
  final bool selected;
  final Widget child;
  @override
  State<SelectBounce> createState() => _SelectBounceState();
}

class _SelectBounceState extends State<SelectBounce>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: OnboardingMotion.select,
  );
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: .94,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: .94,
        end: 1.03,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.03,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
  ]);

  @override
  void didUpdateWidget(SelectBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected && !_reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _controller.drive(_scale), child: widget.child);
}

/// Pops a speech bubble or mascot in once when it first appears.
class PopIn extends StatefulWidget {
  const PopIn({
    required this.child,
    this.alignment = Alignment.center,
    this.duration = OnboardingMotion.bubble,
    this.delay = Duration.zero,
    super.key,
  });
  final Widget child;
  final Alignment alignment;
  final Duration duration;
  final Duration delay;
  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration + widget.delay,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds /
          (widget.duration + widget.delay).inMicroseconds,
      1,
      curve: Curves.easeOutBack,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed) {
      if (_reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (context, child) {
      final t = _curve.value;
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: .6 + .4 * t,
          alignment: widget.alignment,
          child: child,
        ),
      );
    },
    child: widget.child,
  );
}
