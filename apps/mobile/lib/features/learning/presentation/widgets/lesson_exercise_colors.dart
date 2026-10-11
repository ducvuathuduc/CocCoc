import 'package:flutter/material.dart';

/// Colors sampled from docs/design/references/lesson/*.png
/// (docs/design/qa/palette_from_refs.json per_screen entries).
abstract final class LessonExerciseColors {
  // lesson/10.png, 11.png
  static const ink = Color(0xFF4B4B4B);
  static const audioBlue = Color(0xFF1CB0F6);
  static const disabledText = Color(0xFFAFAFAF);
  static const tileBorder = Color(0xFFE5E5E5);
  // lesson/06.png
  static const matchedFill = Color(0xFFD6FFB8);
  static const matchedBorder = Color(0xFFA5ED6E);
  static const matchedText = Color(0xFF58A700);
  // lesson/09.png
  static const wrongFill = Color(0xFFFFDFE0);
  static const wrongBorder = Color(0xFFFF4B4B);
  static const wrongText = Color(0xFFEA2B2B);
  // lesson/11.png
  static const skipFill = Color(0xFFFFF5D3);
  static const skipTitle = Color(0xFFCD7900);
  static const skipButton = Color(0xFFFFC700);
  static const skipEdge = Color(0xFFE7A601);
  // lesson/08.png: barrier renders #999999 over white (black at 40%).
  static const barrier = Color(0x66000000);
  static const sheetHandle = Color(0xFFAFAFAF);
  static const keepGoing = Color(0xFF1CB0F6);
  static const keepGoingEdge = Color(0xFF1899D6);
}
