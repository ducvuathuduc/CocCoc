import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../domain/results_models.dart';

/// Colors sampled (PIL getpixel) from docs/design/references/results/*.png;
/// every value is listed in docs/design/qa/palette_from_refs.json.
abstract final class ResultsColors {
  static const surface = Color(0xFFFFFDFE); // 11 (400,945)
  static const ink = Color(0xFF4D4B4E); // 11 title glyphs
  static const border = Color(0xFFE7E5E7); // 11 card stroke / track
  static const divider = Color(0xFFFBF8FA); // 11 (600,1155)
  static const muted = Color(0xFF989598); // 13 muted glyph
  static const trackText = Color(0xFFB2AFB2); // 13 inactive label
  static const blue = Color(0xFF1DB2FB); // 04 "+50 gems", buttons
  static const blueEdge = Color(0xFF189ADA); // 11 button edge
  static const quest = Color(0xFFCF3591); // 11 (300,1060)
  static const questGleam = Color(0xFFD95DA7); // 11 (300,1045)
  static const promotion = Color(0xFF5AA701); // 12 (350,1040) / 01 palette
  static const userRow = Color(0xFFE8E6E9); // 12 (1000,1250)
  static const rankInk = Color(0xFF4C4A4D); // 12 (120,1250)
  static const avatarPurple = Color(0xFFD082FF); // 12 "W" avatar
  static const avatarOrange = Color(0xFFFF9702); // 12 "M" avatar
  static const streakBackground = Color(0xFFFF9601); // 05 background
  static const streakWhite = Color(0xFFFFFEFE); // 05 (600,2160)
  static const streakDone = Color(0xFFFEE76D); // 05 (140,1740)
  static const streakCheck = Color(0xFFFB9807); // 05 check glyph
  static const streakMissed = Color(0xFFCF6E08); // 05 (890,1760)
  static const streakNumeralTop = Color(0xFFFFF6B9); // 05 (590,1050)
  static const streakShareEdge = Color(0xFFFFE0B3); // 05 (600,2230)
  static const orange = Color(0xFFFF9601); // 07/09 flame, 09 title
  static const bubbleBorder = Color(0xFFE7E5E7); // 07 bubble stroke
  static const questTrack = Color(0xFF6F8BBB); // 10 (800,1520)
  static const questFill = Color(0xFFCF3591); // 10 (400,1520)
  static const questBarText = Color(0xFFFFFEFF); // 10 bar label
  static const bannerEdge = Color(0xFF178EC8); // 13 banner lip
  static const bannerDivider = Color(0xFF27AFF2); // 13 (946,400)
  static const navDivider = Color(0xFFE7E5E7); // 13 (590,2272)
  static const statInk = Color(0xFF989598); // 13 course level glyph
}

/// Graphics-only crops of results references; copy stays in data.
abstract final class ResultsArt {
  static const trophy = ArtRegion(
    'results-12',
    Rect.fromLTWH(476, 220, 228, 312),
  );
  static const promotionArrow = ArtRegion(
    'results-12',
    Rect.fromLTWH(253, 1010, 56, 52),
  );
  static const flagFr = ArtRegion(
    'results-12',
    Rect.fromLTWH(386, 1266, 58, 46),
  );
  static const flagUs = ArtRegion(
    'results-12',
    Rect.fromLTWH(386, 1506, 58, 46),
  );
  static const avatars = {
    'alex': ArtRegion('results-12', Rect.fromLTWH(180, 1145, 202, 185)),
    'yumeka': ArtRegion('results-12', Rect.fromLTWH(180, 1385, 202, 185)),
    'kk': ArtRegion('results-12', Rect.fromLTWH(180, 1625, 202, 185)),
  };
  static const questOpened = ArtRegion(
    'results-11',
    Rect.fromLTWH(912, 925, 134, 182),
  );
  static const questLocked = ArtRegion(
    'results-11',
    Rect.fromLTWH(912, 1364, 134, 124),
  );
  static const questGold = ArtRegion(
    'results-11',
    Rect.fromLTWH(912, 1676, 134, 124),
  );
  static const gem = ArtRegion('results-11', Rect.fromLTWH(955, 220, 72, 84));
  static const flameDuo = ArtRegion(
    'results-05',
    Rect.fromLTWH(368, 383, 478, 542),
  );
  static const shareChest = ArtRegion(
    'results-05',
    Rect.fromLTWH(340, 2125, 74, 70),
  );
  static const gemChest = ArtRegion(
    'results-04',
    Rect.fromLTWH(308, 822, 564, 542),
  );

  // results/07: calendar + Duo goal illustration.
  static const streakGoal = ArtRegion(
    'results-07',
    Rect.fromLTWH(236, 1000, 784, 738),
  );
  // results/08: widget preview cards (previous, current, next).
  static const widgetCards = {
    WidgetCardState.previous: ArtRegion(
      'results-08',
      Rect.fromLTWH(0, 1180, 272, 438),
    ),
    WidgetCardState.current: ArtRegion(
      'results-08',
      Rect.fromLTWH(328, 1137, 524, 523),
    ),
    WidgetCardState.next: ArtRegion(
      'results-08',
      Rect.fromLTWH(909, 1181, 271, 434),
    ),
  };
  // results/09: paired friend avatars and the small streak flame.
  static const friendAvatars = ArtRegion(
    'results-09',
    Rect.fromLTWH(295, 1157, 586, 347),
  );
  static const friendFlame = ArtRegion(
    'results-09',
    Rect.fromLTWH(480, 1574, 102, 82),
  );
  // results/10: friends-quest stage (the progress bar is drawn natively on top).
  static const friendsQuest = ArtRegion(
    'results-10',
    Rect.fromLTWH(149, 423, 882, 1187),
  );
  static const friendsQuestGem = ArtRegion(
    'results-10',
    Rect.fromLTWH(958, 222, 54, 80),
  );
  static const boostGem = ArtRegion(
    'results-10',
    Rect.fromLTWH(720, 2130, 50, 60),
  );
  // results/13: path return.
  static const statFlag = ArtRegion(
    'results-13',
    Rect.fromLTWH(76, 216, 92, 74),
  );
  static const statFlame = ArtRegion(
    'results-13',
    Rect.fromLTWH(379, 216, 62, 74),
  );
  static const statGem = ArtRegion(
    'results-13',
    Rect.fromLTWH(621, 216, 60, 74),
  );
  static const statEnergy = ArtRegion(
    'results-13',
    Rect.fromLTWH(914, 216, 162, 74),
  );
  static const bannerGuide = ArtRegion(
    'results-13',
    Rect.fromLTWH(960, 345, 140, 250),
  );
  static const path = ArtRegion(
    'results-13',
    Rect.fromLTWH(0, 663, 1180, 1606),
  );
  static const nav = ArtRegion('results-13', Rect.fromLTWH(0, 2296, 1180, 180));

  static const files = ['results-04', 'results-05', 'results-11', 'results-12'];

  /// Sources for results/07–10 and 13. Kept separate: each source is ~12 MB
  /// decoded, so preloading all nine at once overflows the image cache.
  static const extraFiles = [
    'results-07',
    'results-08',
    'results-09',
    'results-10',
    'results-13',
  ];
}

/// Duolingo-like motion timings for result screens (ms).
abstract final class ResultsMotion {
  static const stagger = 90;
  static const slide = 320;
  static const fill = 650;
  static const chest = 900;
  static const curve = Curves.easeOutCubic;
}
