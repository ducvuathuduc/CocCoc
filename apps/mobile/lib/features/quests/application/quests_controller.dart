import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../../../core/config/app_config.dart';
import '../data/api_quests_repository.dart';
import '../data/quests_repository.dart';
import '../domain/quest_models.dart';
import '../domain/upgrade_chest.dart';
import '../../auth/application/auth_controller.dart';
import '../../session/application/real_learning_session.dart';
import '../../learning/application/learning_controller.dart';
import '../../progress/application/preview_controller.dart';

final questsRepositoryProvider = Provider<QuestsRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return const MockQuestsRepository();
  return ApiQuestsRepository(
    ref.watch(apiEndpointsProvider),
    host: SnapshotHost.of(ref, 'quests'),
  );
});

final chestRewardCopyProvider = Provider<ChestRewardCopy>((ref) {
  return switch (ref.watch(questsRepositoryProvider)) {
    QuestCopySource(:final chestCopy) => chestCopy,
    _ => const ChestRewardCopy(),
  };
});

final questsControllerProvider =
    NotifierProvider<QuestsController, QuestsTabState>(QuestsController.new);

class QuestsController extends Notifier<QuestsTabState> {
  @override
  QuestsTabState build() {
    watchSnapshot(ref, 'quests');
    final initial = ref.watch(questsRepositoryProvider).loadQuests();
    final preview = ref.watch(previewControllerProvider);
    final learning = ref.watch(learningStateProvider);
    final introSeen = preview.questIntroSeen;
    final claims = preview.claims;
    final claimUser = ref.watch(
      authControllerProvider.select((s) => s.user?.id),
    );

    final initialDaily = initial.dailyQuests.map((q) {
      final claimed =
          q.isClaimed ||
          claims.contains(q.id) ||
          (q.id == 'daily-score' && claims.contains('daily-xp'));
      if (q.id == 'daily-2') {
        return q.copyWith(
          current: learning.completedLessons.clamp(0, q.target),
          isClaimed: claimed,
        );
      }
      return q.copyWith(
        isClaimed: claimed,
        isClaiming: _pendingClaims.contains('$claimUser/${q.id}'),
      );
    }).toList();

    return initial.copyWith(introSeen: introSeen, dailyQuests: initialDaily);
  }

  void dismissIntro() {
    state = state.copyWith(introSeen: true);
    ref.read(previewControllerProvider.notifier).dismissQuestIntro();
  }

  void setSectionType(QuestSectionType type) {
    final quests = ref
        .read(questsRepositoryProvider)
        .loadQuests(sectionType: type);
    state = state.copyWith(
      sectionType: type,
      monthlyChallenge: quests.monthlyChallenge,
    );
  }

  void nudge() {
    state = state.copyWith(
      friendsQuest: state.friendsQuest.copyWith(isNudged: true),
      feedbackMessage: 'Nudged ${state.friendsQuest.friendName}!',
    );
  }

  void gift() {
    state = state.copyWith(
      friendsQuest: state.friendsQuest.copyWith(isGifted: true),
      feedbackMessage: 'Sent a gift to ${state.friendsQuest.friendName}!',
    );
  }

  void highFive() {
    state = state.copyWith(
      friendsQuest: state.friendsQuest.copyWith(isHighFived: true),
      feedbackMessage: 'High fived ${state.friendsQuest.friendName}!',
    );
  }

  void setFriendsQuest(FriendsQuest quest) {
    state = state.copyWith(friendsQuest: quest);
  }

  void setWeekendQuest(WeekendQuest quest) {
    state = state.copyWith(weekendQuest: quest);
  }

  void setMonthlyChallenge(MonthlyChallenge challenge) {
    state = state.copyWith(monthlyChallenge: challenge);
  }

  void setDailyQuests(List<DailyQuest> quests) {
    state = state.copyWith(dailyQuests: quests);
  }

  bool claimQuest(String id) {
    if (ref.read(appConfigProvider).isApi) return false;
    final index = state.dailyQuests.indexWhere((q) => q.id == id);
    if (index == -1) return false;
    final quest = state.dailyQuests[index];
    if (!quest.canClaim) return false;

    // Call through to previewController
    final previewId = id == 'daily-score' ? 'daily-xp' : id;
    final success = ref
        .read(previewControllerProvider.notifier)
        .claimQuest(previewId, eligible: quest.isCompleted);

    final repository = ref.read(questsRepositoryProvider);
    if (repository case final QuestCommands commands) {
      unawaited(commands.claim(id).catchError((Object _) => false));
    }

    // Update state to mark claimed
    final updatedList = List<DailyQuest>.from(state.dailyQuests);
    updatedList[index] = quest.copyWith(isClaimed: true);

    state = state.copyWith(
      dailyQuests: updatedList,
      feedbackMessage: success ? 'Claimed 10 gems!' : 'Claimed!',
    );
    return true;
  }

  final _pendingClaims = <String>{};

  Future<UpgradeChestReward?> claimReward(String id) async {
    final userId = ref.read(authControllerProvider).user?.id;
    final pendingKey = '$userId/$id';
    final quest = state.dailyQuests.where((q) => q.id == id).firstOrNull;
    if (quest == null || !quest.canClaim || !_pendingClaims.add(pendingKey)) {
      return null;
    }
    final repository = ref.read(questsRepositoryProvider);
    state = state.copyWith(
      dailyQuests: [
        for (final q in state.dailyQuests)
          q.id == id ? q.copyWith(isClaiming: true) : q,
      ],
    );
    try {
      UpgradeChestReward? reward;
      if (ref.read(appConfigProvider).isApi) {
        if (repository is! QuestRewardCommands) return null;
        reward = await (repository as QuestRewardCommands).claimReward(id);
        if (!ref.mounted ||
            ref.read(authControllerProvider).user?.id != userId) {
          return null;
        }
        ref.invalidate(realRewardsProvider);
      } else {
        reward = UpgradeChestReward.demo('demo-$id', quest.rewardGems);
        final previewId = id == 'daily-score' ? 'daily-xp' : id;
        if (!ref
            .read(previewControllerProvider.notifier)
            .claimQuest(previewId, eligible: true, gems: reward.gems)) {
          return null;
        }
      }
      if (!ref.mounted || reward == null) return null;
      state = state.copyWith(
        dailyQuests: [
          for (final q in state.dailyQuests)
            q.id == id ? q.copyWith(isClaimed: true, isClaiming: false) : q,
        ],
        feedbackMessage: 'Claimed ${reward.gems} gems!',
      );
      return reward;
    } catch (_) {
      if (ref.mounted && ref.read(authControllerProvider).user?.id == userId) {
        state = state.copyWith(
          feedbackMessage: 'Could not claim your reward. Try again.',
        );
      }
      return null;
    } finally {
      _pendingClaims.remove(pendingKey);
      if (ref.mounted && ref.read(authControllerProvider).user?.id == userId) {
        state = state.copyWith(
          dailyQuests: [
            for (final q in state.dailyQuests)
              q.id == id ? q.copyWith(isClaiming: false) : q,
          ],
        );
      }
    }
  }
}
