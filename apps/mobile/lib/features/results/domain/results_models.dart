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

/// results/07: streak goal challenge ("I bet 7 days will be easy peasy!").
class StreakGoalResult {
  const StreakGoalResult({
    required this.goalDays,
    required this.message,
    required this.continueLabel,
  });
  final int goalDays;
  final String message;
  final String continueLabel;
}

enum WidgetCardState { previous, current, next }

class StreakWidgetCard {
  const StreakWidgetCard({required this.days, required this.state});
  final int days;
  final WidgetCardState state;
}

/// results/08: home-screen widget art unlocked by the streak.
class WidgetUnlockResult {
  const WidgetUnlockResult({
    required this.lead,
    required this.highlight,
    required this.tail,
    required this.cards,
    required this.continueLabel,
  });
  final String lead;
  final String highlight;
  final String tail;
  final List<StreakWidgetCard> cards;
  final String continueLabel;

  String get message => '$lead$highlight$tail';
}

/// results/09: friend streak kept alive with a named friend.
class FriendStreakResult {
  const FriendStreakResult({
    required this.friendName,
    required this.days,
    required this.titlePrefix,
    required this.continueLabel,
  });
  final String friendName;
  final int days;
  final String titlePrefix;
  final String continueLabel;

  String get title => '$titlePrefix\n$friendName';
}

/// results/10: shared Friends Quest progress with an XP boost offer.
class FriendsQuestResult {
  const FriendsQuestResult({
    required this.gemBalance,
    required this.current,
    required this.target,
    required this.daysLeft,
    required this.boostLabel,
    required this.boostCost,
    required this.laterLabel,
  });
  final int gemBalance;
  final int current;
  final int target;
  final int daysLeft;
  final String boostLabel;
  final int boostCost;
  final String laterLabel;

  int get remaining => (target - current).clamp(0, target);
  double get fraction =>
      target <= 0 ? 0 : (current / target).clamp(0, 1).toDouble();
  String get message =>
      '$daysLeft days left! Do $remaining more lessons to\nfinish this Friends Quest.';
}

/// results/13: the path the learner returns to after the result chain.
class PathReturnResult {
  const PathReturnResult({
    required this.courseLevel,
    required this.streak,
    required this.gems,
    required this.sectionLabel,
    required this.unitTitle,
  });
  final int courseLevel;
  final int streak;
  final int gems;
  final String sectionLabel;
  final String unitTitle;
}
