import 'package:flutter/material.dart';

import 'reference_theme.dart';

class ChineseFlag extends StatelessWidget {
  const ChineseFlag({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 40,
      height: 31,
      decoration: BoxDecoration(
        color: const Color(0xFFFF4B4B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Stack(
        children: [
          Positioned(
            left: 6,
            top: 6,
            child: Icon(Icons.star, color: Color(0xFFFFD900), size: 10),
          ),
          Positioned(
            left: 15,
            top: 3,
            child: Icon(Icons.star, color: Color(0xFFFFD900), size: 4),
          ),
          Positioned(
            left: 19,
            top: 7,
            child: Icon(Icons.star, color: Color(0xFFFFD900), size: 4),
          ),
          Positioned(
            left: 19,
            top: 12,
            child: Icon(Icons.star, color: Color(0xFFFFD900), size: 4),
          ),
          Positioned(
            left: 15,
            top: 16,
            child: Icon(Icons.star, color: Color(0xFFFFD900), size: 4),
          ),
        ],
      ),
    ),
  );
}

class ReferenceButton extends StatefulWidget {
  const ReferenceButton({
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.backgroundColor,
    this.edgeColor,
    this.foregroundColor,
    this.leading,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final Color? backgroundColor;
  final Color? edgeColor;
  final Color? foregroundColor;
  final Widget? leading;
  @override
  State<ReferenceButton> createState() => _ReferenceButtonState();
}

class _ReferenceButtonState extends State<ReferenceButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final background = !enabled
        ? widget.outlined
              ? ReferenceColors.surface
              : ReferenceColors.border
        : widget.outlined
        ? ReferenceColors.surface
        : widget.backgroundColor ?? ReferenceColors.green;
    final edge = widget.outlined
        ? ReferenceColors.border
        : widget.edgeColor ?? ReferenceColors.greenEdge;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedPadding(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 80),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            top: _pressed ? 4 : 0,
            bottom: _pressed ? 0 : 4,
          ),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 80),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
              border: widget.outlined
                  ? Border.all(color: ReferenceColors.border, width: 2)
                  : null,
              boxShadow: enabled && !_pressed
                  ? [BoxShadow(color: edge, offset: const Offset(0, 4))]
                  : null,
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size(double.infinity, widget.outlined ? 40 : 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: widget.outlined
                      ? widget.leading == null
                            ? 10
                            : 8
                      : 12,
                ),
                foregroundColor: !enabled
                    ? ReferenceColors.disabled
                    : widget.foregroundColor != null
                    ? widget.foregroundColor!
                    : widget.outlined
                    ? ReferenceColors.green
                    : Colors.white,
                disabledForegroundColor: ReferenceColors.disabled,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'DuolingoSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  height: 1.1,
                ),
              ),
              onPressed: widget.onPressed,
              child: widget.leading == null
                  ? Text(widget.label, textAlign: TextAlign.center)
                  : widget.label.isEmpty
                  ? widget.leading!
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        widget.leading!,
                        const SizedBox(width: 16),
                        Flexible(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    required this.child,
    required this.selected,
    required this.onTap,
    this.recommended = false,
    this.minHeight = 31,
    super.key,
  });
  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final bool recommended;
  final double minHeight;
  @override
  Widget build(BuildContext context) {
    final border = selected
        ? ReferenceColors.blueBorder
        : ReferenceColors.border;
    final card = Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? ReferenceColors.blueFill : ReferenceColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: selected ? ReferenceColors.blue : ReferenceColors.ink,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: border, offset: const Offset(0, 4))],
        ),
        child: recommended
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  card,
                  Positioned(
                    right: -7,
                    top: -13,
                    child: ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1CB0F6),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'RECOMMENDED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : card,
      ),
    );
  }
}

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({required this.child, this.below = false, super.key});
  final Widget child;
  final bool below;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BubblePainter(below),
    child: Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, below ? 24 : 14),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontSize: 20,
          height: 1.42,
          color: ReferenceColors.ink,
        ),
        child: child,
      ),
    ),
  );
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.below);
  final bool below;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height - (below ? 10 : 0),
    );
    final shape = RRect.fromRectAndRadius(bounds, const Radius.circular(13));
    final fill = Paint()..color = ReferenceColors.surface;
    final stroke = Paint()
      ..color = ReferenceColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(shape, fill);
    canvas.drawRRect(shape, stroke);
    final tail = Path();
    if (below) {
      final x = size.width / 2;
      tail.moveTo(x - 9, bounds.bottom - 1);
      tail.lineTo(x, size.height);
      tail.quadraticBezierTo(x + 1, size.height + 1, x + 3, size.height - 2);
      tail.lineTo(x + 10, bounds.bottom - 1);
    } else {
      final y = size.height * .64;
      tail.moveTo(1, y - 10);
      tail.lineTo(-14, y + 1);
      tail.quadraticBezierTo(-16, y + 4, -10, y + 4);
      tail.lineTo(1, y + 4);
    }
    canvas.drawPath(tail, fill);
    canvas.drawPath(tail, stroke);
    // Erase the shared base line, leaving the bubble and tail as one outline.
    final eraser = Paint()
      ..color = ReferenceColors.surface
      ..strokeWidth = 3;
    if (below) {
      canvas.drawLine(
        Offset(size.width / 2 - 8, bounds.bottom),
        Offset(size.width / 2 + 8, bounds.bottom),
        eraser,
      );
    } else {
      final y = size.height * .64;
      canvas.drawLine(Offset(0, y - 9), Offset(0, y + 3), eraser);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => below != oldDelegate.below;
}

class ReferenceBackIcon extends StatelessWidget {
  const ReferenceBackIcon({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 28,
    height: 28,
    child: CustomPaint(painter: _BackPainter()),
  );
}

class _BackPainter extends CustomPainter {
  const _BackPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ReferenceColors.disabled
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(13, 5)
        ..lineTo(4, 14)
        ..lineTo(13, 23)
        ..moveTo(4, 14)
        ..lineTo(25, 14),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackPainter oldDelegate) => false;
}

class FlowHeader extends StatelessWidget {
  const FlowHeader({required this.onBack, this.progress, super.key});
  final VoidCallback onBack;
  final double? progress;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 3, 16, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          icon: const ReferenceBackIcon(),
        ),
        if (progress != null) const SizedBox(width: 6),
        if (progress != null)
          Expanded(
            child: Semantics(
              label: 'Onboarding progress',
              value: '${(progress! * 100).round()}%',
              child: SizedBox(
                height: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: ReferenceColors.border),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: progress!.clamp(0, 1)),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) =>
                            FractionallySizedBox(
                              widthFactor: value,
                              child: child,
                            ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: ReferenceColors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF80DE1A),
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
