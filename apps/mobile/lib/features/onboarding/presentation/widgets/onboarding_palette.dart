import 'package:flutter/painting.dart';

/// Onboarding-only colors, each pixel-sampled from
/// docs/design/references/onboarding (1180px wide) and present in
/// docs/design/qa/palette_from_refs.json.
abstract final class OnboardingPalette {
  /// 10.png checkbox fill (950-1080, 800-900); 17.png badge.
  static const checkBlue = Color(0xFF1DB2FB);

  /// 08.png filled level bars (100-190, 1220-1300).
  static const barFilled = Color(0xFF1B9AD7);

  /// 08.png empty level bars, unselected row (100-190, 790-880).
  static const barEmpty = Color(0xFFD4EBFB);

  /// 08.png empty level bars, selected row (100-190, 1000-1090).
  static const barEmptySelected = Color(0xFFBBE3FA);

  /// 14.png notification sheet background (160-1000, 1020-1400).
  static const sheet = Color(0xFFFAF7FB);

  /// 14.png "Allow" label (600-1000, 1440-1560).
  static const allow = Color(0xFF33ACE7);

  /// 14.png pointer arrow (700-800, 1600-1780).
  static const arrow = Color(0xFF7CD1FC);
}
