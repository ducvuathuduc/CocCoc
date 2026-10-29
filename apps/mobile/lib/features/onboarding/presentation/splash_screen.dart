import 'package:flutter/material.dart';

import '../../../core/design/cocenglish_brand.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: CocEnglishBrand.surface,
    body: SafeArea(
      child: Column(
        children: [
          const Expanded(child: Center(child: CocEnglishMark(size: 192))),
          const CocEnglishWordmark(),
          SizedBox(height: MediaQuery.sizeOf(context).height * .07),
        ],
      ),
    ),
  );
}
