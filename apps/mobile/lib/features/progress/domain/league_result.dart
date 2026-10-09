enum LeagueTier { bronze, silver, gold, sapphire, ruby, obsidian, diamond }

extension LeagueTierLabel on LeagueTier {
  String get label => switch (this) {
    LeagueTier.bronze => 'Bronze',
    LeagueTier.silver => 'Silver',
    LeagueTier.gold => 'Gold',
    LeagueTier.sapphire => 'Sapphire',
    LeagueTier.ruby => 'Ruby',
    LeagueTier.obsidian => 'Obsidian',
    LeagueTier.diamond => 'Diamond',
  };
}

class LeagueResultEntry {
  const LeagueResultEntry({
    required this.name,
    required this.xp,
    required this.rank,
    required this.isLearner,
  });

  final String name;
  final int xp;
  final int rank;
  final bool isLearner;
}

class LeagueResultFixture {
  LeagueResultFixture({
    required this.previousTier,
    required this.currentTier,
    required List<LeagueResultEntry> entries,
    int rewardGems = 0,
    this.eventLabel,
  }) : entries = _validatedEntries(entries),
       rewardGems = _validatedReward(rewardGems);

  final LeagueTier previousTier;
  final LeagueTier currentTier;
  final List<LeagueResultEntry> entries;
  final int rewardGems;
  final String? eventLabel;

  bool get promoted => previousTier.index < currentTier.index;

  LeagueResultEntry get learner =>
      entries.singleWhere((entry) => entry.isLearner);

  static List<LeagueResultEntry> _validatedEntries(
    List<LeagueResultEntry> entries,
  ) {
    if (entries.where((entry) => entry.isLearner).length != 1) {
      throw ArgumentError.value(
        entries,
        'entries',
        'must contain exactly one learner',
      );
    }
    if (entries.any((entry) => entry.xp < 0 || entry.rank < 1)) {
      throw ArgumentError.value(
        entries,
        'entries',
        'must use non-negative XP and positive ranks',
      );
    }
    return List<LeagueResultEntry>.unmodifiable(entries);
  }

  static int _validatedReward(int rewardGems) {
    if (rewardGems < 0) {
      throw ArgumentError.value(
        rewardGems,
        'rewardGems',
        'must be non-negative',
      );
    }
    return rewardGems;
  }
}
