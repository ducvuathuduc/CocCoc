import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class CocEnglishBrand {
  static const orange = Color(0xFFF47721);
  // Dark enough for white labels while staying in the mascot's orange family.
  static const actionOrange = Color(0xFFC84E08);
  static const actionOrangeEdge = Color(0xFF963A00);
  static const surface = Color(0xFFFFF7EF);
  static const teal = Color(0xFF008F8C);
  static const ink = Color(0xFF21314A);
}

enum CocEnglishMascotPose { wave, study, celebrate }

extension CocEnglishMascotAsset on CocEnglishMascotPose {
  String get asset => switch (this) {
    CocEnglishMascotPose.wave => 'assets/brand/cocenglish-mascot-wave.png',
    CocEnglishMascotPose.study => 'assets/brand/cocenglish-mascot-study.png',
    CocEnglishMascotPose.celebrate =>
      'assets/brand/cocenglish-mascot-celebrate.png',
  };
}

class CocEnglishMark extends StatelessWidget {
  const CocEnglishMark({this.size = 144, super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/cocenglish-mark.svg',
    width: size,
    height: size,
    semanticsLabel: 'CocEnglish logo',
  );
}

class CocEnglishWordmark extends StatelessWidget {
  const CocEnglishWordmark({super.key});

  @override
  Widget build(BuildContext context) => const Text(
    'CocEnglish',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: 'sans-serif',
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      color: CocEnglishBrand.orange,
    ),
  );
}

/// Fits the replacement into the original illustration's layout bounds.
class CocEnglishMascot extends StatelessWidget {
  const CocEnglishMascot({
    required this.width,
    required this.height,
    this.pose = CocEnglishMascotPose.wave,
    this.semanticsLabel,
    super.key,
  });
  final double width, height;
  final CocEnglishMascotPose pose;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Center(
      child: Image.asset(
        pose.asset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        excludeFromSemantics: semanticsLabel == null,
        semanticLabel: semanticsLabel,
      ),
    ),
  );
}
