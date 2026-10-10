import '../domain/quest_models.dart';
import 'quests_mock_data.dart';

/// Override questsRepositoryProvider to replace the local quest data source.
abstract interface class QuestsRepository {
  QuestsTabState loadQuests({
    QuestSectionType sectionType = QuestSectionType.friends,
  });
}

class MockQuestsRepository implements QuestsRepository {
  const MockQuestsRepository();

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
