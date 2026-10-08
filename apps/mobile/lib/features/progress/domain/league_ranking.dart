class LeagueRankingEntry {
  const LeagueRankingEntry({
    required this.userId,
    required this.name,
    required this.xp,
    required this.rank,
    required this.isOwn,
  });

  final String userId;
  final String name;
  final int xp;
  final int rank;
  final bool isOwn;
}

class LeagueRanking {
  LeagueRanking({required List<LeagueRankingEntry> entries})
    : entries = List.unmodifiable(entries);

  final List<LeagueRankingEntry> entries;
}
