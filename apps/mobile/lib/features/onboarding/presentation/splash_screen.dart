import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF7BC900),
    body: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned(
            top: constraints.maxHeight * .486 - 57.5,
            left: (constraints.maxWidth - 172) / 2,
            child: const ReferenceArt(
              ReferenceArtRegions.splashFace,
              width: 172,
              height: 115,
            ),
          ),
          Positioned(
            bottom: constraints.maxHeight * .0708,
            left: (constraints.maxWidth - 185) / 2,
            child: const ReferenceArt(
              ReferenceArtRegions.splashWordmark,
              width: 185,
              height: 50,
            ),
          ),
        ],
      ),
    ),
  );
}
