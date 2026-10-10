import 'package:flutter/material.dart';
import '../../../core/design/reference_art.dart';

abstract final class QuestArt {
  /// Bronze locked chest from quests-06 daily quests
  static const chestBronze = ArtRegion(
    'quests-06',
    Rect.fromLTWH(950, 1511, 158, 122),
  );

  /// Silver ready/open chest from quests-06 daily quests
  static const chestSilver = ArtRegion(
    'quests-06',
    Rect.fromLTWH(951, 1750, 156, 160),
  );

  /// Gold locked chest from quests-06 daily quests
  static const chestGold = ArtRegion(
    'quests-06',
    Rect.fromLTWH(950, 2039, 158, 122),
  );

  /// Ice block sculpture banner from quests-05 weekend quest
  static const weekendBanner = ArtRegion(
    'quests-05',
    Rect.fromLTWH(72, 946, 1035, 430),
  );

  /// Waving hand icon from quests-03 NUDGE button
  static const nudge = ArtRegion(
    'quests-03',
    Rect.fromLTWH(185, 1903, 82, 84),
  );

  /// Gift box icon from quests-03 GIFT button
  static const gift = ArtRegion(
    'quests-03',
    Rect.fromLTWH(754, 1908, 84, 75),
  );

  /// High five hand icon from quests-04 HIGH FIVED ALEX! button
  static const highFive = ArtRegion(
    'quests-04',
    Rect.fromLTWH(329, 1914, 91, 71),
  );

  /// Singer badge ROI on monthly challenge intro screen
  static const singerIntro = ArtRegion(
    'quests-02',
    Rect.fromLTWH(276, 731, 620, 665),
  );

  /// Singer character in top header of quests screen
  static const singerHeader = ArtRegion(
    'quests-03',
    Rect.fromLTWH(775, 155, 300, 256),
  );

  /// Friends quest illustration banner (Duo between friends)
  static const friendsBanner = ArtRegion(
    'quests-03',
    Rect.fromLTWH(76, 956, 1030, 376),
  );

  /// Friends quest illustration banner completed (Duo celebrating) from quests-04
  static const friendsBannerCompleted = ArtRegion(
    'quests-04',
    Rect.fromLTWH(76, 956, 1030, 376),
  );
}
