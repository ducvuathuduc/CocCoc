import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class CocEnglishBrand {
  static const orange = Color(0xFFF47721);
  static const surface = Color(0xFFFFF7EF);
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
    super.key,
  });
  final double width, height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Center(child: CocEnglishMark(size: width < height ? width : height)),
  );
}
