import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/year_review_controller.dart';
import 'package:cocenglish/features/progress/domain/year_review.dart';
import 'package:cocenglish/features/progress/presentation/year_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('historical fixture is English-only and remains dated 2025', () {
    expect(historical2025.year, 2025);
    expect(historical2025.course, 'English');
    expect(historical2025.lessons, 400);
    expect(historical2025.totalXp, 12949);
    expect(historical2025.percentile, 93);
    expect(historical2025.studentTopPercent, 8);
    expect(historical2025.league, 'Pearl');
    expect(historical2025.leagueWeeks, 2);
    expect(historical2025.englishScore, 19);
    expect(historical2025.longestStreak, 837);
    expect(historical2025.minutesSpent, 1374);
    expect(historical2025.asOf, DateTime(2025, 11, 30));
  });

  test('controller navigation is bounded and restart returns to intro', () {
    final container = ProviderContainer();
    final subscription = container.listen(
      yearReviewControllerProvider,
      (_, _) {},
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    final controller = container.read(yearReviewControllerProvider.notifier);

    controller.back();
    expect(container.read(yearReviewControllerProvider).index, 0);
    for (var i = 0; i < yearReviewPageCount + 2; i++) {
      controller.next();
    }
    expect(
      container.read(yearReviewControllerProvider).index,
      yearReviewPageCount - 1,
    );
    controller.restart();
    expect(container.read(yearReviewControllerProvider).index, 0);
  });

  test(
    'share copies one historical English summary and supports retry',
    () async {
      var attempts = 0;
      String? copiedValue;
      final container = ProviderContainer(
        overrides: [
          yearReviewClipboardWriterProvider.overrideWithValue((value) async {
            attempts += 1;
            copiedValue = value;
            if (attempts == 1) {
              throw PlatformException(code: 'clipboard-unavailable');
            }
          }),
        ],
      );
      final subscription = container.listen(
        yearReviewControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });
      final controller = container.read(yearReviewControllerProvider.notifier);

      expect(await controller.share(), isFalse);
      expect(
        container.read(yearReviewControllerProvider).shareError,
        isNotNull,
      );
      expect(await controller.share(), isTrue);
      expect(container.read(yearReviewControllerProvider).copied, isTrue);
      expect(copiedValue, contains('English'));
      expect(copiedValue, contains('2025'));
      expect(copiedValue, contains('12,949 XP'));
    },
  );

  test('programmer errors from the clipboard writer are not hidden', () async {
    final container = ProviderContainer(
      overrides: [
        yearReviewClipboardWriterProvider.overrideWithValue((_) {
          throw StateError('bad test wiring');
        }),
      ],
    );
    final subscription = container.listen(
      yearReviewControllerProvider,
      (_, _) {},
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });

    await expectLater(
      container.read(yearReviewControllerProvider.notifier).share(),
      throwsStateError,
    );
  });

  test(
    'disposing the route scope ignores a pending clipboard completion',
    () async {
      final gate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          yearReviewClipboardWriterProvider.overrideWithValue(
            (_) => gate.future,
          ),
        ],
      );
      container.listen(yearReviewControllerProvider, (_, _) {});
      final controller = container.read(yearReviewControllerProvider.notifier);
      final pending = controller.share();

      container.dispose();
      gate.complete();

      expect(await pending, isFalse);
    },
  );

  test(
    'restart invalidates stale share completion and permits retry',
    () async {
      final first = Completer<void>();
      final second = Completer<void>();
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          yearReviewClipboardWriterProvider.overrideWithValue((_) {
            attempts += 1;
            return attempts == 1 ? first.future : second.future;
          }),
        ],
      );
      final subscription = container.listen(
        yearReviewControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });
      final controller = container.read(yearReviewControllerProvider.notifier);

      final stale = controller.share();
      controller.restart();
      final retry = controller.share();
      second.complete();
      expect(await retry, isTrue);

      first.completeError(PlatformException(code: 'stale-clipboard-failure'));
      expect(await stale, isFalse);
      expect(container.read(yearReviewControllerProvider).copied, isTrue);
      expect(container.read(yearReviewControllerProvider).shareError, isNull);
    },
  );

  test('auto-dispose starts a later journey from the intro', () async {
    final container = ProviderContainer();
    final subscription = container.listen(
      yearReviewControllerProvider,
      (_, _) {},
    );
    container.read(yearReviewControllerProvider.notifier).next();
    expect(container.read(yearReviewControllerProvider).index, 1);

    subscription.close();
    await container.pump();

    expect(container.read(yearReviewControllerProvider).index, 0);
    container.dispose();
  });

  testWidgets(
    'seven native pages keep English copy and expose tap navigation',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: _Harness()));

      expect(find.text('Look back on your year of learning!'), findsOneWidget);
      expect(find.bySemanticsLabel('Close Year in Review'), findsOneWidget);

      for (var i = 0; i < 6; i++) {
        await _tapVisible(tester, i == 0 ? 'START' : 'NEXT');
      }

      expect(
        find.text('Share your progress and keep learning next year!'),
        findsOneWidget,
      );
      expect(find.text('English Score'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      expect(find.text('cocenglish'), findsOneWidget);
      expect(find.text('2025 YEAR IN REVIEW'), findsOneWidget);
      expect(find.text('I’m a top 8% learner!'), findsOneWidget);
      expect(find.textContaining('Nov. 30, 2025'), findsOneWidget);
      expect(find.textContaining('French'), findsNothing);
      expect(find.textContaining('Chess'), findsNothing);
      expect(find.textContaining('Music'), findsNothing);
      expect(find.bySemanticsLabel('SHARE FOR A REWARD'), findsOneWidget);
    },
  );

  testWidgets('normal-size vertical swipe advances the native PageView', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: _Harness()));
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('That’s twice the fun!', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('next and close expose real semantic tap actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const ProviderScope(child: _Harness()));

      expect(
        tester
            .getSemantics(find.bySemanticsLabel('START'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Close Year in Review'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reduced motion next jumps without a zero-duration animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const YearReviewScreen(),
            ),
          ),
        ),
      ),
    );

    await _tapVisible(tester, 'START');

    expect(
      find.textContaining('That’s twice the fun!', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320 wide text scale two can reach every action without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: referenceTheme(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: const YearReviewScreen(),
              ),
            ),
          ),
        ),
      );

      for (var i = 0; i < 6; i++) {
        final label = i == 0 ? 'START' : 'NEXT';
        await _tapVisible(tester, label);
      }
      await tester.ensureVisible(find.bySemanticsLabel('SHARE FOR A REWARD'));

      expect(find.bySemanticsLabel('SHARE FOR A REWARD'), findsOneWidget);
      expect(find.text('English Score'), findsOneWidget);
      expect(find.text('longest streak'), findsOneWidget);
      expect(find.text('total XP'), findsOneWidget);
      expect(find.text('minutes spent'), findsOneWidget);
      expect(find.byType(FittedBox), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clipboard failure remains on summary and retry reports copied', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          yearReviewClipboardWriterProvider.overrideWithValue((_) async {
            attempts += 1;
            if (attempts == 1) {
              throw PlatformException(code: 'clipboard-unavailable');
            }
          }),
        ],
        child: const _Harness(),
      ),
    );

    for (var i = 0; i < 6; i++) {
      await _tapVisible(tester, i == 0 ? 'START' : 'NEXT');
    }
    await _tapVisible(tester, 'SHARE FOR A REWARD');
    expect(find.text('Couldn’t copy. Try again.'), findsOneWidget);
    expect(find.bySemanticsLabel('RETRY SHARE'), findsOneWidget);

    await _tapVisible(tester, 'RETRY SHARE');
    expect(find.text('Copied'), findsOneWidget);
    expect(
      find.text('Share your progress and keep learning next year!'),
      findsOneWidget,
    );
  });
}

class _Harness extends StatelessWidget {
  const _Harness();

  @override
  Widget build(BuildContext context) =>
      MaterialApp(theme: referenceTheme(), home: const YearReviewScreen());
}

Future<void> _tapVisible(WidgetTester tester, String semanticsLabel) async {
  final target = find.bySemanticsLabel(semanticsLabel);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
