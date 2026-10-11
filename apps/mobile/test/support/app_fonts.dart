import 'package:flutter/services.dart';

/// Loads the app's bundled fonts (DuolingoSans, Feather) plus Material icons
/// so goldens render real glyphs instead of Ahem boxes.
Future<void> loadAppFonts() async {
  await (FontLoader('DuolingoSans')
        ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
        ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
      .load();
  await (FontLoader(
    'Feather',
  )..addFont(rootBundle.load('assets/fonts/Feather.ttf'))).load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
