import '../domain/quest_models.dart';
import '../domain/upgrade_chest.dart';
import 'quests_mock_data.dart';

/// Override questsRepositoryProvider to replace the local quest data source.
abstract interface class QuestsRepository {
  QuestsTabState loadQuests({
    QuestSectionType sectionType = QuestSectionType.friends,
  });
}

class MockQuestsRepository implements QuestsRepository, QuestCopySource {
  const MockQuestsRepository();

  @override
  ChestRewardCopy get chestCopy => const ChestRewardCopy();

  @override
  QuestsTabState loadQuests({
    QuestSectionType sectionType = QuestSectionType.friends,
  }) => QuestsTabState(
    sectionType: sectionType,
    monthlyChallenge: sectionType == QuestSectionType.weekend
        ? QuestsMockData.weekendMonthlyChallenge
        : QuestsMockData.defaultMonthlyChallenge,
    friendsQuest: QuestsMockData.inProgressFriendsQuest,
    weekendQuest: QuestsMockData.defaultWeekendQuest,
    dailyQuests: QuestsMockData.defaultDailyQuests,
    dailyTimeRemaining: '5H',
  );
}

/// Optional server commands an API-backed [QuestsRepository] also implements.
/// The local preview ledger keeps the optimistic UI either way.
abstract interface class QuestCommands {
  Future<bool> claim(String questId);
}

abstract interface class QuestRewardCommands {
  Future<UpgradeChestReward?> claimReward(String questId);
}

/// Opts into next week's Friends Quest pairing on the Progress service.
abstract interface class FriendQuestCommands {
  Future<bool> optInFriendQuest();
}

/// Optional copy source; repositories without it fall back to the default
/// [ChestRewardCopy].
abstract interface class QuestCopySource {
  ChestRewardCopy get chestCopy;
}
