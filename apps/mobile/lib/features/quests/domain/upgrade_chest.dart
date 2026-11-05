import 'dart:math';

enum ChestRarity { common, rare, epic, mega }

class UpgradeChestReward {
  const UpgradeChestReward({
    required this.receiptId,
    required this.tiers,
    required this.gems,
  });
  final String receiptId;
  final List<ChestRarity> tiers;
  final int gems;

  factory UpgradeChestReward.checked(String id, List<String> tiers, int gems) {
    final ranks = tiers
        .map(
          (t) => ChestRarity.values
              .where((v) => v.name.toUpperCase() == t)
              .firstOrNull,
        )
        .toList();
    if (id.isEmpty ||
        gems <= 0 ||
        ranks.length != 4 ||
        ranks.first != ChestRarity.common ||
        ranks.any((v) => v == null)) {
      throw const FormatException('Invalid chest receipt');
    }
    for (var i = 1; i < ranks.length; i++) {
      final delta = ranks[i]!.index - ranks[i - 1]!.index;
      if (delta < 0 || delta > 1) {
        throw const FormatException('Invalid chest upgrade');
      }
    }
    return UpgradeChestReward(
      receiptId: id,
      tiers: List.unmodifiable(ranks.cast<ChestRarity>()),
      gems: gems,
    );
  }

  /// Explicit offline preview only. API mode always uses the Progress receipt.
  factory UpgradeChestReward.demo(String id, int baseGems, {Random? random}) {
    final rng = random ?? Random.secure();
    var rank = 0;
    final tiers = <ChestRarity>[ChestRarity.common];
    for (var i = 0; i < 3; i++) {
      if (rng.nextInt(256) < 64) rank = min(3, rank + 1);
      tiers.add(ChestRarity.values[rank]);
    }
    return UpgradeChestReward(
      receiptId: id,
      tiers: List.unmodifiable(tiers),
      gems: baseGems * (1 << rank),
    );
  }
}

class UpgradeChestProgress {
  UpgradeChestProgress(this.reward);
  final UpgradeChestReward reward;
  int attempts = 0;
  bool revealed = false;
  ChestRarity get rarity => reward.tiers[attempts];
  void tap() {
    if (attempts < 3) {
      attempts++;
    } else {
      revealed = true;
    }
  }
}
