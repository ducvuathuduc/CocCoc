import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/presentation/foreign_profile_achievements.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> finishTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<(BuildContext, ProviderContainer)> openAlex(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await finishTransition(tester);
    final context = tester.element(find.byTooltip('Profile'));
    final container = ProviderScope.containerOf(context);
    GoRouter.of(context).push('/profile/Alex');
    await finishTransition(tester);
    return (context, container);
  }

  testWidgets('foreign strip has three source awards and owner counters', (
    tester,
  ) async {
    await openAlex(tester);
    await tester.ensureVisible(find.bySemanticsLabel('Legend, 4 of 10'));
    await finishTransition(tester);

    expect(find.bySemanticsLabel('Legend, 4 of 10'), findsOneWidget);
    expect(find.bySemanticsLabel('Perfect Week, 1 of 30'), findsOneWidget);
    expect(find.bySemanticsLabel('Flawless Finisher, 5 of 5'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('foreign-award-legend')),
        matching: find.byType(ReferenceArt),
      ),
      findsOneWidget,
    );
    final cells = [
      find.byKey(const ValueKey('foreign-award-legend')),
      find.byKey(const ValueKey('foreign-award-perfect-week')),
      find.byKey(const ValueKey('foreign-award-flawless-finisher')),
    ];
    expect(
      cells.map(tester.getSize).map((size) => size.width).toSet(),
      hasLength(1),
    );
    final arts = [
      for (final cell in cells)
        tester.widget<ReferenceArt>(
          find.descendant(of: cell, matching: find.byType(ReferenceArt)),
        ),
    ];
    expect(
      arts.map((art) => art.region.file),
      everyElement('profile-foreign-source'),
    );
    for (var index = 0; index < arts.length; index++) {
      final region = arts[index].region.source;
      expect(region.left, greaterThanOrEqualTo(50 + index * 360));
      expect(region.right, lessThanOrEqualTo(410 + index * 360));
      expect(region.top, greaterThanOrEqualTo(1660));
      expect(
        region.bottom,
        lessThan(1930),
        reason: 'Source tier numerals begin below the figure',
      );
      expect(
        arts[index].height / arts[index].width,
        closeTo(region.height / region.width, 0.0001),
      );
    }
    expect(find.text('FRIENDS ACTIVITY'), findsNothing);
  });

  testWidgets(
    'safety actions preserve cancel and allow confirmed block then unblock',
    (tester) async {
      final (_, container) = await openAlex(tester);
      final xpBefore = container.read(learningStateProvider).xp;
      await tester.ensureVisible(find.text('REPORT USER'));
      await finishTransition(tester);

      await tester.tap(find.text('REPORT USER'));
      await finishTransition(tester);
      await tester.tap(find.text('Spam'));
      await finishTransition(tester);
      await tester.tap(find.text('Cancel'));
      await finishTransition(tester);
      expect(container.read(profileActionsProvider).reports, isEmpty);
      expect(container.read(profileActionsProvider).blocked, isEmpty);

      await tester.ensureVisible(find.text('BLOCK USER'));
      await finishTransition(tester);
      await tester.tap(find.text('BLOCK USER'));
      await finishTransition(tester);
      await tester.tap(find.text('Cancel'));
      await finishTransition(tester);
      expect(container.read(profileActionsProvider).blocked, isEmpty);
      expect(container.read(learningStateProvider).xp, xpBefore);

      await tester.tap(find.text('BLOCK USER'));
      await finishTransition(tester);
      await tester.tap(find.text('BLOCK'));
      await finishTransition(tester);
      expect(container.read(profileActionsProvider).blocked, contains('Alex'));
      final lowerUnblock = find.descendant(
        of: find.byType(ForeignProfileAchievements),
        matching: find.text('UNBLOCK USER'),
      );
      expect(lowerUnblock, findsOneWidget);
      await tester.tap(lowerUnblock);
      await finishTransition(tester);
      expect(container.read(profileActionsProvider).blocked, isEmpty);
      expect(container.read(learningStateProvider).xp, xpBefore);
    },
  );

  testWidgets('unknown profile keeps the lower foreign block hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: const Scaffold(
            body: ForeignProfileAchievements(userId: 'missing'),
          ),
        ),
      ),
    );
    await finishTransition(tester);
    expect(find.byType(ReferenceArt), findsNothing);
    expect(find.text('REPORT USER'), findsNothing);
    expect(find.text('BLOCK USER'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('award selection retains owner and returns to profile', (
    tester,
  ) async {
    final (context, _) = await openAlex(tester);
    final router = GoRouter.of(context);
    await tester.ensureVisible(find.bySemanticsLabel('Legend, 4 of 10'));
    await finishTransition(tester);
    final profilePosition = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final profileOffset = profilePosition.pixels;
    final legend = tester.getSemantics(
      find.bySemanticsLabel('Legend, 4 of 10'),
    );
    expect(legend.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Legend, 4 of 10'));
    await finishTransition(tester);

    expect(router.state.uri.path, '/achievements/legend');
    expect(router.state.uri.queryParameters['profile'], 'Alex');
    expect(find.text('CLAIM REWARD'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await finishTransition(tester);
    expect(router.state.uri.path, '/profile/Alex');
    expect(profilePosition.pixels, closeTo(profileOffset, 1));
  });

  testWidgets('foreign achievement section is compact at 320 text2', (
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
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: ForeignProfileAchievements(userId: 'James Smith'),
              ),
            ),
          ),
        ),
      ),
    );
    await finishTransition(tester);
    expect(find.bySemanticsLabel('Legend, 4 of 10'), findsOneWidget);
    expect(find.text('REPORT USER'), findsOneWidget);
    expect(find.text('BLOCK USER'), findsOneWidget);
    expect(
      DefaultTextStyle.of(tester.element(find.text('REPORT USER')))
          .style
          .fontFamily,
      'DuolingoSans',
    );
    expect(tester.takeException(), isNull);
  });
}
