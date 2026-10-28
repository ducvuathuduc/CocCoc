import 'dart:async';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/idempotency.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../domain/quest_models.dart';
import '../domain/upgrade_chest.dart';
import 'quests_repository.dart';

/// [QuestsRepository] backed by `GET /v1/quests` + `POST /v1/quests/{id}/claim`.
///
/// Server-owned: daily quests (DAY), the monthly challenge (MONTH) and the
/// friends quest (WEEK, `friend_*`). The weekend XP quest has no endpoint yet,
/// so it renders as a zero-progress card rather than a fixture value.
class ApiQuestsRepository
    implements
        QuestsRepository,
        QuestCommands,
        QuestRewardCommands,
        FriendQuestCommands,
        QuestCopySource {
  @override
  ChestRewardCopy get chestCopy => const ChestRewardCopy();

  ApiQuestsRepository(
    this.api, {
    SnapshotHost? host,
    DateTime Function()? now,
    IdGenerator? ids,
  }) : _now = now ?? DateTime.now,
       _ids = ids ?? UuidV4Generator(),
       cache = SnapshotCache<wire.QuestPage>(
         key: 'quests',
         host: host ?? SnapshotHost.detached(),
         decode: wire.QuestPage.fromJson,
         encode: (page) => page.toJson(),
         maxAge: const Duration(minutes: 1),
         clock: now,
       );

  final ApiEndpoints api;
  final SnapshotCache<wire.QuestPage> cache;
  final DateTime Function() _now;
  final IdGenerator _ids;

  static const _titles = {
    'daily_lessons': 'Complete {n} lessons',
    'daily_correct': 'Answer {n} questions correctly',
    'daily_review': 'Complete {n} review session',
  };

  Future<wire.QuestPage> _fetch() => api.listQuests(limit: 50);

  Future<void> refresh() => cache.refresh(_fetch);

  @override
  QuestsTabState loadQuests({
    QuestSectionType sectionType = QuestSectionType.friends,
  }) {
    cache.ensureLoaded(_fetch);
    final items = cache.value?.items ?? const <wire.Quest>[];
    final now = _now();
    final daily = items.where((q) => q.period == 'DAY').toList();
    final monthly = items.where((q) => q.period == 'MONTH').firstOrNull;
    final friend = items
        .where((q) => q.period == 'WEEK' && q.questId.startsWith('friend_'))
        .firstOrNull;
    return QuestsTabState(
      sectionType: sectionType,
      monthlyChallenge: _monthly(monthly, now),
      friendsQuest: _friends(friend, now),
      weekendQuest: WeekendQuest(
        title: 'Earn 100 XP',
        timeRemaining: _daysLeftInWeek(now),
        currentXp: 0,
        targetXp: 100,
      ),
      dailyQuests: [
        for (var i = 0; i < daily.length; i++)
          DailyQuest(
            id: daily[i].questId,
            title: (_titles[daily[i].questId] ?? daily[i].questId).replaceAll(
              '{n}',
              '${daily[i].target}',
            ),
            current: daily[i].metricValue.clamp(0, daily[i].target),
            target: daily[i].target,
            chestType: QuestChestType
                .values[i.clamp(0, QuestChestType.values.length - 1)],
            isClaimed: daily[i].claimed,
            rewardGems: daily[i].rewardGems,
          ),
      ],
      dailyTimeRemaining: _hoursToMidnight(now),
    );
  }

  @override
  Future<bool> claim(String questId) async {
    final quest = cache.value?.items
        .where((q) => q.questId == questId)
        .firstOrNull;
    if (quest == null || quest.claimed || quest.metricValue < quest.target) {
      return false;
    }
    await api.claimQuest(
      questId,
      wire.QuestClaimRequest(periodKey: quest.periodKey),
    );
    unawaited(refresh());
    return true;
  }

  @override
  Future<UpgradeChestReward?> claimReward(String questId) async {
    final quest = cache.value?.items
        .where((q) => q.questId == questId)
        .firstOrNull;
    if (quest == null || quest.claimed || quest.metricValue < quest.target) {
      return null;
    }
    final rewards = await api.claimQuest(
      questId,
      wire.QuestClaimRequest(periodKey: quest.periodKey, upgradeChest: true),
    );
    unawaited(refresh());
    final chest = rewards.chest;
    if (chest == null) {
      return null; // An older already-claimed receipt cannot be rolled again.
    }
    return UpgradeChestReward.checked(chest.receiptId, chest.tiers, chest.gems);
  }

  @override
  Future<bool> optInFriendQuest() async {
    await api.optInFriendQuest(idempotencyKey: _ids.next());
    await refresh();
    return true;
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  MonthlyChallenge _monthly(wire.Quest? quest, DateTime now) {
    final month = _months[now.month - 1];
    final end = DateTime(now.year, now.month + 1);
    final days = end.difference(DateTime(now.year, now.month, now.day)).inDays;
    return MonthlyChallenge(
      title: '$month Quest',
      daysRemaining: '$days ${days == 1 ? 'DAY' : 'DAYS'}',
      currentPoints: quest?.metricValue ?? 0,
      targetPoints: quest?.target ?? 0,
      badgeName: '$month Badge',
    );
  }

  FriendsQuest _friends(wire.Quest? quest, DateTime now) => FriendsQuest(
    title: 'Complete ${quest?.target ?? 0} lessons',
    timeRemaining: _daysLeftInWeek(now),
    target: quest?.target ?? 0,
    userLessons: quest?.metricValue ?? 0,
    friendLessons: 0,
    friendName: '',
    isNudged: false,
    isGifted: false,
    isHighFived: false,
    // The wire Quest DTO carries no opt-in flag yet, so API mode starts
    // un-opted and the JOIN button is shown; QuestsController flips this to
    // true in-session after optInFriendQuest() succeeds. (Was `quest != null`,
    // which hid JOIN whenever a quest existed and killed the feature.)
    isOptedIn: false,
  );

  static String _hoursToMidnight(DateTime now) {
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final hours = midnight.difference(now).inHours;
    return hours < 1 ? '${midnight.difference(now).inMinutes}M' : '${hours}H';
  }

  static String _daysLeftInWeek(DateTime now) {
    final days = DateTime.sunday - now.weekday + 1;
    return '${days}D';
  }
}
