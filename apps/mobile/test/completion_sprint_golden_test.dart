import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_widgets.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/completion_repository.dart';
import 'package:cocenglish/features/learning/domain/completion_summary.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'completion_ui_master_golden_test.dart' as fixture;

const _referenceReceipt = SessionReceipt(
  id: 'source-completion',
  nodeId: 'node-0',
  xp: 10,
  accuracy: 1,
  elapsed: Duration(seconds: 58),
  firstCompletion: true,
  guest: false,
  placement: false,
);

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
    await ReferenceArt.preloadFiles(['results-02', 'lesson-18']);
  });

  test('two-day streak projects the archived calendar window', () {
    final streak = const MockCompletionRepository().streak(2);
    expect(streak.week.map((day) => day.label), [
      'We',
      'Th',
      'Fr',
      'Sa',
      'Su',
      'Mo',
      'Tu',
    ]);
    expect(streak.week.where((day) => day.practiced).length, 2);
  });

  testWidgets('430 metric spacing retains the reference card gaps', (
    tester,
  ) async {
    await fixture.openResult(tester, width: 430, height: 932, reduced: true);
    await tester.pumpAndSettle();
    final xp = tester.getRect(find.byKey(const Key('lesson-summary-stat-xp')));
    final accuracy = tester.getRect(
      find.byKey(const Key('lesson-summary-stat-accuracy')),
    );
    expect(accuracy.left - xp.right, closeTo(52 * 430 / 1180, .1));
    final label = tester.widget<Text>(find.text('AMAZING'));
    expect(label.style!.height, 1);
    final action = tester.widget<ReferenceButton>(find.byType(ReferenceButton));
    expect(action.textStyle!.fontSize, closeTo(16 * 430 / 390, .01));
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('completion $width text $scale source-copy golden', (
        tester,
      ) async {
        final container = await fixture.openResult(
          tester,
          width: width,
          height: width == 430 ? 932 : 800,
          scale: scale,
          reduced: true,
          receipt: _referenceReceipt,
        );
        await tester.pumpAndSettle();
        expect(find.text('AMAZING'), findsOneWidget);
        expect(find.text('BLAZING'), findsOneWidget);
        expect(find.text('CLAIM XP').hitTestable(), findsOneWidget);
        expect(
          tester.getSize(find.byType(TextButton)).height,
          greaterThanOrEqualTo(48),
        );
        expect(container.read(learningStateProvider).xp, 87);
        expect(
          container.read(learningStateProvider).claimedReceiptIds,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('completion-master-screen')),
          matchesGoldenFile(
            'goldens/ui_master/sprint_completion_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
        if (scale == 2) {
          await tester.ensureVisible(
            find.byKey(const Key('lesson-summary-stat-time')),
          );
          await tester.pumpAndSettle();
          expect(find.text('BLAZING').hitTestable(), findsOneWidget);
          expect(find.text('CLAIM XP').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
      testWidgets('completion streak $width text $scale golden', (
        tester,
      ) async {
        final container = await fixture.openResult(
          tester,
          step: 3,
          width: width,
          height: width == 430 ? 932 : 800,
          scale: scale,
          reduced: true,
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Streak, 2 days'), findsOneWidget);
        expect(find.text('I’M COMMITTED').hitTestable(), findsOneWidget);
        expect(
          tester.getSize(find.byType(TextButton)).height,
          greaterThanOrEqualTo(48),
        );
        expect(container.read(learningStateProvider).streak, 2);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('completion-master-screen')),
          matchesGoldenFile(
            'goldens/ui_master/sprint_completion_streak_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
        if (scale == 2) {
          await tester.ensureVisible(
            find.text(
              'Practicing daily grows your streak,\nbut skipping a day resets it!',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Tu').hitTestable(), findsOneWidget);
          expect(find.text('I’M COMMITTED').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('repository alone replaces streak copy, calendar and action', (
    tester,
  ) async {
    final container = await fixture.openResult(
      tester,
      step: 3,
      reduced: true,
      completionRepository: _AlternateStreakRepository(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Consistency'), findsOneWidget);
    expect(find.text('One steady habit.'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Mo'), findsNothing);
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(container.read(lessonControllerProvider).resultStep, 4);
    expect(container.read(learningStateProvider).streak, 2);
    expect(container.read(learningStateProvider).xp, 87);
  });
}

class _AlternateStreakRepository implements CompletionRepository {
  @override
  CompletionSummary summary(
    SessionReceipt receipt, {
    required int mistakeCount,
  }) => const MockCompletionRepository().summary(
    receipt,
    mistakeCount: mistakeCount,
  );

  @override
  CompletionStreak streak(int days) => CompletionStreak(
    days: days,
    semanticLabel: 'Streak, $days days',
    title: 'Consistency',
    description: 'One steady habit.',
    commitLabel: 'Keep going',
    week: const [
      CompletionStreakDay('First', practiced: false),
      CompletionStreakDay('Second', practiced: true),
    ],
  );
}
