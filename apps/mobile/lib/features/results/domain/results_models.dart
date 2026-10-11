/// Display models for the post-lesson result screens that follow the basic
/// lesson-complete summary. These describe server-issued outcomes; the client
/// never awards XP, gems, quest points or league rank on its own.
library;

enum ResultDayState { practiced, today, missed }

class ResultDay {
  const ResultDay(this.label, this.state);
  final String label;
  final ResultDayState state;
}

/// results/05: streak extended celebration on the orange takeover.
class StreakExtendedResult {
  const StreakExtendedResult({
    required this.days,
    required this.title,
    required this.week,
    required this.shareLabel,
    required this.continueLabel,
  });
  final int days;
  final String title;
  final List<ResultDay> week;
  final String shareLabel;
  final String continueLabel;
}

/// results/04: chest reward with a gem payout.
class GemRewardResult {
  const GemRewardResult({
    required this.gems,
    required this.unit,
    required this.message,
    required this.continueLabel,
  });
  final int gems;
  final String unit;
  final String message;
  final String continueLabel;
}

enum QuestChestState { opened, locked, gold }

class QuestProgressItem {
  const QuestProgressItem({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    required this.chest,
  });
  final String id;
  final String title;
  final int current;
  final int target;
  final QuestChestState chest;

  double get fraction =>
      target <= 0 ? 0 : (current / target).clamp(0, 1).toDouble();
  bool get complete => target > 0 && current >= target;
}

/// results/11: daily quest progress after a lesson.
class QuestProgressResult {
  const QuestProgressResult({
    required this.points,
    required this.gemBalance,
    required this.quests,
    required this.continueLabel,
  });
  final int points;
  final int gemBalance;
  final List<QuestProgressItem> quests;
  final String continueLabel;

  String get headline => '+$points Quest ${points == 1 ? 'Point' : 'Points'}!';
}

class LeagueRankRow {
  const LeagueRankRow({
    required this.rank,
    required this.name,
    required this.xp,
    required this.avatarKey,
    required this.flagKey,
    required this.streak,
    this.isUser = false,
    this.initial,
  });
  final int rank;
  final String name;
  final int xp;

  /// Presentation maps this key to artwork; null keys fall back to [initial].
  final String? avatarKey;
  final String flagKey;
  final int streak;
  final bool isUser;
  final String? initial;
}

/// results/12: league standings with the promotion cut line.
class LeagueRankResult {
  const LeagueRankResult({
    required this.message,
    required this.promotionCutoff,
    required this.promotionLabel,
    required this.rows,
    required this.continueLabel,
  });
  final String message;

  /// Ranks `<= promotionCutoff` move up; the zone divider sits after it.
  final int promotionCutoff;
  final String promotionLabel;
  final List<LeagueRankRow> rows;
  final String continueLabel;

  LeagueRankRow? get user => rows.where((row) => row.isUser).firstOrNull;
}
