import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/achievements_controller.dart';
import 'package:cocenglish/features/progress/presentation/achievements_screen.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'profile monthly badges route keeps chronology and profile scroll',
    (tester) async {
      await tester.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rootContext = tester.element(find.byTooltip('Profile'));
      final container = ProviderScope.containerOf(rootContext);
      final xpBefore = container.read(learningStateProvider).xp;

      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      final profileScroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.bySemanticsLabel('Open Monthly Badges'),
        350,
        scrollable: profileScroll,
      );
      await tester.ensureVisible(find.bySemanticsLabel('Open Monthly Badges'));
      await tester.pumpAndSettle();
      final profileOffset = tester
          .state<ScrollableState>(profileScroll)
          .position
          .pixels;
      final profilePosition = tester
          .state<ScrollableState>(profileScroll)
          .position;
      await tester.tap(find.bySemanticsLabel('Open Monthly Badges'));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Badges'), findsOneWidget);
      expect(find.text('2025 Badges'), findsOneWidget);
      final badgesScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const PageStorageKey('monthly-badges-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _scrollTo(tester, badgesScroll, find.text('2024 Badges'));
      expect(find.text('2024 Badges'), findsOneWidget);
      await _scrollTo(tester, badgesScroll, find.text('2023 Badges'));
      expect(find.text('2023 Badges'), findsOneWidget);
      expect(container.read(learningStateProvider).xp, xpBefore);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Open Monthly Badges'), findsOneWidget);
      expect(profilePosition.pixels, closeTo(profileOffset, 1));
      expect(container.read(learningStateProvider).xp, xpBefore);
    },
  );

  testWidgets('390 grid uses source-relative badge sizes and reveals 2024', (
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
          home: const MonthlyBadgesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final columnWidth = (390 - 40 - 16) / 3;
    final baselineColumnWidth = (390 - 40 - 16) / 3;
    final expectedScale = columnWidth / baselineColumnWidth / (1179 / 390);
    for (final label in ['January 2025, earned', 'November 2025, locked']) {
      final art = tester.widget<ReferenceArt>(
        find.descendant(
          of: find.bySemanticsLabel(label),
          matching: find.byType(ReferenceArt),
        ),
      );
      expect(art.width, closeTo(art.region.source.width * expectedScale, .01));
      expect(
        art.height,
        closeTo(art.region.source.height * expectedScale, .01),
      );
    }
    expect(find.text('2024 Badges').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 text2 badge tiles preserve crop aspect ratio responsively', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final badges = container.read(monthlyBadgesProvider);
    expect(badges, hasLength(27));
    expect(badges.take(12).every((badge) => badge.year == 2025), isTrue);
    expect(
      badges.skip(12).take(12).every((badge) => badge.year == 2024),
      isTrue,
    );
    expect(badges.skip(24).every((badge) => badge.year == 2023), isTrue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: referenceTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 760),
              textScaler: TextScaler.linear(2),
            ),
            child: const MonthlyBadgesScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final january = find.bySemanticsLabel('January 2025, earned');
    await tester.ensureVisible(january);
    await tester.pumpAndSettle();
    for (final badge in [
      january,
      find.bySemanticsLabel('November 2025, locked'),
    ]) {
      final art = tester.widget<ReferenceArt>(
        find.descendant(of: badge, matching: find.byType(ReferenceArt)),
      );
      expect(
        art.width / art.height,
        closeTo(art.region.source.width / art.region.source.height, .001),
      );
    }
    final november = tester.widget<ReferenceArt>(
      find.descendant(
        of: find.bySemanticsLabel('November 2025, locked'),
        matching: find.byType(ReferenceArt),
      ),
    );
    expect(november.height, greaterThan(november.width));
    expect(tester.getSize(january).height, lessThan(220));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollTo(
  WidgetTester tester,
  ScrollableState scrollable,
  Finder target,
) async {
  for (var attempt = 0; target.evaluate().isEmpty && attempt < 20; attempt++) {
    final position = scrollable.position;
    position.jumpTo(
      (position.pixels + 350).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
