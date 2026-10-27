import 'league_result.dart';

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
  LeagueRanking({required List<LeagueRankingEntry> entries, this.tier})
    : entries = List.unmodifiable(entries);

  final List<LeagueRankingEntry> entries;

  /// Server tier when known; null for the local preview league.
  final LeagueTier? tier;
}

