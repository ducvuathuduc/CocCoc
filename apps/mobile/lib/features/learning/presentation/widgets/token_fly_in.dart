import 'package:flutter/material.dart';

/// Word tile "flies" from its word-bank slot ([originKey]) into the answer
/// line. Under reduced motion it appears in place immediately.
class TokenFlyIn extends StatefulWidget {
  const TokenFlyIn({required this.child, this.originKey, super.key});
  final Widget child;
  final GlobalKey? originKey;

  @override
  State<TokenFlyIn> createState() => _TokenFlyInState();
}

class _TokenFlyInState extends State<TokenFlyIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  Offset _from = Offset.zero;
  bool _measuring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) &&
        widget.originKey?.currentContext != null &&
        !_controller.isAnimating &&
        _from == Offset.zero) {
      _measuring = true;
    }
  }

  void _launch() {
    if (!mounted) return;
    final origin =
        widget.originKey?.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (!_measuring ||
        origin == null ||
        me == null ||
        !origin.attached ||
        !me.attached) {
      if (_measuring) setState(() => _measuring = false);
      return;
    }
    setState(() {
      _from = origin.localToGlobal(Offset.zero) - me.localToGlobal(Offset.zero);
      _measuring = false;
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_measuring) return Opacity(opacity: 0, child: widget.child);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_controller.value);
        return Transform.translate(
          offset: Offset.lerp(_from, Offset.zero, t)!,
          child: child,
        );
      },
    );
  }
}
