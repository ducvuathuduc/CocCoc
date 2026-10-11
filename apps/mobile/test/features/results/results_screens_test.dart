import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/results/application/results_providers.dart';
import 'package:cocenglish/features/results/data/results_repository.dart';
import 'package:cocenglish/features/results/domain/results_models.dart';
import 'package:cocenglish/features/results/presentation/results_screens.dart';
import 'package:cocenglish/features/results/presentation/results_theme.dart';
import 'package:cocenglish/features/results/presentation/results_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _OverrideRepository extends MockResultsRepository {
  const _OverrideRepository();
  @override
  GemRewardResult gemReward() => const GemRewardResult(
    gems: 120,
    unit: 'gems',
    message: 'Server reward',
    continueLabel: 'NEXT',
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
    await ReferenceArt.preloadFiles(ResultsArt.files);
  });

  test('mock repository exposes reference outcomes', () {
    const repo = MockResultsRepository();
    expect(repo.streakExtended().days, 5);
    expect(
      repo.streakExtended().week.where((d) => d.state != ResultDayState.missed),
      hasLength(5),
    );
    expect(repo.questProgress().headline, '+1 Quest Point!');
    expect(repo.questProgress().quests.first.complete, isTrue);
    expect(repo.questProgress().quests.last.fraction, closeTo(.1, 1e-9));
    final league = repo.leagueRank();
    expect(league.user!.rank, 9);
    expect(league.user!.rank > league.promotionCutoff, isTrue);
  });

  const screens = <String, Widget>{
    'gems': GemRewardScreen(),
    'quest': QuestProgressResultScreen(),
    'league': LeagueRankResultScreen(),
    'streak': StreakExtendedScreen(),
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
      expect(find.byKey(const Key('lesson-completion-confetti')), findsNothing);
      // Count-ups land on the final value without ticking.
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gem reward counts up and shows confetti once', (tester) async {
    await _open(tester, const GemRewardScreen());
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('lesson-completion-confetti')), findsOneWidget);
    expect(find.text('50'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('50'), findsOneWidget);
    expect(find.text(' gems'), findsOneWidget);
    expect(find.byKey(const Key('lesson-completion-confetti')), findsNothing);
  });

  testWidgets('repository override drives the screen and continue acts', (
    tester,
  ) async {
    var continued = 0;
    await _open(
      tester,
      GemRewardScreen(onContinue: () => continued++),
      reduced: true,
      overrides: [
        resultsRepositoryProvider.overrideWithValue(
          const _OverrideRepository(),
        ),
      ],
    );
    await tester.pump();
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Server reward'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    expect(continued, 1);
  });

  testWidgets('quest bars fill from zero to their fraction', (tester) async {
    await _open(tester, const QuestProgressResultScreen());
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('+1 Quest Point!'), findsOneWidget);
    expect(find.byType(ResultProgressBar), findsNWidgets(3));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.text('950'), findsOneWidget);
  });

  testWidgets('league highlights the learner below the promotion zone', (
    tester,
  ) async {
    await _open(tester, const LeagueRankResultScreen(), reduced: true);
    await tester.pumpAndSettle();
    expect(find.text('PROMOTION ZONE'), findsOneWidget);
    final zone = tester.getRect(find.text('PROMOTION ZONE'));
    final user = tester.getRect(find.byKey(const ValueKey('results-rank-9')));
    expect(user.top, greaterThan(zone.bottom));
    final row = tester.widget<Container>(
      find.byKey(const ValueKey('results-rank-9')),
    );
    expect(row.color, ResultsColors.userRow);
    expect(find.bySemanticsLabel('Rank 9, Alex Smith, 74 XP'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'I CAN DO IT')).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('streak share copies text and continue acts', (tester) async {
    var continued = 0;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    await _open(
      tester,
      StreakExtendedScreen(onContinue: () => continued++),
      reduced: true,
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Streak, 5 days'), findsOneWidget);
    await tester.tap(find.text('SHARE +20 GEMS'));
    await tester.pump();
    expect(calls.any((c) => c.method == 'Clipboard.setData'), isTrue);
    await tester.tap(find.text('CONTINUE'));
    expect(continued, 1);
  });
}
