import 'package:flutter/material.dart';

abstract final class ReferenceColors {
  static const surface = Color(0xFFFFFDFE);
  static const ink = Color(0xFF4D4B4E);
  static const muted = Color(0xFF807E80);
  static const border = Color(0xFFE7E5E7);
  static const disabled = Color(0xFFB0AEB0);
  static const green = Color(0xFF5BCD05);
  static const greenEdge = Color(0xFF58A700);
  static const blue = Color(0xFF20A2CF);
  static const blueBorder = Color(0xFF89DBF6);
  static const blueFill = Color(0xFFE1F4FF);
  static const purple = Color(0xFF9861FF);
}

/// Calibrated from the archived CHECK/CONTINUE control crops, not source code.
abstract final class ReferenceButtonTokens {
  static const minimumTarget = 48.0;
  static const labelTracking = 1.3;
}

/// Archived flows have different palettes; a new capture must opt in without
/// recoloring existing screens. Lesson colors are sampled from sc_b7f6add9
/// and sc_ceb894f1, with coordinates recorded in specs/exercises-i1.md.
class ReferenceButtonPalette {
  const ReferenceButtonPalette({
    required this.surface,
    required this.border,
    required this.disabled,
    required this.green,
    required this.labelTracking,
  });

  static const legacy = ReferenceButtonPalette(
    surface: ReferenceColors.surface,
    border: ReferenceColors.border,
    disabled: ReferenceColors.disabled,
    green: ReferenceColors.green,
    labelTracking: .8,
  );
  static const lesson = ReferenceButtonPalette(
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE5E5E5),
    disabled: Color(0xFFAFAFAF),
    green: Color(0xFF58CC02),
    labelTracking: ReferenceButtonTokens.labelTracking,
  );
  // sc_5b3164cb only shows disabled CHECK. Its enabled action is UNKNOWN;
  // retain the existing green until an enabled text-match source is admitted.
  static const textMatch = ReferenceButtonPalette(
    surface: Color(0xFFFEFCFE),
    border: Color(0xFFE7E5E7),
    disabled: Color(0xFFB3B0B3),
    green: ReferenceColors.green,
    labelTracking: .8,
  );

  final Color surface, border, disabled, green;
  final double labelTracking;
}

ThemeData referenceTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'DuolingoSans',
  scaffoldBackgroundColor: ReferenceColors.surface,
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: ReferenceColors.surface,
    surfaceTintColor: Colors.transparent,
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: ReferenceColors.green,
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
