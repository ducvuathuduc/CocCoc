import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';

/// Colours sampled (PIL getpixel) from docs/design/references/call/*.png;
/// every value is listed in docs/design/qa/palette_from_refs.json.
abstract final class CallColors {
  static const night = Color(0xFF020002); // 03 (120,1200)
  static const dock = Color(0xFF141F26); // 04 (590,2150)
  static const hangUp = Color(0xFFFF4A4D); // 03 / 04 (590,2220)
  static const hangUpEdge = Color(0xFFCE3C3D); // closest ref to 04 (590,2370)
  static const cyan = Color(0xFF38F0FF); // 03 ring
  static const glowStart = Color(0xFF75F5FF); // 06 (60,2330)
  static const glowEnd = Color(0xFF34F2CF); // 07 palette
  static const bubble = Color(0xFF19343B); // 07 (240,470)
  static const bubbleBorder = Color(0xFF1F5A63); // 07 (1030,776)
  static const divider = Color(0xFF245861); // 07 (600,2232)
  static const lily = Color(0xFFA971FF); // 07 (80,530) / 09 headline
  static const white = Color(0xFFFFFEFF); // 07 text
  static const phoneFrame = Color(0xFF35424F); // 09 (244,600)
  static const phoneScreen = Color(0xFF171F29); // 09 (256,600)
  static const buttonEdge = Color(0xFFCFCCCF); // 09 (300,2232)
  static const introGreen = Color(0xFF02CEA0); // 02 card
  static const introEdge = Color(0xFF01A47F); // 02 card edge
  static const introSurface = Color(0xFFFFFDFE); // 02 button
}

/// Durations/curves for the call flow (Duolingo-like, snappy).
abstract final class CallMotion {
  static const page = Duration(milliseconds: 320);
  static const pulse = Duration(milliseconds: 1600);
  static const press = Duration(milliseconds: 110);
  static const caption = Duration(milliseconds: 260);
  static const wave = Duration(milliseconds: 700);
  static const pageCurve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Illustration crops from the call references (graphics only, no text).
abstract final class CallArt {
  static const ringingAvatar = ArtRegion(
    'call-03',
    Rect.fromLTWH(339, 1014, 515, 528),
  );
  static const earnedAvatar = ArtRegion(
    'call-06',
    Rect.fromLTWH(371, 903, 454, 465),
  );
  static const maxWordmark = ArtRegion(
    'call-03',
    Rect.fromLTWH(368, 354, 445, 237),
  );
  static const videoTalking = ArtRegion(
    'call-04',
    Rect.fromLTWH(39, 140, 1102, 1992),
  );
  static const videoListening = ArtRegion(
    'call-05',
    Rect.fromLTWH(39, 140, 1102, 1992),
  );
  static const reviewAvatar = ArtRegion(
    'call-07',
    Rect.fromLTWH(48, 453, 112, 107),
  );
  static const maxBadge = ArtRegion(
    'call-09',
    Rect.fromLTWH(903, 201, 205, 72),
  );
  static const phoneFace = ArtRegion(
    'call-10',
    Rect.fromLTWH(256, 700, 668, 950),
  );

  static const files = [
    'call-03',
    'call-04',
    'call-05',
    'call-06',
    'call-07',
    'call-09',
    'call-10',
  ];
}
