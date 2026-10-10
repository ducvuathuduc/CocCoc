import 'package:flutter/material.dart';
import '../../../core/design/reference_art.dart';

abstract final class ShopArt {
  // Max subscriber banner
  static const maxBanner = ArtRegion('shop-02', Rect.fromLTWH(85, 410, 1000, 310));
  
  // My Items
  static const xpBoost = ArtRegion('shop-02', Rect.fromLTWH(210, 1145, 175, 235));
  static const streakFreeze = ArtRegion('shop-02', Rect.fromLTWH(620, 1145, 185, 235));
  static const timerBoostMyItem = ArtRegion('shop-03', Rect.fromLTWH(265, 1150, 180, 235));
  
  // Subscriptions
  static const maxFamilyPlan = ArtRegion('shop-02', Rect.fromLTWH(210, 1905, 220, 220));

  // Special Offers
  static const widgetReward = ArtRegion('shop-04', Rect.fromLTWH(240, 560, 175, 180));
  static const genshinReward = ArtRegion('shop-04', Rect.fromLTWH(240, 930, 210, 210));
  static const friendsChest = ArtRegion('shop-05', Rect.fromLTWH(240, 555, 175, 160));
  static const earlyBirdChest = ArtRegion('shop-05', Rect.fromLTWH(240, 1290, 175, 160));
  static const nightOwlChest = ArtRegion('shop-05', Rect.fromLTWH(240, 1660, 175, 160));
  
  // Timer Boost 
  static const timerBoostSingle = ArtRegion('shop-04', Rect.fromLTWH(240, 1600, 180, 180));
  static const timerBoost5Pack = ArtRegion('shop-04', Rect.fromLTWH(240, 1960, 210, 210));
  static const timerBoost15Pack = ArtRegion('shop-04', Rect.fromLTWH(240, 2330, 205, 205));

  // Streak Freeze
  static const streakFreezeItem = ArtRegion('shop-05', Rect.fromLTWH(210, 2190, 180, 210));
}
