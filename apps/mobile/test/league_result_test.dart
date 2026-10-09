import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/progress/application/league_result_controller.dart';
import 'package:cocenglish/features/progress/domain/league_result.dart';
import 'package:cocenglish/features/progress/presentation/league_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settlement advances once through authored eligible stages', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final fixture = container.read(leagueResultFixtureProvider)!;
    expect(fixture.learner.name, 'Sam');
    expect(fixture.learner.xp, 867);
    expect(fixture.entries, isNotEmpty);
    expect(() => fixture.entries.clear(), throwsUnsupportedError);
    expect(
      container.read(leagueResultControllerProvider).stage,
      LeagueResultStage.result,
    );

    final controller = container.read(leagueResultControllerProvider.notifier);
    expect(controller.advance(), isFalse);
    expect(
      container.read(leagueResultControllerProvider).stage,
      LeagueResultStage.promotion,
    );
    expect(controller.advance(), isFalse);
    expect(
      container.read(leagueResultControllerProvider).stage,
      LeagueResultStage.reward,
    );
    expect(controller.advance(), isTrue);
    expect(
      container.read(leagueResultControllerProvider).stage,
      LeagueResultStage.complete,
    );
    expect(controller.advance(), isFalse);
    expect(
      container.read(leagueResultControllerProvider).stage,
      LeagueResultStage.complete,
    );
  });

  test('ineligible authored stages are skipped without inventing rewards', () {
    final fixture = LeagueResultFixture(
      previousTier: LeagueTier.silver,
      currentTier: LeagueTier.silver,
      entries: const <LeagueResultEntry>[
        LeagueResultEntry(name: 'Sam', xp: 622, rank: 4, isLearner: true),
      ],
    );
    final container = ProviderContainer(
      overrides: [leagueResultFixtureProvider.overrideWithValue(fixture)],
    );
    addTearDown(container.dispose);

    final controller = container.read(leagueResultControllerProvider.notifier);
    expect(controller.advance(), isTrue);
    expect(
      container.read(leagueResultControllerProvider).stage,
      LeagueResultStage.complete,
    );
    expect(controller.advance(), isFalse);
  });

  test('authored reward can be acknowledged without a promotion', () {
    final fixture = LeagueResultFixture(
      previousTier: LeagueTier.silver,
      currentTier: LeagueTier.silver,
      rewardGems: 20,
      entries: const <LeagueResultEntry>[
        LeagueResultEntry(name: 'Sam', xp: 622, rank: 3, isLearner: true),
      ],
    );
    final container = ProviderContainer(
      overrides: [leagueResultFixtureProvider.overrideWithValue(fixture)],
    );
    addTearDown(container.dispose);

    final controller = container.read(leagueResultControllerProvider.notifier);
    expect(controller.advance(), isFalse);
    expect(
      container.read(leagueResultControllerProvider).stage,
      LeagueResultStage.reward,
    );
    expect(controller.advance(), isTrue);
  });

  test('fixture rejects invalid learner, rank, XP and reward data', () {
    expect(
      () => LeagueResultFixture(
        previousTier: LeagueTier.bronze,
        currentTier: LeagueTier.silver,
        entries: const <LeagueResultEntry>[],
      ),
      throwsArgumentError,
    );
    expect(
      () => LeagueResultFixture(
        previousTier: LeagueTier.bronze,
        currentTier: LeagueTier.silver,
        entries: const <LeagueResultEntry>[
          LeagueResultEntry(name: 'Sam', xp: -1, rank: 1, isLearner: true),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => LeagueResultFixture(
        previousTier: LeagueTier.bronze,
        currentTier: LeagueTier.silver,
        entries: const <LeagueResultEntry>[
          LeagueResultEntry(name: 'Sam', xp: 1, rank: 0, isLearner: true),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => LeagueResultFixture(
        previousTier: LeagueTier.bronze,
        currentTier: LeagueTier.silver,
        entries: const <LeagueResultEntry>[
          LeagueResultEntry(name: 'Sam', xp: 1, rank: 1, isLearner: true),
        ],
        rewardGems: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => LeagueResultFixture(
        previousTier: LeagueTier.bronze,
        currentTier: LeagueTier.silver,
        entries: const <LeagueResultEntry>[
          LeagueResultEntry(name: 'Sam', xp: 1, rank: 1, isLearner: true),
          LeagueResultEntry(name: 'Lee', xp: 1, rank: 2, isLearner: true),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('moving to a lower tier does not present a promotion', () {
    final fixture = LeagueResultFixture(
      previousTier: LeagueTier.gold,
      currentTier: LeagueTier.silver,
      entries: const <LeagueResultEntry>[
        LeagueResultEntry(name: 'Sam', xp: 300, rank: 19, isLearner: true),
      ],
    );
    expect(fixture.promoted, isFalse);
  });

  test('missing authored settlement completes without fabricated stages', () {
    final container = ProviderContainer(
      overrides: [leagueResultFixtureProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(leagueResultControllerProvider).stage,
      LeagueResultStage.complete,
    );
    expect(
      container.read(leagueResultControllerProvider.notifier).advance(),
      isFalse,
    );
  });

  test(
    'a fresh history entry replays without changing learner balances',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final learningBefore = container.read(learningStateProvider);
      final subscription = container.listen(
        leagueResultControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final controller = container.read(
        leagueResultControllerProvider.notifier,
      );
      controller.advance();
      controller.advance();
      controller.advance();
      expect(
        container.read(leagueResultControllerProvider).stage,
        LeagueResultStage.complete,
      );

      subscription.close();
      await container.pump();

      expect(
        container.read(leagueResultControllerProvider).stage,
        LeagueResultStage.result,
      );
      expect(container.read(learningStateProvider).xp, learningBefore.xp);
      expect(container.read(learningStateProvider).gems, learningBefore.gems);
    },
  );

  testWidgets('authored result promotes to Silver and acknowledges 40 gems', (
    tester,
  ) async {
    var finishes = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LeagueResultScreen(onFinished: () => finishes++),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LeagueResultScreen)),
    );
    final learningBefore = container.read(learningStateProvider);
    expect(find.text('You finished #1 last week!'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('867 XP'), findsOneWidget);
    expect(find.bySemanticsLabel('Rank 1, Sam, 867 XP'), findsOneWidget);
    final resultArt = tester
        .widgetList<ReferenceArt>(find.byType(ReferenceArt))
        .toList();
    expect(resultArt.first.region.file, 'league-result-source');
    expect(
      resultArt.first.region.source,
      const ui.Rect.fromLTWH(430, 230, 590, 475),
    );

    expect(find.bySemanticsLabel('CONTINUE').hitTestable(), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('CONTINUE').hitTestable());
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Congratulations! You were promoted to this week's Silver League.",
      ),
      findsOneWidget,
    );
    final promotionArt = tester.widget<ReferenceArt>(find.byType(ReferenceArt));
    expect(promotionArt.region.file, 'league-promotion-source');
    expect(
      promotionArt.region.source,
      const ui.Rect.fromLTWH(0, 175, 1179, 1010),
    );
    expect(promotionArt.height, closeTo(360 * 1010 / 1179, 0.001));

    expect(find.bySemanticsLabel('CONTINUE').hitTestable(), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('CONTINUE').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('+40 gems'), findsOneWidget);
    expect(
      find.text(
        'You earned 40 gems! Keep finishing in the top 3 to win rewards.',
      ),
      findsOneWidget,
    );
    final rewardArt = tester.widget<ReferenceArt>(find.byType(ReferenceArt));
    expect(rewardArt.region.file, 'league-reward-source');
    expect(rewardArt.region.source, const ui.Rect.fromLTWH(300, 670, 580, 650));

    expect(find.bySemanticsLabel('CONTINUE').hitTestable(), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('CONTINUE').hitTestable());
    await tester.pumpAndSettle();
    expect(finishes, 1);
    expect(container.read(learningStateProvider).xp, learningBefore.xp);
    expect(container.read(learningStateProvider).gems, learningBefore.gems);

    container.read(leagueResultControllerProvider.notifier).advance();
    await tester.pump();
    expect(finishes, 1);
    expect(container.read(learningStateProvider).xp, learningBefore.xp);
    expect(container.read(learningStateProvider).gems, learningBefore.gems);
  });

  testWidgets('Diamond event variant uses authored tier and skips no reward', (
    tester,
  ) async {
    var finishes = 0;
    final fixture = LeagueResultFixture(
      previousTier: LeagueTier.obsidian,
      currentTier: LeagueTier.diamond,
      eventLabel: 'Diamond Tournament',
      entries: const <LeagueResultEntry>[
        LeagueResultEntry(name: 'Sam', xp: 1420, rank: 2, isLearner: true),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [leagueResultFixtureProvider.overrideWithValue(fixture)],
        child: MaterialApp(
          home: LeagueResultScreen(onFinished: () => finishes++),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Diamond Tournament'), findsOneWidget);
    expect(find.text('You finished #2 last week!'), findsOneWidget);
    expect(find.bySemanticsLabel('CONTINUE').hitTestable(), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('CONTINUE').hitTestable());
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Congratulations! You were promoted to this week's Diamond League.",
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('CONTINUE').hitTestable(), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('CONTINUE').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('gems'), findsNothing);
    expect(finishes, 1);
  });

  testWidgets('close preserves the authored result and learner balances', (
    tester,
  ) async {
    var closes = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LeagueResultScreen(onFinished: () => closes++),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LeagueResultScreen)),
    );
    final before = container.read(learningStateProvider);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();

    expect(closes, 1);
    expect(
      container.read(leagueResultControllerProvider).stage,
      LeagueResultStage.result,
    );
    expect(container.read(learningStateProvider).xp, before.xp);
    expect(container.read(learningStateProvider).gems, before.gems);
  });

  testWidgets('source-sized result expands its card and overlays close', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: LeagueResultScreen(onFinished: () {})),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('league-result-card'))).height,
      370,
    );
    expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(find.byTooltip('Close')).dy, closeTo(0, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 wide text scale two scrolls every step without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: LeagueResultScreen(onFinished: () {}),
        ),
      ),
    );
    await tester.pump();

    for (final expected in <String>[
      'You finished #1 last week!',
      "Congratulations! You were promoted to this week's Silver League.",
      '+40 gems',
    ]) {
      await tester.ensureVisible(find.text(expected));
      expect(find.text(expected), findsOneWidget);
      expect(find.bySemanticsLabel('CONTINUE').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('CONTINUE').hitTestable());
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
