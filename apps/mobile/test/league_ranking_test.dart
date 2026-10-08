import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';
import 'package:cocenglish/features/account/presentation/avatar_motion.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/progress/application/league_ranking_provider.dart';
import 'package:cocenglish/features/progress/presentation/league_ranking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ranking is immutable, descending and assigns all eight ranks', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ranking = container.read(leagueRankingProvider);
    expect(ranking.entries, hasLength(8));
    expect(ranking.entries.map((entry) => entry.rank), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
    ]);
    expect(
      ranking.entries.map((entry) => entry.xp),
      orderedEquals(
        ranking.entries.map((entry) => entry.xp).toList()
          ..sort((a, b) => b.compareTo(a)),
      ),
    );
    expect(ranking.entries.where((entry) => entry.isOwn).single.userId, 'me');
    expect(
      ranking.entries
          .where((entry) => !entry.isOwn)
          .map((entry) => entry.userId),
      containsAll(<String>[
        'Alex',
        'Maria',
        'Lucas',
        'Anna',
        'Samira',
        'Noah',
        'Emma',
      ]),
    );
    expect(() => ranking.entries.clear(), throwsUnsupportedError);
  });

  test('learner XP re-ranks only me and keeps deterministic foreign ties', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = container.read(leagueRankingProvider);
    final foreignBefore = {
      for (final entry in before.entries.where((entry) => !entry.isOwn))
        entry.userId: entry.xp,
    };

    container
        .read(learningStateProvider.notifier)
        .claim(
          const SessionReceipt(
            id: 'league-tie',
            nodeId: 'league-node',
            xp: 120,
            accuracy: 1,
            elapsed: Duration(minutes: 2),
            firstCompletion: true,
            guest: false,
            placement: false,
          ),
        );
    final after = container.read(leagueRankingProvider);
    final alex = after.entries.singleWhere((entry) => entry.userId == 'Alex');
    final me = after.entries.singleWhere((entry) => entry.isOwn);
    expect(alex.xp, me.xp);
    expect(alex.rank, lessThan(me.rank));
    expect({
      for (final entry in after.entries.where((entry) => !entry.isOwn))
        entry.userId: entry.xp,
    }, foreignBefore);
  });

  testWidgets('source ranking opens profiles and own avatar opens status', (
    tester,
  ) async {
    String? opened;
    var statusOpens = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: Scaffold(
            body: LeagueRankingSurface(
              ownAvatar: const SizedBox(
                key: ValueKey('own-avatar-fixture'),
                width: 45,
                height: 45,
                child: ColoredBox(color: Colors.green),
              ),
              onOpenProfile: (userId) => opened = userId,
              onSetStatus: () => statusOpens++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bronze League'), findsOneWidget);
    expect(find.text('6 DAYS'), findsOneWidget);
    expect(find.text('Compete with other learners.'), findsOneWidget);
    final trophies = tester
        .widgetList<ReferenceArt>(find.byType(ReferenceArt))
        .toList();
    expect(trophies[0].region.file, 'status-league');
    expect(
      trophies[0].region.source,
      const ui.Rect.fromLTWH(78, 501, 126, 229),
    );
    expect(trophies[1].region.file, 'status-league');
    expect(
      trophies[1].region.source,
      const ui.Rect.fromLTWH(650, 506, 168, 222),
    );

    tester.semantics.tap(find.semantics.byLabel('Rank 1, Anna, 214 XP'));
    await tester.pump();
    expect(opened, 'Anna');
    final list = find.descendant(
      of: find.byType(ListView),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('league-row-me')),
      240,
      scrollable: list,
    );
    await tester.pump();
    expect(find.semantics.byLabel('Set your status'), findsOne);
    tester.semantics.tap(find.semantics.byLabel('Set your status'));
    await tester.pump();
    expect(statusOpens, 1);
    expect(opened, 'Anna');

    final ownRow = tester.widget<Material>(
      find.byKey(const ValueKey('league-row-me')),
    );
    expect(ownRow.color, const Color(0xFFD7FFB8));
  });

  testWidgets('ranking rows expand safely at 320 and text scale two', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: LeagueRankingSurface(
              ownAvatar: const SizedBox(
                key: ValueKey('own-avatar-fixture'),
                width: 45,
                height: 45,
              ),
              onOpenProfile: (_) {},
              onSetStatus: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.text('Bronze League')),
    );
    container
        .read(learningStateProvider.notifier)
        .claim(
          const SessionReceipt(
            id: 'large-readable-league-xp',
            nodeId: 'local-league-fixture',
            xp: 999999,
            accuracy: 1,
            elapsed: Duration(minutes: 2),
            firstCompletion: true,
            guest: false,
            placement: false,
          ),
        );
    await tester.pump();

    final list = find.descendant(
      of: find.byType(ListView),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('league-row-Anna')),
      180,
      scrollable: list,
    );
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('league-row-Anna'))).height,
      greaterThanOrEqualTo(55),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('league-row-me')),
      -240,
      scrollable: list,
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel('Set your status').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('999999 XP').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('foreign avatar state survives learner XP rank changes', (
    tester,
  ) async {
    final source = await tester.runAsync(
      () => rootBundle.loadString(
        'assets/avatar/avatar_builder_config.json',
        cache: false,
      ),
    );
    final catalog = AvatarCatalogLoader.parse(source!);
    final container = ProviderContainer(
      overrides: [avatarCatalogProvider.overrideWithValue(AsyncData(catalog))],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: referenceTheme(),
          home: Scaffold(
            body: LeagueRankingSurface(
              ownAvatar: const SizedBox(width: 45, height: 45),
              onOpenProfile: (_) {},
              onSetStatus: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final annaAvatar = find.descendant(
      of: find.byKey(const ValueKey('league-row-Anna')),
      matching: find.byType(AvatarMotion),
    );
    final before = tester.state(annaAvatar);

    container
        .read(learningStateProvider.notifier)
        .claim(
          const SessionReceipt(
            id: 'league-mounted-reorder',
            nodeId: 'league-mounted-node',
            xp: 220,
            accuracy: 1,
            elapsed: Duration(minutes: 2),
            firstCompletion: true,
            guest: false,
            placement: false,
          ),
        );
    await tester.pump(const Duration(milliseconds: 300));

    final me = container
        .read(leagueRankingProvider)
        .entries
        .singleWhere((entry) => entry.isOwn);
    expect(
      find.bySemanticsLabel('Rank 1, ${me.name}, ${me.xp} XP'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Rank 2, Anna, 214 XP'), findsOneWidget);
    expect(identical(tester.state(annaAvatar), before), isTrue);
  });

  testWidgets(
    'rows expose one profile action plus separate own status action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final source = await tester.runAsync(
        () => rootBundle.loadString(
          'assets/avatar/avatar_builder_config.json',
          cache: false,
        ),
      );
      final catalog = AvatarCatalogLoader.parse(source!);
      final container = ProviderContainer(
        overrides: [
          avatarCatalogProvider.overrideWithValue(AsyncData(catalog)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: referenceTheme(),
            home: Scaffold(
              body: LeagueRankingSurface(
                ownAvatar: const SizedBox(width: 45, height: 45),
                onOpenProfile: (_) {},
                onSetStatus: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final anna = tester.getSemantics(
        find.bySemanticsLabel('Rank 1, Anna, 214 XP'),
      );
      final annaTree = _semanticsTree(anna);
      expect(_tapActionCount(annaTree), 1);
      final annaDescendantLabels = annaTree
          .skip(1)
          .map((node) => node.getSemanticsData().label);
      expect(
        annaDescendantLabels.where(
          (label) =>
              label.contains('Anna') ||
              label.contains('214 XP') ||
              label == '1',
        ),
        isEmpty,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('league-row-me')),
        240,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      final meEntry = container
          .read(leagueRankingProvider)
          .entries
          .singleWhere((entry) => entry.isOwn);
      final me = tester.getSemantics(
        find.bySemanticsLabel(
          'Rank ${meEntry.rank}, ${meEntry.name}, ${meEntry.xp} XP',
        ),
      );
      final meTree = _semanticsTree(me);
      expect(_tapActionCount(meTree), 2);
      expect(
        meTree
            .map((node) => node.getSemanticsData().label)
            .where((label) => label == 'Set your status'),
        hasLength(1),
      );
      semantics.dispose();
    },
  );

  testWidgets('short window scrolls the header and reaches the final row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 430);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: Scaffold(
            body: LeagueRankingSurface(
              ownAvatar: const SizedBox(width: 45, height: 45),
              onOpenProfile: (_) {},
              onSetStatus: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final list = find.byType(ListView).first;
    final headerTop = tester.getTopLeft(find.text('Bronze League')).dy;
    await tester.drag(list, const Offset(0, -100));
    await tester.pump();
    expect(find.text('Bronze League'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Bronze League')).dy,
      lessThan(headerTop),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('league-row-me')),
      300,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('league-row-me')).hitTestable(), findsOne);
    expect(find.text('Bronze League'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

List<SemanticsNode> _semanticsTree(SemanticsNode root) {
  final nodes = <SemanticsNode>[root];
  root.visitChildren((child) {
    nodes.addAll(_semanticsTree(child));
    return true;
  });
  return nodes;
}

int _tapActionCount(Iterable<SemanticsNode> nodes) => nodes
    .where((node) => node.getSemanticsData().hasAction(ui.SemanticsAction.tap))
    .length;
