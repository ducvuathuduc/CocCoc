import 'package:flutter/widgets.dart' show StringCharacters;

import '../../../core/api/api_contracts.dart' as wire;
import '../../progress/data/progress_snapshot.dart';
import '../domain/results_models.dart';
import 'results_repository.dart';

/// [ResultsRepository] derived from the shared Progress snapshot
/// (`/v1/me/rewards`, `/v1/league`, `/v1/quests`, `/v1/me`).
///
/// Celebrations whose trigger the server does not report (streak goal, widget
/// unlock, friend streak) return `null`, so the chain skips them instead of
/// showing fixture values.
class ApiResultsRepository implements ResultsRepository {
  ApiResultsRepository(this.source, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ProgressSnapshotSource source;
  final DateTime Function() _now;

  /// services/progress league: top 5 promote.
  static const promoteCount = 5;

  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  static const _questTitles = {
    'daily_lessons': 'Complete {n} lessons',
    'daily_correct': 'Answer {n} questions correctly',
    'daily_review': 'Complete {n} review session',
  };

  ProgressSnapshot? get _s => source.value;
  int get _streak => _s?.rewards.currentStreak ?? 0;
  int get _gems => _s?.rewards.gems ?? 0;

  @override
  StreakExtendedResult streakExtended() {
    final today = _now().weekday - 1; // 0 = Monday
    final streak = _streak;
    return StreakExtendedResult(
      days: streak,
      title: 'day streak',
      week: [
        for (var i = 0; i < 7; i++)
          ResultDay(
            _dayLabels[i],
            i == today
                ? ResultDayState.today
                : i < today && today - i < streak
                ? ResultDayState.practiced
                : ResultDayState.missed,
          ),
      ],
      shareLabel: 'SHARE',
      continueLabel: 'CONTINUE',
    );
  }

  @override
  GemRewardResult gemReward() => GemRewardResult(
    gems: _gems,
    unit: 'gems',
    message: 'You now have $_gems gems.\nKeep learning to earn more!',
    continueLabel: 'CONTINUE',
  );

  @override
  QuestProgressResult questProgress() {
    final daily = [
      for (final q in _s?.quests.items ?? const <wire.Quest>[])
        if (q.period == 'DAY') q,
    ];
    return QuestProgressResult(
      points: daily.where((q) => q.metricValue >= q.target).length,
      gemBalance: _gems,
      continueLabel: 'CONTINUE',
      quests: [
        for (final q in daily)
          QuestProgressItem(
            id: q.questId,
            title: (_questTitles[q.questId] ?? q.questId).replaceAll(
              '{n}',
              '${q.target}',
            ),
            current: q.metricValue.clamp(0, q.target),
            target: q.target,
            chest: q.claimed
                ? QuestChestState.opened
                : q.metricValue >= q.target
                ? QuestChestState.gold
                : QuestChestState.locked,
          ),
      ],
    );
  }

  @override
  LeagueRankResult leagueRank() {
    final snapshot = _s;
    final members = [...?snapshot?.league?.members]
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final mine = members.indexWhere(
      (m) => m.userId == snapshot?.profile.userId,
    );
    final start = mine < 0 ? 0 : (mine - 1).clamp(0, members.length);
    final window = members.skip(start).take(5);
    return LeagueRankResult(
      message:
          'The top $promoteCount move up to the next\nleague. Will you make it?',
      promotionCutoff: promoteCount,
      promotionLabel: 'PROMOTION ZONE',
      continueLabel: 'I CAN DO IT',
      rows: [
        for (final m in window)
          LeagueRankRow(
            rank: m.rank,
            name: m.nickname.isEmpty ? 'Learner' : m.nickname,
            xp: m.eligibleXp,
            avatarKey: null,
            initial: m.nickname.isEmpty
                ? 'L'
                : m.nickname.characters.first.toUpperCase(),
            flagKey: 'us',
            streak: m.userId == snapshot?.profile.userId ? _streak : 0,
            isUser: m.userId == snapshot?.profile.userId,
          ),
      ],
    );
  }

  @override
  StreakGoalResult? streakGoal() => null;

  @override
  WidgetUnlockResult? widgetUnlock() => null;

  @override
  FriendStreakResult? friendStreak() => null;

  @override
  FriendsQuestResult? friendsQuest() {
    final quest = _s?.quests.items
        .where((q) => q.period == 'WEEK' && q.questId.startsWith('friend_'))
        .firstOrNull;
    if (quest == null) return null;
    return FriendsQuestResult(
      gemBalance: _gems,
      current: quest.metricValue,
      target: quest.target,
      daysLeft: DateTime.sunday - _now().weekday + 1,
      boostLabel: 'SEND XP BOOST',
      boostCost: 20,
      laterLabel: 'MAYBE LATER',
    );
  }

  @override
  PathReturnResult pathReturn() => PathReturnResult(
    courseLevel: 0,
    streak: _streak,
    gems: _gems,
    sectionLabel: 'SECTION 1, UNIT 1',
    unitTitle: '',
  );
}
