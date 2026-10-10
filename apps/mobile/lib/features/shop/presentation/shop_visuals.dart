import 'package:flutter/material.dart';
import '../../../core/design/reference_art.dart';

abstract final class ShopArt {
  // Max subscriber banner
  static const maxBanner = ArtRegion('shop-02', Rect.fromLTWH(775, 425, 290, 300));
  
  // My Items
  static const xpBoost = ArtRegion('shop-02', Rect.fromLTWH(181, 1255, 180, 232));
  static const streakFreeze = ArtRegion('shop-02', Rect.fromLTWH(650, 1243, 191, 256));
  static const timerBoostMyItem = ArtRegion('shop-03', Rect.fromLTWH(332, 1266, 186, 209));
  
  // Subscriptions
  static const maxFamilyPlan = ArtRegion('shop-02', Rect.fromLTWH(81, 2103, 209, 197));

  // Special Offers
  static const widgetReward = ArtRegion('shop-04', Rect.fromLTWH(84, 616, 174, 162));
  static const genshinReward = ArtRegion('shop-04', Rect.fromLTWH(84, 957, 174, 193));
  static const friendsChest = ArtRegion('shop-05', Rect.fromLTWH(86, 616, 179, 162));
  static const earlyBirdChest = ArtRegion('shop-05', Rect.fromLTWH(86, 1359, 179, 140));
  static const nightOwlChest = ArtRegion('shop-05', Rect.fromLTWH(86, 1719, 179, 151));
  
  // Timer Boost 
  static const timerBoostSingle = ArtRegion('shop-04', Rect.fromLTWH(95, 1622, 151, 148));
  static const timerBoost5Pack = ArtRegion('shop-04', Rect.fromLTWH(95, 1987, 163, 185));
  static const timerBoost15Pack = ArtRegion('shop-04', Rect.fromLTWH(90, 2335, 168, 197));

  // Streak Freeze
  static const streakFreezeItem = ArtRegion('shop-05', Rect.fromLTWH(102, 2323, 151, 209));
}
