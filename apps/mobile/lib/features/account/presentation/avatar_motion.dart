import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Original, code-drawn profile avatar. The selectable values are retained by
/// the account model; this painter gives them a self-contained visual result.
class AvatarMotion extends StatelessWidget {
  const AvatarMotion({
    required this.values,
    this.width,
    this.height,
    this.tile = false,
    this.animate = true,
    super.key,
  });

  final Map<String, double> values;
  final double? width;
  final double? height;
  final bool tile;
  final bool animate;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CustomPaint(painter: _CocEnglishAvatarPainter(values)),
  );
}

class _CocEnglishAvatarPainter extends CustomPainter {
  const _CocEnglishAvatarPainter(this.values);

  final Map<String, double> values;

  static const _skin = <Color>[
    Color(0xFFF6D0B2),
    Color(0xFFE8B895),
    Color(0xFFD9A07C),
    Color(0xFFCA8A68),
    Color(0xFFB97656),
    Color(0xFFA7684E),
    Color(0xFF935B45),
    Color(0xFF804D3D),
    Color(0xFF704437),
    Color(0xFF603A32),
    Color(0xFF54352E),
    Color(0xFF4B302A),
    Color(0xFF8C4A25),
    Color(0xFF7D4A3F),
    Color(0xFF6E3D3A),
  ];

  static const _hair = <Color>[
    Color(0xFF292531),
    Color(0xFF493126),
    Color(0xFF633C2B),
    Color(0xFF7A4A31),
    Color(0xFFB47743),
    Color(0xFFC7A05D),
    Color(0xFF6B3442),
    Color(0xFF394A65),
  ];

  static const _clothing = <Color>[
    Color(0xFFF47721),
    Color(0xFF008F8C),
    Color(0xFF287CAD),
    Color(0xFF715C9F),
    Color(0xFFD76568),
    Color(0xFFE5A93E),
    Color(0xFF214D5A),
    Color(0xFF5C6268),
  ];

  static const _backgrounds = <Color>[
    Color(0xFFFFF2E8),
    Color(0xFFFFE2CF),
    Color(0xFFFFD0B8),
    Color(0xFFF9B59E),
    Color(0xFFF3D5BB),
    Color(0xFFE9C5AF),
    Color(0xFFE1B48C),
    Color(0xFFB7785D),
    Color(0xFF6E473B),
    Color(0xFFE1DAD1),
    Color(0xFFC7C5C0),
    Color(0xFF8B8581),
    Color(0xFF5E5B5C),
    Color(0xFFF4E4C2),
    Color(0xFFE6C99B),
    Color(0xFFCDAE72),
    Color(0xFFFFF0B3),
    Color(0xFFFFD87A),
    Color(0xFFFFC273),
    Color(0xFFF9AB6C),
    Color(0xFFF7D4DB),
    Color(0xFFE9ADC8),
    Color(0xFFD67BA4),
    Color(0xFFB65D82),
    Color(0xFFDAF0EA),
    Color(0xFFACE0D3),
  ];

  static const _glasses = <Color>[
    Color(0xFF21314A),
    Color(0xFF008F8C),
    Color(0xFFF47721),
    Color(0xFF715C9F),
    Color(0xFFD76568),
    Color(0xFFE5A93E),
    Color(0xFF496473),
    Color(0xFF5C6268),
  ];

  static const _eyes = <Color>[
    Color(0xFF28364A),
    Color(0xFF8C4528),
    Color(0xFF79611F),
    Color(0xFF526E3A),
    Color(0xFF287A7C),
    Color(0xFF37688B),
    Color(0xFF65758D),
    Color(0xFF735796),
  ];

  double _value(String key, [double fallback = 0]) => values[key] ?? fallback;

  Color _pick(List<Color> colors, double value, Color fallback) {
    if (value <= 0) return fallback;
    final index = value.round() - 1;
    return colors[index.clamp(0, colors.length - 1)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = (size.width < size.height ? size.width : size.height) / 100;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    final backgroundValue = _value('BackgroundColor');
    if (backgroundValue > 0) {
      canvas.drawCircle(
        Offset.zero,
        48,
        Paint()
          ..color = _pick(
            _backgrounds,
            backgroundValue,
            const Color(0xFFF3E7DC),
          ),
      );
    }

    final skin = _pick(_skin, _value('SkinTone', 15), _skin.last);
    final hair = _pick(_hair, _value('MainHairColor', 1), _hair.first);
    final shirt = _pick(_clothing, _value('ClothingColor', 1), _clothing[0]);
    final hairPaint = Paint()..color = hair;
    final skinPaint = Paint()..color = skin;
    final shirtPaint = Paint()..color = shirt;
    final white = Paint()..color = Colors.white;
    final eyeColor = Paint()
      ..color = _pick(_eyes, _value('EyeColor', 1), _eyes[0]);
    final accessory = Paint()..color = const Color(0xFFFFC744);

    // Neck and shoulders.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, 7, 24, 22),
        const Radius.circular(8),
      ),
      skinPaint,
    );
    final shirtPath = Path()
      ..moveTo(-41, 47)
      ..quadraticBezierTo(-37, 18, -16, 20)
      ..lineTo(-9, 15)
      ..lineTo(0, 24)
      ..lineTo(9, 15)
      ..lineTo(16, 20)
      ..quadraticBezierTo(37, 18, 41, 47)
      ..close();
    canvas.drawPath(shirtPath, shirtPaint);
    canvas.drawPath(
      shirtPath,
      Paint()
        ..color = const Color(0xFF493A38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Head and hair.
    final head = Rect.fromCenter(
      center: const Offset(0, -12),
      width: 52 + (_value('Body', 1) % 2) * 2,
      height: 62,
    );
    canvas.drawOval(head, skinPaint);
    canvas.drawOval(
      head,
      Paint()
        ..color = const Color(0xFF493A38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final hairStyle = _value('MainHair', 58).round();
    final hairCap = Path()
      ..moveTo(-27, -18)
      ..quadraticBezierTo(-32, -53, -1, -47)
      ..quadraticBezierTo(28, -51, 28, -19)
      ..quadraticBezierTo(17, -30, 5, -31)
      ..quadraticBezierTo(-8, -24, -27, -18)
      ..close();
    canvas.drawPath(hairCap, hairPaint);
    if (hairStyle.isOdd) {
      canvas.drawCircle(const Offset(-23, -13), 9, hairPaint);
      canvas.drawCircle(const Offset(23, -13), 8, hairPaint);
    } else if (hairStyle % 3 == 0) {
      canvas.drawOval(const Rect.fromLTWH(-33, -35, 16, 28), hairPaint);
      canvas.drawOval(const Rect.fromLTWH(17, -35, 16, 28), hairPaint);
    }

    // Eyes, eyebrows and expression.
    final expression = _value('Expression', 17).round();
    final eyeY = expression % 3 == 0 ? -14.0 : -12.0;
    canvas.drawOval(const Rect.fromLTWH(-17, -20, 6, 10), eyeColor);
    canvas.drawOval(const Rect.fromLTWH(11, -20, 6, 10), eyeColor);
    canvas.drawCircle(const Offset(-15, -17), 1.6, white);
    canvas.drawCircle(const Offset(13, -17), 1.6, white);
    final brow = Paint()
      ..color = hair
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-20, -25), const Offset(-10, -26), brow);
    canvas.drawLine(const Offset(10, -26), const Offset(20, -25), brow);
    final mouth = Paint()
      ..color = const Color(0xFF9A4D4B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(-7, eyeY + 5, 14, expression % 2 == 0 ? 9 : 7),
      .2,
      math.pi - .4,
      false,
      mouth,
    );

    // Optional facial hair, glasses and small accessories.
    if (_value('FacialHair') > 0) {
      final beard = Path()
        ..moveTo(-20, 0)
        ..quadraticBezierTo(-12, 10, 0, 9)
        ..quadraticBezierTo(13, 10, 20, 0)
        ..quadraticBezierTo(16, 18, 0, 20)
        ..quadraticBezierTo(-16, 18, -20, 0)
        ..close();
      final beardColor = switch (_value('FacialHairColor', 1).round()) {
        1 => const Color(0xFF434343),
        2 => const Color(0xFF5D3B2D),
        3 => const Color(0xFF592615),
        4 => const Color(0xFF703030),
        6 => const Color(0xFF785B56),
        7 => const Color(0xFFA44D13),
        9 => const Color(0xFFF09647),
        10 => const Color(0xFFFFD1A4),
        _ => hair,
      };
      canvas.drawPath(beard, Paint()..color = beardColor);
    }
    if (_value('Glasses') > 0) {
      final glasses = Paint()
        ..color = _pick(_glasses, _value('GlassesColor', 1), _glasses[0])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-23, -21, 20, 16),
          const Radius.circular(6),
        ),
        glasses,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, -21, 20, 16),
          const Radius.circular(6),
        ),
        glasses,
      );
      canvas.drawLine(const Offset(-3, -14), const Offset(3, -14), glasses);
    }
    if (_value('Piercings') > 0 || _value('Nose Piercing') > 0) {
      canvas.drawCircle(const Offset(23, -1), 3, accessory);
    }
    if (_value('Headwear') > 0) {
      final hat = Path()
        ..moveTo(-30, -37)
        ..quadraticBezierTo(-24, -53, -2, -52)
        ..quadraticBezierTo(20, -52, 27, -37)
        ..lineTo(34, -34)
        ..lineTo(-35, -34)
        ..close();
      canvas.drawPath(
        hat,
        Paint()..color = _pick(_clothing, _value('HeadwearColor', 1), shirt),
      );
      canvas.drawPath(
        hat,
        Paint()
          ..color = const Color(0xFF493A38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CocEnglishAvatarPainter oldDelegate) =>
      !mapEquals(oldDelegate.values, values);
}
