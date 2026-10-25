import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/shell/application/app_shell_providers.dart';
import 'package:cocenglish/features/shell/data/app_shell_repository.dart';
import 'package:cocenglish/features/shell/domain/app_shell_models.dart';
import 'package:cocenglish/features/shell/presentation/app_bottom_nav.dart';
import 'package:cocenglish/features/shell/presentation/app_stats_bar.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settle_images.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('DuolingoSans')
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
          ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
        .load();
    await ReferenceArt.preloadFiles([
      '05',
      'lesson-01',
      'practice-04',
      'energy-02',
      'energy-01',
    ]);
  });
  testWidgets('all top stats retain at least48dp hit areas', (tester) async {
    await tester.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    for (final label in ['Courses', 'Streak', 'Shop', 'Energy']) {
      final control = find.descendant(
        of: find.byTooltip(label),
        matching: find.byType(InkWell),
      );
      final size = tester.getSize(control);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('tab artwork retains its source proportions', (tester) async {
    await tester.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['Home', 'Practice', 'Quests', 'League', 'Profile']) {
      final artFinder = find.descendant(
        of: find.byTooltip(label),
        matching: find.byType(ReferenceArt),
      );
      final art = tester.widget<ReferenceArt>(artFinder);
      final size = tester.getSize(artFinder);
      expect(
        size.width / size.height,
        closeTo(art.region.source.width / art.region.source.height, .01),
        reason: label,
      );
    }
  });

  testWidgets('repository alone replaces shell copy and destinations', (
    tester,
  ) async {
    AppStatKind? stat;
    int? branch;
    final container = ProviderContainer(
      overrides: [
        appShellRepositoryProvider.overrideWithValue(
          _AlternateShellRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _harness(
        container,
        onStat: (value) => stat = value,
        onTab: (value) => branch = value,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Courses'), findsNothing);
    expect(find.byTooltip('Home'), findsNothing);
    expect(find.text('432'), findsOneWidget);
    expect(find.bySemanticsLabel('Reserve, 432'), findsOneWidget);
    await tester.tap(find.byTooltip('Reserve'));
    await tester.pumpAndSettle();
    expect(stat, AppStatKind.energy);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(branch, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'top stats react to current progress, wallet and unlimited plan',
    (tester) async {
      final container = ProviderContainer(
        overrides: [learningStateProvider.overrideWith(_StatsFixture.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Streak, 846 days'), findsOneWidget);
      expect(find.bySemanticsLabel('Shop, 8369 gems'), findsOneWidget);
      expect(find.bySemanticsLabel('Energy, 25'), findsOneWidget);
      container
          .read(learningStateProvider.notifier)
          .claim(
            const SessionReceipt(
              id: 'shell-receipt',
              nodeId: 'node-0',
              xp: 10,
              accuracy: 1,
              elapsed: Duration(seconds: 58),
              firstCompletion: true,
              guest: false,
              placement: false,
              gems: 2,
            ),
          );
      container.read(extendedControllerProvider.notifier)
        ..choosePlan('individual')
        ..confirmPlan();
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Courses, English score 24'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Shop, 8371 gems'), findsOneWidget);
      expect(find.bySemanticsLabel('Energy, unlimited'), findsOneWidget);
      expect(find.text('∞'), findsOneWidget);
      expect(container.read(learningStateProvider).xp, 10);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets('shell press/cancel and selection respect reduced=$reduced', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var selected = 0;
      var actions = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: referenceTheme(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  bottomNavigationBar: AppBottomNav(
                    selectedBranch: selected,
                    onSelected: (value) => setState(() {
                      selected = value;
                      actions++;
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Practice')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final scale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byTooltip('Practice'),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, reduced ? 1 : .94);
      expect(
        scale.duration,
        reduced ? Duration.zero : const Duration(milliseconds: 120),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(actions, 0);
      await tester.tap(find.byTooltip('Practice'));
      await tester.pump(const Duration(milliseconds: 70));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(actions, 1);
      expect(find.bySemanticsLabel('Practice'), findsOneWidget);
      final tile = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byTooltip('Practice'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        tile.duration,
        reduced ? Duration.zero : const Duration(milliseconds: 140),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('five branch switches preserve the Home path scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byTooltip('Home'));
    ProviderScope.containerOf(context)
        .read(previewControllerProvider.notifier)
        .dismissQuestIntro();
    final list = find.byKey(const PageStorageKey('learning-path'));
    await tester.drag(list, const Offset(0, -120));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));
    for (final label in ['Practice', 'Quests', 'League', 'Profile']) {
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, before);
  });

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'shell strips $width text$scale golden and accessible controls',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 430 ? 932 : 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = ProviderContainer(
            overrides: [learningStateProvider.overrideWith(_StatsFixture.new)],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(_harness(container, scale: scale));
          await tester.pumpAndSettle();
          // Decode the stat and tab artwork so the golden shows the icons.
          await settleImages(tester);
          for (final label in [
            'Courses',
            'Streak',
            'Shop',
            'Energy',
            'Home',
            'Practice',
            'Quests',
            'League',
            'Profile',
          ]) {
            final ink = find.descendant(
              of: find.byTooltip(label),
              matching: find.byType(InkWell),
            );
            expect(find.byTooltip(label).hitTestable(), findsOneWidget);
            expect(tester.getSize(ink).height, greaterThanOrEqualTo(48));
            expect(tester.getSize(ink).width, greaterThanOrEqualTo(48));
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const ValueKey('shell-master-screen')),
            matchesGoldenFile(
              'goldens/ui_master/sprint_shell_${width.toInt()}_text${scale.toInt()}.png',
            ),
          );
        },
      );
    }
  }
}

Widget _harness(
  ProviderContainer container, {
  double scale = 1,
  ValueChanged<AppStatKind>? onStat,
  ValueChanged<int>? onTab,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: referenceTheme(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 59, bottom: 34),
          viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: RepaintBoundary(
          key: const ValueKey('shell-master-screen'),
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AppStatsBar(onSelected: onStat ?? (_) {}),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
            bottomNavigationBar: AppBottomNav(
              selectedBranch: 1,
              onSelected: onTab ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  ),
);

class _StatsFixture extends LearningStateController {
  @override
  LearningState build() =>
      const LearningState(score: 19, streak: 846, gems: 8369);
}

class _AlternateShellRepository implements AppShellRepository {
  @override
  List<AppStat> stats(AppShellSnapshot snapshot) => const [
    AppStat(
      kind: AppStatKind.energy,
      label: 'Reserve',
      value: '432',
      semanticLabel: 'Reserve, 432',
    ),
  ];
  @override
  List<AppTab> tabs() => const [
    AppTab(kind: AppTabKind.profile, branchIndex: 4, label: 'Account'),
  ];
}
