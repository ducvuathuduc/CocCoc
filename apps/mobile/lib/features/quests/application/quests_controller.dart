import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quests_repository.dart';
import '../domain/quest_models.dart';
import '../../learning/application/learning_controller.dart';
import '../../progress/application/preview_controller.dart';

final questsRepositoryProvider = Provider<QuestsRepository>(
  (ref) => const MockQuestsRepository(),
);

final questsControllerProvider =
    NotifierProvider<QuestsController, QuestsTabState>(QuestsController.new);

class QuestsController extends Notifier<QuestsTabState> {
  @override
  QuestsTabState build() {
    final initial = ref.watch(questsRepositoryProvider).loadQuests();
    final preview = ref.watch(previewControllerProvider);
    final learning = ref.watch(learningStateProvider);
    final introSeen = preview.questIntroSeen;
    final claims = preview.claims;

    final initialDaily = initial.dailyQuests.map((q) {
      final claimed =
          claims.contains(q.id) ||
          (q.id == 'daily-score' && claims.contains('daily-xp'));
      if (q.id == 'daily-2') {
        return q.copyWith(
          current: learning.completedLessons.clamp(0, q.target),
          isClaimed: claimed,
        );
      }
      return q.copyWith(isClaimed: claimed);
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
    final index = state.dailyQuests.indexWhere((q) => q.id == id);
    if (index == -1) return false;
    final quest = state.dailyQuests[index];
    if (!quest.canClaim) return false;

    // Call through to previewController
    final previewId = id == 'daily-score' ? 'daily-xp' : id;
    final success = ref
        .read(previewControllerProvider.notifier)
        .claimQuest(previewId, eligible: quest.isCompleted);

    // Update state to mark claimed
    final updatedList = List<DailyQuest>.from(state.dailyQuests);
    updatedList[index] = quest.copyWith(isClaimed: true);

    state = state.copyWith(
      dailyQuests: updatedList,
      feedbackMessage: success ? 'Claimed 10 gems!' : 'Claimed!',
    );
    return true;
  }
}
