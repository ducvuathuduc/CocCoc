import 'package:flutter/material.dart';

/// Shared icon control with a stable hit area and reduced-motion-aware press.
class PressableIcon extends StatefulWidget {
  const PressableIcon({
    required this.onTap,
    required this.child,
    this.radius = 14,
    super.key,
  });
  final VoidCallback onTap;
  final Widget child;
  final double radius;

  @override
  State<PressableIcon> createState() => _PressableIconState();
}

class _PressableIconState extends State<PressableIcon> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(widget.radius),
    onTap: widget.onTap,
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) => setState(() => _pressed = false),
    onTapCancel: () => setState(() => _pressed = false),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: AnimatedScale(
        scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .94 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    ),
  );
}
