import 'package:flutter/material.dart';

import 'cocenglish_brand.dart';

abstract final class ReferenceColors {
  static const surface = Color(0xFFFFFDFE);
  static const ink = Color(0xFF4D4B4E);
  static const muted = Color(0xFF807E80);
  static const border = Color(0xFFE7E5E7);
  static const disabled = Color(0xFFB0AEB0);
  static const primary = CocEnglishBrand.actionOrange;
  static const primaryEdge = CocEnglishBrand.actionOrangeEdge;
  // Legacy aliases retained for tests and older feature code.
  static const green = primary;
  static const greenEdge = primaryEdge;
  static const blue = Color(0xFF20A2CF);
  static const blueBorder = Color(0xFF89DBF6);
  static const blueFill = Color(0xFFE1F4FF);
  static const purple = Color(0xFF9861FF);
}

ThemeData referenceTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'sans-serif',
  scaffoldBackgroundColor: ReferenceColors.surface,
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: ReferenceColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: ReferenceColors.primary,
    surface: ReferenceColors.surface,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(
      fontSize: 20,
      color: ReferenceColors.ink,
      height: 1.35,
    ),
  ),
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
);
