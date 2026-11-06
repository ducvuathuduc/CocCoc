import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cocenglish_brand.dart';

class ArtRegion {
  const ArtRegion(this.file, this.source);
  final String file;
  final Rect source;
}

// Original source PNGs remain untouched. Only these illustration/icon regions
// are painted; text, cards, buttons and interaction are native Flutter widgets.
abstract final class ReferenceArtRegions {
  static const splashFace = ArtRegion('01', Rect.fromLTWH(330, 1060, 520, 348));
  static const splashWordmark = ArtRegion(
    '01',
    Rect.fromLTWH(310, 2225, 560, 150),
  );
  static const welcomeDuo = ArtRegion('02', Rect.fromLTWH(402, 720, 370, 365));
  static const wordmark = ArtRegion('02', Rect.fromLTWH(315, 1170, 555, 135));
  static const waving = ArtRegion('03', Rect.fromLTWH(400, 1306, 365, 394));
  static const excited = ArtRegion('04', Rect.fromLTWH(390, 1300, 410, 415));
  static const questionDuo = ArtRegion('05', Rect.fromLTWH(48, 350, 287, 354));
  static const building = ArtRegion('07', Rect.fromLTWH(414, 874, 370, 463));
  static const phoneWidget = ArtRegion('15', Rect.fromLTWH(152, 885, 875, 930));
  static const writing = ArtRegion('20', Rect.fromLTWH(380, 1300, 445, 425));
  static const book = ArtRegion('19', Rect.fromLTWH(128, 819, 177, 216));
  static const compass = ArtRegion('19', Rect.fromLTWH(110, 1205, 215, 215));
  static const loginDuo = ArtRegion(
    'login-07',
    Rect.fromLTWH(435, 312, 315, 365),
  );
  static const successDuo = ArtRegion(
    'login-17',
    Rect.fromLTWH(440, 1430, 315, 490),
  );
  static const google = ArtRegion('login-03', Rect.fromLTWH(276, 1681, 72, 72));
  static const facebook = ArtRegion(
    'login-03',
    Rect.fromLTWH(245, 1870, 78, 78),
  );
  static const apple = ArtRegion('login-03', Rect.fromLTWH(308, 2057, 68, 82));
  static const hiddenEye = ArtRegion(
    'login-03',
    Rect.fromLTWH(984, 548, 84, 64),
  );
  static const flags = [
    ArtRegion('05', Rect.fromLTWH(102, 968, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1173, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1378, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1583, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1788, 124, 96)),
    ArtRegion('05', Rect.fromLTWH(102, 1993, 124, 96)),
  ];
  static const reasonIcons = [
    ArtRegion('09', Rect.fromLTWH(96, 785, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1003, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1221, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1439, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1657, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 1875, 140, 125)),
    ArtRegion('09', Rect.fromLTWH(96, 2093, 140, 125)),
  ];
  static const benefitIcons = [
    ArtRegion('16', Rect.fromLTWH(102, 813, 130, 125)),
    ArtRegion('16', Rect.fromLTWH(102, 1106, 130, 125)),
    ArtRegion('16', Rect.fromLTWH(102, 1334, 130, 125)),
  ];
}

/// Keeps legacy layout coordinates while painting project-owned CocEnglish art.
/// Source screenshots are research records only and are never loaded by the app.
class ReferenceArt extends StatelessWidget {
  const ReferenceArt(
    this.region, {
    required this.width,
    required this.height,
    this.blendMode = BlendMode.srcOver,
    super.key,
  });
  final ArtRegion region;
  final double width;
  final double height;
  final BlendMode blendMode;
  static Future<void> preload() =>
      Future.wait(CocEnglishMascotPose.values.map((pose) => _load(pose.asset)));

  // Archived region IDs now share three owned poses. Keep callers' preload
  // contract while letting Flutter's bounded image cache own decoded images.
  static Future<void> preloadFiles(Iterable<String> files) =>
      files.isEmpty ? Future.value() : preload();

  static Future<void> _load(String asset) {
    final done = Completer<void>();
    final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronous) {
        info.dispose();
        stream.removeListener(listener);
        if (!done.isCompleted) done.complete();
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        if (!done.isCompleted) done.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    return done.future;
  }

  @override
  Widget build(BuildContext context) {
    if (_isWordmark(region)) return const CocEnglishWordmark();
    if (_isPlanWordmark(region)) {
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(
            'COC PLUS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CocEnglishBrand.teal,
              fontSize: math.min(width / 5, height / 1.8),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }
    final mascotPose = _mascotPose(region);
    if (mascotPose != null) {
      return CocEnglishMascot(width: width, height: height, pose: mascotPose);
    }
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _CocEnglishArtPainter(region, blendMode)),
      ),
    );
  }
}

bool _isWordmark(ArtRegion region) =>
    region == ReferenceArtRegions.wordmark ||
    region == ReferenceArtRegions.splashWordmark;

bool _isPlanWordmark(ArtRegion region) {
  final file = region.file.toLowerCase();
  final source = region.source;
  return (file.contains('max') || file.contains('super')) &&
      source.width / source.height > 2.4 &&
      source.height < 100;
}

CocEnglishMascotPose? _mascotPose(ArtRegion region) {
  final file = region.file.toLowerCase();
  final source = region.source;
  final largeIllustration = source.width >= 260 && source.height >= 210;
  if (!largeIllustration && !file.startsWith('widget-')) return null;
  if (file.contains('result') ||
      file.contains('complete') ||
      file.contains('success') ||
      file.contains('award') ||
      file.contains('achievement') ||
      file.contains('review') ||
      file.contains('promotion')) {
    return CocEnglishMascotPose.celebrate;
  }
  if (file.contains('lesson') ||
      file.contains('guide') ||
      file.contains('course') ||
      file.contains('section') ||
      file.contains('word') ||
      file.contains('unit') ||
      file.contains('learning') ||
      file.contains('book') ||
      file.contains('call')) {
    return CocEnglishMascotPose.study;
  }
  return CocEnglishMascotPose.wave;
}

enum _CocEnglishGlyph {
  book,
  trophy,
  star,
  heart,
  flame,
  gem,
  people,
  gift,
  speech,
  profile,
  compass,
  timer,
  bolt,
  shield,
  bag,
  chart,
  gear,
  microphone,
  globe,
  eye,
}

_CocEnglishGlyph _glyphFor(ArtRegion region) {
  final file = region.file.toLowerCase();
  final source = region.source;
  if (file == 'login-03') {
    if (source.top < 650) return _CocEnglishGlyph.eye;
    if (source.top > 2000) return _CocEnglishGlyph.book;
    if (source.top > 1800) return _CocEnglishGlyph.people;
    return _CocEnglishGlyph.globe;
  }
  if (file == '05') return _CocEnglishGlyph.globe;
  if (file == '09') {
    return switch (((source.top - 785) / 218).round().clamp(0, 6)) {
      0 => _CocEnglishGlyph.book,
      1 => _CocEnglishGlyph.people,
      2 => _CocEnglishGlyph.globe,
      3 => _CocEnglishGlyph.star,
      4 => _CocEnglishGlyph.speech,
      5 => _CocEnglishGlyph.compass,
      _ => _CocEnglishGlyph.trophy,
    };
  }
  if (file == '16') return _CocEnglishGlyph.star;
  if (file == '19') {
    return source.top < 1000 ? _CocEnglishGlyph.book : _CocEnglishGlyph.compass;
  }
  if (file == 'lesson-01' && source.top < 300) {
    if (source.left < 500) return _CocEnglishGlyph.flame;
    if (source.left < 900) return _CocEnglishGlyph.gem;
    return _CocEnglishGlyph.heart;
  }
  if (file.contains('heart') || file.contains('streak-protection')) {
    return _CocEnglishGlyph.heart;
  }
  if (file.contains('streak') || file.contains('flame')) {
    return _CocEnglishGlyph.flame;
  }
  if (file.contains('achievement') ||
      file.contains('league') ||
      file.contains('medal') ||
      file.contains('trophy') ||
      file.contains('award')) {
    return _CocEnglishGlyph.trophy;
  }
  if (file.contains('gem') ||
      file.contains('super') ||
      file.contains('max') ||
      file.contains('premium')) {
    return _CocEnglishGlyph.gem;
  }
  if (file.contains('gift') || file.contains('chest')) {
    return _CocEnglishGlyph.gift;
  }
  if (file.contains('shop') || file.contains('store')) {
    return _CocEnglishGlyph.bag;
  }
  if (file.contains('friend') ||
      file.contains('profile') ||
      file.contains('feed') ||
      file.contains('family')) {
    return _CocEnglishGlyph.people;
  }
  if (file.contains('call') ||
      file.contains('roleplay') ||
      file.contains('status') ||
      file.contains('radio')) {
    return _CocEnglishGlyph.speech;
  }
  if (file.contains('score') || file.contains('xp')) {
    return _CocEnglishGlyph.chart;
  }
  if (file.contains('energy') || file.contains('boost')) {
    return _CocEnglishGlyph.bolt;
  }
  if (file.contains('timer')) return _CocEnglishGlyph.timer;
  if (file.contains('delete') || file.contains('protect')) {
    return _CocEnglishGlyph.shield;
  }
  if (file.contains('setting')) return _CocEnglishGlyph.gear;
  if (file.contains('story')) return _CocEnglishGlyph.book;
  if (file.contains('adventure') || file.contains('compass')) {
    return _CocEnglishGlyph.compass;
  }
  if (file.contains('lesson') ||
      file.contains('course') ||
      file.contains('section') ||
      file.contains('guide') ||
      file.contains('word') ||
      file.contains('unit') ||
      file.contains('explain')) {
    return _CocEnglishGlyph.book;
  }
  if (file.contains('signup') || file.contains('login')) {
    return _CocEnglishGlyph.profile;
  }
  if (file.contains('quest') || file.contains('result')) {
    return _CocEnglishGlyph.star;
  }
  if (file == '15') return _CocEnglishGlyph.timer;
  if (file == '20') return _CocEnglishGlyph.book;
  return _CocEnglishGlyph.speech;
}

class _CocEnglishArtPainter extends CustomPainter {
  const _CocEnglishArtPainter(this.region, this.blendMode);

  final ArtRegion region;
  final BlendMode blendMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.saveLayer(Offset.zero & size, Paint()..blendMode = blendMode);
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final backgroundPaint = Paint()..color = CocEnglishBrand.surface;
    if (side >= 42) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: side * .9, height: side * .9),
          Radius.circular(side * .25),
        ),
        backgroundPaint,
      );
      canvas.drawCircle(
        center + Offset(side * .31, -side * .29),
        side * .075,
        Paint()..color = const Color(0xFFFFCF5A),
      );
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final iconSize = side * (side < 30 ? .9 : .59);
    canvas.scale(iconSize / 100);
    _paintGlyph(canvas, _glyphFor(region));
    canvas.restore();
    canvas.restore();
  }

  void _paintGlyph(Canvas canvas, _CocEnglishGlyph glyph) {
    final ink = Paint()
      ..color = CocEnglishBrand.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final orange = Paint()..color = CocEnglishBrand.orange;
    final teal = Paint()..color = CocEnglishBrand.teal;
    final cream = Paint()..color = const Color(0xFFFFFDF8);
    final gold = Paint()..color = const Color(0xFFFFC744);
    final path = Path();

    switch (glyph) {
      case _CocEnglishGlyph.book:
        path
          ..moveTo(-43, -34)
          ..quadraticBezierTo(-20, -42, 0, -29)
          ..quadraticBezierTo(20, -42, 43, -34)
          ..lineTo(43, 36)
          ..quadraticBezierTo(19, 27, 0, 42)
          ..quadraticBezierTo(-19, 27, -43, 36)
          ..close();
        canvas.drawPath(path, cream);
        canvas.drawPath(path, ink);
        canvas.drawLine(const Offset(0, -29), const Offset(0, 40), ink);
        canvas.drawLine(const Offset(-32, -16), const Offset(-11, -11), ink);
        canvas.drawLine(const Offset(11, -11), const Offset(32, -16), ink);
      case _CocEnglishGlyph.trophy:
        path
          ..moveTo(-27, -38)
          ..lineTo(27, -38)
          ..lineTo(22, -5)
          ..quadraticBezierTo(19, 15, 0, 20)
          ..quadraticBezierTo(-19, 15, -22, -5)
          ..close();
        canvas.drawPath(path, gold);
        canvas.drawPath(path, ink);
        canvas.drawArc(
          const Rect.fromLTWH(-43, -35, 25, 38),
          math.pi / 2,
          math.pi,
          false,
          ink,
        );
        canvas.drawArc(
          const Rect.fromLTWH(18, -35, 25, 38),
          -math.pi / 2,
          math.pi,
          false,
          ink,
        );
        canvas.drawLine(const Offset(0, 20), const Offset(0, 35), ink);
        canvas.drawLine(const Offset(-19, 37), const Offset(19, 37), ink);
        _star(canvas, gold, ink);
      case _CocEnglishGlyph.star:
        _star(canvas, gold, ink);
      case _CocEnglishGlyph.heart:
        path
          ..moveTo(0, 39)
          ..cubicTo(-12, 28, -39, 7, -39, -12)
          ..cubicTo(-39, -35, -11, -42, 0, -21)
          ..cubicTo(11, -42, 39, -35, 39, -12)
          ..cubicTo(39, 7, 12, 28, 0, 39)
          ..close();
        canvas.drawPath(path, orange);
        canvas.drawPath(path, ink);
        canvas.drawCircle(const Offset(-12, -15), 5, cream);
      case _CocEnglishGlyph.flame:
        path
          ..moveTo(2, 42)
          ..cubicTo(-26, 42, -39, 22, -31, 1)
          ..cubicTo(-26, -13, -15, -22, -12, -42)
          ..cubicTo(7, -26, 12, -13, 8, -2)
          ..cubicTo(22, -12, 24, -23, 21, -30)
          ..cubicTo(47, -8, 40, 20, 24, 33)
          ..cubicTo(18, 39, 10, 42, 2, 42)
          ..close();
        canvas.drawPath(path, orange);
        canvas.drawPath(path, ink);
        final inner = Path()
          ..moveTo(1, 28)
          ..cubicTo(-11, 20, -11, 8, -3, -2)
          ..cubicTo(0, 7, 11, 9, 10, 18)
          ..cubicTo(10, 23, 6, 27, 1, 28)
          ..close();
        canvas.drawPath(inner, gold);
      case _CocEnglishGlyph.gem:
        path
          ..moveTo(-39, -19)
          ..lineTo(-22, -37)
          ..lineTo(22, -37)
          ..lineTo(39, -19)
          ..lineTo(0, 40)
          ..close();
        canvas.drawPath(path, teal);
        canvas.drawPath(path, ink);
        canvas.drawLine(const Offset(-22, -37), const Offset(-14, -16), ink);
        canvas.drawLine(const Offset(22, -37), const Offset(14, -16), ink);
        canvas.drawLine(const Offset(-39, -19), const Offset(39, -19), ink);
        canvas.drawLine(const Offset(0, -19), const Offset(0, 38), ink);
      case _CocEnglishGlyph.people:
        canvas.drawCircle(const Offset(0, -22), 15, gold);
        canvas.drawCircle(const Offset(-29, -9), 12, orange);
        canvas.drawCircle(const Offset(29, -9), 12, teal);
        canvas.drawCircle(const Offset(0, -22), 15, ink);
        canvas.drawCircle(const Offset(-29, -9), 12, ink);
        canvas.drawCircle(const Offset(29, -9), 12, ink);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-22, 0, 44, 38),
            const Radius.circular(18),
          ),
          orange,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-22, 0, 44, 38),
            const Radius.circular(18),
          ),
          ink,
        );
        canvas.drawArc(
          const Rect.fromLTWH(-48, 3, 30, 32),
          math.pi,
          math.pi,
          false,
          ink,
        );
        canvas.drawArc(
          const Rect.fromLTWH(18, 3, 30, 32),
          math.pi,
          math.pi,
          false,
          ink,
        );
      case _CocEnglishGlyph.gift:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-34, -9, 68, 47),
            const Radius.circular(6),
          ),
          teal,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-34, -9, 68, 47),
            const Radius.circular(6),
          ),
          ink,
        );
        canvas.drawRect(const Rect.fromLTWH(-39, -17, 78, 13), orange);
        canvas.drawRect(const Rect.fromLTWH(-39, -17, 78, 13), ink);
        canvas.drawRect(const Rect.fromLTWH(-5, -16, 10, 53), gold);
        canvas.drawRect(const Rect.fromLTWH(-5, -16, 10, 53), ink);
        canvas.drawOval(const Rect.fromLTWH(-26, -40, 24, 22), gold);
        canvas.drawOval(const Rect.fromLTWH(2, -40, 24, 22), gold);
        canvas.drawArc(
          const Rect.fromLTWH(-27, -41, 26, 24),
          math.pi,
          math.pi,
          false,
          ink,
        );
        canvas.drawArc(
          const Rect.fromLTWH(1, -41, 26, 24),
          math.pi,
          math.pi,
          false,
          ink,
        );
      case _CocEnglishGlyph.speech:
        path
          ..moveTo(-35, -31)
          ..quadraticBezierTo(-35, -40, -25, -40)
          ..lineTo(25, -40)
          ..quadraticBezierTo(35, -40, 35, -30)
          ..lineTo(35, 9)
          ..quadraticBezierTo(35, 19, 25, 19)
          ..lineTo(2, 19)
          ..lineTo(-20, 39)
          ..lineTo(-18, 19)
          ..lineTo(-25, 19)
          ..quadraticBezierTo(-35, 19, -35, 9)
          ..close();
        canvas.drawPath(path, teal);
        canvas.drawPath(path, ink);
        for (var x = -14.0; x <= 14; x += 14) {
          canvas.drawCircle(Offset(x, -10), 3.5, cream);
        }
      case _CocEnglishGlyph.profile:
        canvas.drawCircle(const Offset(0, -19), 20, orange);
        canvas.drawCircle(const Offset(0, -19), 20, ink);
        path
          ..moveTo(-36, 37)
          ..quadraticBezierTo(-36, 1, 0, 1)
          ..quadraticBezierTo(36, 1, 36, 37)
          ..close();
        canvas.drawPath(path, teal);
        canvas.drawPath(path, ink);
      case _CocEnglishGlyph.compass:
        canvas.drawCircle(const Offset(0, 0), 39, cream);
        canvas.drawCircle(const Offset(0, 0), 39, ink);
        path
          ..moveTo(18, -22)
          ..lineTo(-3, 4)
          ..lineTo(-19, 25)
          ..lineTo(3, -5)
          ..close();
        canvas.drawPath(path, orange);
        canvas.drawPath(path, ink);
        canvas.drawCircle(Offset.zero, 4, gold);
      case _CocEnglishGlyph.timer:
        canvas.drawCircle(const Offset(0, 3), 36, cream);
        canvas.drawCircle(const Offset(0, 3), 36, ink);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-12, -44, 24, 10),
            const Radius.circular(5),
          ),
          orange,
        );
        canvas.drawLine(const Offset(0, 3), const Offset(0, -21), ink);
        canvas.drawLine(const Offset(0, 3), const Offset(19, 13), ink);
        canvas.drawCircle(const Offset(0, 3), 5, teal);
      case _CocEnglishGlyph.bolt:
        path
          ..moveTo(8, -43)
          ..lineTo(-25, 4)
          ..lineTo(-4, 4)
          ..lineTo(-11, 43)
          ..lineTo(26, -7)
          ..lineTo(5, -7)
          ..close();
        canvas.drawPath(path, gold);
        canvas.drawPath(path, ink);
      case _CocEnglishGlyph.shield:
        path
          ..moveTo(0, -42)
          ..lineTo(35, -28)
          ..lineTo(30, 8)
          ..quadraticBezierTo(24, 31, 0, 43)
          ..quadraticBezierTo(-24, 31, -30, 8)
          ..lineTo(-35, -28)
          ..close();
        canvas.drawPath(path, teal);
        canvas.drawPath(path, ink);
        canvas.drawLine(const Offset(-16, 0), const Offset(-3, 14), cream);
        canvas.drawLine(const Offset(-3, 14), const Offset(18, -12), cream);
      case _CocEnglishGlyph.bag:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-34, -23, 68, 61),
            const Radius.circular(9),
          ),
          orange,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-34, -23, 68, 61),
            const Radius.circular(9),
          ),
          ink,
        );
        canvas.drawArc(
          const Rect.fromLTWH(-17, -42, 34, 40),
          math.pi,
          math.pi,
          false,
          ink,
        );
        canvas.drawCircle(Offset.zero, 7, gold);
      case _CocEnglishGlyph.chart:
        canvas.drawLine(const Offset(-37, 36), const Offset(-37, -35), ink);
        canvas.drawLine(const Offset(-37, 36), const Offset(39, 36), ink);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-24, 7, 15, 29),
            const Radius.circular(5),
          ),
          orange,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, -11, 15, 47),
            const Radius.circular(5),
          ),
          teal,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(24, -30, 15, 66),
            const Radius.circular(5),
          ),
          gold,
        );
      case _CocEnglishGlyph.gear:
        canvas.drawCircle(const Offset(0, 0), 29, teal);
        canvas.drawCircle(const Offset(0, 0), 29, ink);
        canvas.drawCircle(const Offset(0, 0), 11, cream);
        canvas.drawCircle(const Offset(0, 0), 11, ink);
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final start = Offset(math.cos(angle) * 32, math.sin(angle) * 32);
          final end = Offset(math.cos(angle) * 42, math.sin(angle) * 42);
          canvas.drawLine(start, end, ink);
        }
      case _CocEnglishGlyph.microphone:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-12, -40, 24, 48),
            const Radius.circular(12),
          ),
          orange,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-12, -40, 24, 48),
            const Radius.circular(12),
          ),
          ink,
        );
        canvas.drawArc(
          const Rect.fromLTWH(-27, -18, 54, 51),
          0,
          math.pi,
          false,
          ink,
        );
        canvas.drawLine(const Offset(0, 33), const Offset(0, 44), ink);
        canvas.drawLine(const Offset(-14, 44), const Offset(14, 44), ink);
      case _CocEnglishGlyph.globe:
        canvas.drawCircle(const Offset(0, 0), 38, teal);
        canvas.drawCircle(const Offset(0, 0), 38, ink);
        canvas.drawOval(const Rect.fromLTWH(-17, -38, 34, 76), ink);
        canvas.drawLine(const Offset(-35, -14), const Offset(35, -14), ink);
        canvas.drawLine(const Offset(-37, 12), const Offset(37, 12), ink);
      case _CocEnglishGlyph.eye:
        path
          ..moveTo(-42, 0)
          ..quadraticBezierTo(0, -37, 42, 0)
          ..quadraticBezierTo(0, 37, -42, 0)
          ..close();
        canvas.drawPath(path, cream);
        canvas.drawPath(path, ink);
        canvas.drawCircle(Offset.zero, 15, teal);
        canvas.drawCircle(Offset.zero, 7, ink);
    }
  }

  void _star(Canvas canvas, Paint fill, Paint outline) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final radius = i.isEven ? 42.0 : 19.0;
      final point = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);
  }

  @override
  bool shouldRepaint(_CocEnglishArtPainter oldDelegate) =>
      oldDelegate.region != region || oldDelegate.blendMode != blendMode;
}
