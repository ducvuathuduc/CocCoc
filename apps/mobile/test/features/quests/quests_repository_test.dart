import 'package:cocenglish/features/quests/application/quests_controller.dart';
import 'package:cocenglish/features/quests/data/quests_repository.dart';
import 'package:cocenglish/features/quests/domain/quest_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository override supplies initial data and section changes', () {
    final repository = _ReplacementQuestsRepository();
    final container = ProviderContainer(
      overrides: [questsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final initial = container.read(questsControllerProvider);
    expect(initial.monthlyChallenge.title, 'Replacement month');
    expect(initial.friendsQuest.friendName, 'Sam');
    expect(initial.weekendQuest.targetXp, 250);
    expect(initial.dailyQuests.single.title, 'Replacement daily quest');
    expect(initial.dailyTimeRemaining, '7H');

    final controller = container.read(questsControllerProvider.notifier);
    controller.nudge();
    controller.setSectionType(QuestSectionType.weekend);
    final weekend = container.read(questsControllerProvider);
    expect(weekend.sectionType, QuestSectionType.weekend);
    expect(weekend.monthlyChallenge.title, 'Replacement weekend month');
    expect(weekend.friendsQuest.isNudged, isTrue);
    expect(weekend.dailyQuests.single.title, 'Replacement daily quest');

    controller.setSectionType(QuestSectionType.friends);
    expect(
      container.read(questsControllerProvider).monthlyChallenge.title,
      'Replacement month',
    );
  });
}

class _ReplacementQuestsRepository implements QuestsRepository {
  @override
  QuestsTabState loadQuests({
    QuestSectionType sectionType = QuestSectionType.friends,
  }) {
    final initial = const MockQuestsRepository().loadQuests(
      sectionType: sectionType,
    );
    return initial.copyWith(
      monthlyChallenge: initial.monthlyChallenge.copyWith(
        title: sectionType == QuestSectionType.weekend
            ? 'Replacement weekend month'
            : 'Replacement month',
      ),
      friendsQuest: initial.friendsQuest.copyWith(friendName: 'Sam'),
      weekendQuest: initial.weekendQuest.copyWith(targetXp: 250),
      dailyQuests: const [
        DailyQuest(
          id: 'replacement-daily',
          title: 'Replacement daily quest',
          current: 0,
          target: 3,
        ),
      ],
      dailyTimeRemaining: '7H',
    );
  }
}
