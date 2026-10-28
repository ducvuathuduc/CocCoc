import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/quests/application/quests_controller.dart';
import 'package:cocenglish/features/quests/data/quests_repository.dart';
import 'package:cocenglish/features/quests/domain/quest_models.dart';
import 'package:cocenglish/features/quests/presentation/quests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await ReferenceArt.preloadFiles([
      'quests-02',
      'quests-03',
      'quests-04',
      'quests-05',
      'quests-06',
    ]);
  });

  QuestsTabState friendsQuestState({
    required bool optedIn,
    bool completed = false,
  }) {
    final base = const MockQuestsRepository().loadQuests();
    return base.copyWith(
      introSeen: true,
      friendsQuest: base.friendsQuest.copyWith(
        isOptedIn: optedIn,
        userLessons: completed
            ? base.friendsQuest.target
            : base.friendsQuest.userLessons,
        friendLessons: completed ? 0 : base.friendsQuest.friendLessons,
      ),
    );
  }

  Future<void> pumpQuests(
    WidgetTester tester, {
    required _JoinFakeRepository repository,
  }) async {
    tester.view.physicalSize = const Size(430, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questsRepositoryProvider.overrideWithValue(repository),
          previewControllerProvider.overrideWith(
            () => _TestPreviewController(true),
          ),
        ],
        child: MaterialApp(
          theme: referenceTheme(),
          debugShowCheckedModeBanner: false,
          home: const QuestsScreen(sectionType: QuestSectionType.friends),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('JOIN is visible before opt-in, then hides after tapping', (
    tester,
  ) async {
    final repository = _JoinFakeRepository(friendsQuestState(optedIn: false));
    await pumpQuests(tester, repository: repository);

    expect(find.text('JOIN'), findsOneWidget);
    expect(find.text('NUDGE'), findsOneWidget);
    expect(find.text('GIFT'), findsOneWidget);

    await tester.tap(find.text('JOIN'));
    await tester.pumpAndSettle();

    expect(repository.optInCalls, 1);
    expect(find.text('JOIN'), findsNothing);
    expect(find.text('NUDGE'), findsOneWidget);
    expect(find.text('GIFT'), findsOneWidget);
  });

  testWidgets('an opted-in Friends Quest has no JOIN action', (tester) async {
    final repository = _JoinFakeRepository(friendsQuestState(optedIn: true));
    await pumpQuests(tester, repository: repository);

    expect(find.text('JOIN'), findsNothing);
    expect(find.text('NUDGE'), findsOneWidget);
    expect(find.text('GIFT'), findsOneWidget);
  });

  testWidgets('the completed Friends Quest branch is unchanged', (
    tester,
  ) async {
    final repository = _JoinFakeRepository(
      friendsQuestState(optedIn: false, completed: true),
    );
    await pumpQuests(tester, repository: repository);

    expect(find.text('JOIN'), findsNothing);
    expect(find.textContaining('HIGH FIVED'), findsOneWidget);
  });

  test('a failed opt-in keeps the quest and reports the failure', () async {
    final repository = _JoinFakeRepository(
      friendsQuestState(optedIn: false),
      result: false,
    );
    final container = ProviderContainer(
      overrides: [questsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final joined = await container
        .read(questsControllerProvider.notifier)
        .optInFriendQuest();

    expect(joined, isFalse);
    final state = container.read(questsControllerProvider);
    expect(state.friendsQuest.isOptedIn, isFalse);
    expect(state.feedbackMessage, 'Could not join. Try again.');
  });
}

final class _JoinFakeRepository
    implements QuestsRepository, FriendQuestCommands {
  _JoinFakeRepository(this._initial, {this.result = true});

  final QuestsTabState _initial;
  final bool result;
  int optInCalls = 0;

  @override
  QuestsTabState loadQuests({
    QuestSectionType sectionType = QuestSectionType.friends,
  }) => _initial;

  @override
  Future<bool> optInFriendQuest() async {
    optInCalls += 1;
    return result;
  }
}

final class _TestPreviewController extends PreviewController {
  _TestPreviewController(this._introSeen);

  final bool _introSeen;

  @override
  PreviewState build() => PreviewState(questIntroSeen: _introSeen);
}
