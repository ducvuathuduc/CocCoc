import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/presentation/signup_flow.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_results.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/results/application/results_providers.dart';
import 'package:cocenglish/features/results/data/results_repository.dart';
import 'package:cocenglish/features/results/domain/results_models.dart';
import 'package:cocenglish/features/results/presentation/results_chain.dart';
import 'package:cocenglish/features/results/presentation/results_extra_screens.dart';
import 'package:cocenglish/features/results/presentation/results_screens.dart';
import 'package:cocenglish/features/results/presentation/score_unlock_screen.dart';
import 'package:cocenglish/features/results/presentation/results_theme.dart';
import 'package:cocenglish/features/results/presentation/results_widgets.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _NoExtrasRepository extends MockResultsRepository {
  const _NoExtrasRepository();
  @override
  StreakGoalResult? streakGoal() => null;
  @override
  WidgetUnlockResult? widgetUnlock() => null;
  @override
  FriendStreakResult? friendStreak() => null;
  @override
  FriendsQuestResult? friendsQuest() => null;
}

class _ServerQuestRepository extends MockResultsRepository {
  const _ServerQuestRepository();
  @override
  FriendsQuestResult? friendsQuest() => const FriendsQuestResult(
    gemBalance: 12,
    current: 24,
    target: 25,
    daysLeft: 1,
    boostLabel: 'BOOST',
    boostCost: 5,
    laterLabel: 'SKIP',
  );
}

Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  bool reduced = false,
  List overrides = const [],
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides],
      child: MaterialApp(
        theme: referenceTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 59, bottom: 0),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('results-golden'),
          child: screen,
        ),
      ),
    ),
  );
}

class _CompletedLesson extends LessonController {
  _CompletedLesson(this.receipt);
  final SessionReceipt receipt;
  @override
  LessonState build() => LessonState(
    stage: LessonStage.completed,
    receipt: receipt,
    attempted: 10,
    originalCorrect: 10,
  );
}

SessionReceipt _receipt({bool guest = false, int gems = 5}) => SessionReceipt(
  id: guest ? 'guest-first' : 'lesson-first',
  nodeId: guest ? 'demo' : 'node-0',
  xp: 20,
  gems: gems,
  accuracy: 1,
  elapsed: const Duration(seconds: 58),
  firstCompletion: true,
  guest: guest,
  placement: false,
);

/// Boots the real app router, then jumps to a completed lesson's results.
Future<void> _openRouterResults(
  WidgetTester tester,
  SessionReceipt receipt,
) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Looping path/summary idles never settle; reduced motion keeps
  // pumpAndSettle meaningful while still exercising the real router.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lessonControllerProvider.overrideWith(() => _CompletedLesson(receipt)),
      ],
      child: MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'French',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Navigator).first))
      .go('/results/${receipt.id}');
  await tester.pumpAndSettle();
  expect(find.byType(LessonResults), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, String text) async {
  final f = find.text(text).hitTestable().last;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

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
    await ReferenceArt.preloadFiles(ResultsArt.extraFiles);
  });

  test('mock repository exposes reference outcomes for 07–10, 13', () {
    const repo = MockResultsRepository();
    expect(repo.streakGoal()!.goalDays, 7);
    expect(repo.widgetUnlock()!.message, contains('Sleepytime Duo'));
    expect(
      repo.widgetUnlock()!.cards.map((c) => c.state),
      WidgetCardState.values,
    );
    expect(repo.friendStreak()!.title, 'Friend Streak with\nSam Lee');
    final quest = repo.friendsQuest()!;
    expect(quest.remaining, 9);
    expect(quest.fraction, closeTo(.64, 1e-9));
    expect(
      quest.message,
      '3 days left! Do 9 more lessons to\nfinish this Friends Quest.',
    );
    expect(repo.pathReturn().gems, 950);
  });

  group('chain order', () {
    const repo = MockResultsRepository();
    test('learner whose streak grew sees the full Duolingo order', () {
      expect(
        resultsChainStages(
          repository: repo,
          streakGrew: true,
          gemsEarned: true,
          guest: false,
        ),
        [
          ResultsStage.streakExtended,
          ResultsStage.streakGoal,
          ResultsStage.widgetUnlock,
          ResultsStage.friendStreak,
          ResultsStage.gems,
          ResultsStage.quest,
          ResultsStage.friendsQuest,
          ResultsStage.league,
        ],
      );
    });
    test('no streak growth and no gems skips those screens', () {
      expect(
        resultsChainStages(
          repository: repo,
          streakGrew: false,
          gemsEarned: false,
          guest: false,
        ),
        [ResultsStage.quest, ResultsStage.friendsQuest, ResultsStage.league],
      );
    });
    test('guest ends on the create-profile prompt', () {
      expect(
        resultsChainStages(
          repository: repo,
          streakGrew: false,
          gemsEarned: false,
          guest: true,
        ),
        [ResultsStage.quest, ResultsStage.createProfile],
      );
    });
    test('null optional results drop out', () {
      expect(
        resultsChainStages(
          repository: const _NoExtrasRepository(),
          streakGrew: true,
          gemsEarned: true,
          guest: false,
        ),
        [
          ResultsStage.streakExtended,
          ResultsStage.gems,
          ResultsStage.quest,
          ResultsStage.league,
        ],
      );
    });
  });

  const screens = <String, Widget>{
    'streak_goal': StreakGoalScreen(),
    'widget_unlock': WidgetUnlockScreen(),
    'friend_streak': FriendStreakResultScreen(),
    'friends_quest': FriendsQuestResultScreen(),
    'path_return': PathReturnScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('results ${entry.key} 430 golden', (tester) async {
      await _open(tester, entry.value);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('results-golden')),
        matchesGoldenFile(
          '../../goldens/ui_master/sprint_results_${entry.key}_430.png',
        ),
      );
    });

    testWidgets('results ${entry.key} reduced motion renders final frame', (
      tester,
    ) async {
      await _open(tester, entry.value, reduced: true);
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('friends quest bar fills, server values drive copy', (
    tester,
  ) async {
    var boosted = 0;
    var later = 0;
    await _open(
      tester,
      FriendsQuestResultScreen(
        onBoost: () => boosted++,
        onContinue: () => later++,
      ),
      overrides: [
        resultsRepositoryProvider.overrideWithValue(
          const _ServerQuestRepository(),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(FriendsQuestBar), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('24 / 25'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(
      find.text(
        '1 days left! Do 1 more lessons to\nfinish this Friends Quest.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('BOOST'));
    expect(find.text('5'), findsOneWidget);
    await tester.tap(find.text('SKIP'));
    expect((boosted, later), (1, 1));
  });

  testWidgets('friend streak counts up and widget highlight is blue', (
    tester,
  ) async {
    await _open(tester, const FriendStreakResultScreen());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('1 day friend streak'), findsOneWidget);
    await _open(tester, const WidgetUnlockScreen(), reduced: true);
    await tester.pump();
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Sleepytime'),
      ),
    );
    final span = (rich.text as TextSpan).children!.first as TextSpan;
    expect(span.children![1].style!.color, ResultsColors.blue);
  });

  testWidgets(
    'router: lesson complete → score → streak → gems → quests → league → home',
    (tester) async {
      await _openRouterResults(tester, _receipt());
      await _tap(tester, 'CLAIM XP');
      expect(find.byType(ScoreUnlockScreen), findsOneWidget);
      await _tap(tester, 'CONTINUE');
      // Streak went 0 → 1; its celebrations follow the first Score unlock.
      expect(find.byType(StreakExtendedScreen), findsOneWidget);
      await _tap(tester, 'CONTINUE');
      expect(find.byType(StreakGoalScreen), findsOneWidget);
      await _tap(tester, 'I CAN DO IT');
      expect(find.byType(WidgetUnlockScreen), findsOneWidget);
      await _tap(tester, 'CONTINUE');
      expect(find.byType(FriendStreakResultScreen), findsOneWidget);
      await _tap(tester, 'CONTINUE');
      expect(find.byType(GemRewardScreen), findsOneWidget);
      await _tap(tester, 'CONTINUE');
      expect(find.byType(QuestProgressResultScreen), findsOneWidget);
      await _tap(tester, 'CONTINUE');
      expect(find.byType(FriendsQuestResultScreen), findsOneWidget);
      await _tap(tester, 'MAYBE LATER');
      expect(find.byType(LeagueRankResultScreen), findsOneWidget);
      await _tap(tester, 'I CAN DO IT');
      expect(find.byType(ResultsChainScreen), findsNothing);
      expect(find.text('Use basic phrases'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('router: guest gets create-profile prompt → signup / later', (
    tester,
  ) async {
    await _openRouterResults(tester, _receipt(guest: true, gems: 0));
    await _tap(tester, 'CLAIM XP');
    expect(find.byType(StreakExtendedScreen), findsNothing);
    expect(find.byType(GemRewardScreen), findsNothing);
    expect(find.byType(QuestProgressResultScreen), findsOneWidget);
    await _tap(tester, 'CONTINUE');
    expect(find.byType(CreateProfilePromptScreen), findsOneWidget);
    await _tap(tester, 'CREATE PROFILE');
    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('router: guest LATER returns home', (tester) async {
    await _openRouterResults(tester, _receipt(guest: true, gems: 0));
    await _tap(tester, 'CLAIM XP');
    await _tap(tester, 'CONTINUE');
    await _tap(tester, 'LATER');
    expect(find.byType(ResultsChainScreen), findsNothing);
    expect(find.text('Use basic phrases'), findsOneWidget);
  });

  testWidgets('router: /speaking/call opens the video call', (tester) async {
    await _openRouterResults(tester, _receipt());
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .go('/speaking/call');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'VideoCallScreen',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chain primary buttons stay ≥48 tall', (tester) async {
    await _open(tester, const StreakGoalScreen(), reduced: true);
    await tester.pump();
    expect(
      tester.getSize(find.byType(ResultsPrimaryButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  for (final screen in <Widget>[
    const StreakExtendedScreen(),
    const StreakGoalScreen(),
    const WidgetUnlockScreen(),
    const FriendStreakResultScreen(),
    const GemRewardScreen(),
    const QuestProgressResultScreen(),
    const FriendsQuestResultScreen(),
    const LeagueRankResultScreen(),
    const PathReturnScreen(),
  ]) {
    testWidgets('${screen.runtimeType} lays out at 390 without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: referenceTheme(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: screen,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
