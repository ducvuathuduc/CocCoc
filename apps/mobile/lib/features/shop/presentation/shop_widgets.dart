import 'package:flutter/material.dart';

// PIL samples: shop/02.png surface (10,20), ink glyph (144,1094),
// border (50,1550), blue shop/04.png (200,1920).
abstract final class ShopColors {
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF4B4B4B);
  static const border = Color(0xFFE5E5E5);
  static const blue = Color(0xFF1CB0F6);
}

class ShopManageButton extends StatelessWidget {
  const ShopManageButton({required this.onPressed, super.key});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: const _ManagePainter(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            width: double.infinity,
            child: const Text(
              'MANAGE FEATURES',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ManagePainter extends CustomPainter {
  const _ManagePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // shop/02.png (500,886): bottom edge. Row 840, x=300/600/900:
    // (54,239,236)/(51,240,215)/(48,241,193).
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()..color = const Color(0xFF14DAEB),
    );
    final face = Rect.fromLTWH(0, 0, size.width, size.height - 4.4);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(face, const Radius.circular(14)));
    canvas.drawRect(
      face,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF38EEFF),
            Color(0xFF36EFEC),
            Color(0xFF33F0D7),
            Color(0xFF30F1C1),
            Color(0xFF30F2B8),
          ],
          stops: [0, .218, .516, .815, 1],
        ).createShader(face),
    );
    // Stripe samples: shop/02.png (100,800) and (1000,830).
    for (final stripe in [(0.0, .12), (.23, .035), (.31, .085), (.88, .12)]) {
      final left = size.width * stripe.$1;
      final width = size.width * stripe.$2;
      final path = Path()
        ..moveTo(left, face.height)
        ..lineTo(left + width, face.height)
        ..lineTo(left + width + face.height * .85, 0)
        ..lineTo(left + face.height * .85, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF73F4FB), Color(0xFF6EF6CB)],
          ).createShader(face),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ManagePainter oldDelegate) => false;
}
