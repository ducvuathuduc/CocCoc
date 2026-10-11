import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/completion_providers.dart';
import 'package:cocenglish/features/learning/data/completion_repository.dart';
import 'package:cocenglish/features/learning/domain/completion_summary.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/learning_visuals.dart';
import 'package:cocenglish/features/learning/presentation/lesson_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SessionReceipt _receipt({
  int xp = 24,
  double accuracy = 1,
  Duration elapsed = const Duration(minutes: 1, seconds: 5),
  bool guest = false,
  bool placement = false,
}) => SessionReceipt(
  id: 'summary-receipt',
  nodeId: 'summary-node',
  xp: xp,
  accuracy: accuracy,
  elapsed: elapsed,
  firstCompletion: true,
  guest: guest,
  placement: placement,
);

Widget _harness(
  SessionReceipt receipt, {
  int mistakes = 0,
  double textScale = 1,
  bool reducedMotion = false,
}) => ProviderScope(
  child: MaterialApp(
    theme: referenceTheme(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: LessonSummary(receipt: receipt, mistakeCount: mistakes),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('430 completion preserves the source illustration proportions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_harness(_receipt()));
    await tester.pumpAndSettle();
    final art = tester.widget<ReferenceArt>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ReferenceArt && widget.region == LearningArt.medalDuo,
      ),
    );
    expect(art.width, closeTo(430 * 772 / 1180, .01));
    expect(art.height, closeTo(430 * 771 / 1180, .01));
  });

  testWidgets('overriding only the repository replaces completion content', (
    tester,
  ) async {
    final repository = _AlternateCompletionRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [completionRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: referenceTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: LessonSummary(receipt: _receipt(), mistakeCount: 3),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.receivedMistakes, 3);
    expect(repository.receivedReceipt?.xp, 24);
    expect(find.text('A fresh result'), findsOneWidget);
    expect(find.text('Repository description'), findsOneWidget);
    expect(find.text('POINTS'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);
    expect(find.text('RECALL'), findsOneWidget);
    expect(find.text('82%'), findsOneWidget);
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('2:13'), findsOneWidget);
    expect(find.bySemanticsLabel('Points, 37'), findsOneWidget);
    expect(find.text('24'), findsNothing);
  });

  testWidgets('completion stat labels match the inspected source variants', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_receipt()));
    await tester.pumpAndSettle();
    expect(find.text('TOTAL XP'), findsOneWidget);
    expect(find.text('AMAZING'), findsOneWidget);
    expect(find.text('BLAZING'), findsOneWidget);
    await tester.pumpWidget(_harness(_receipt(accuracy: .94), mistakes: 1));
    await tester.pumpAndSettle();
    expect(find.text('GREAT'), findsOneWidget);
    expect(find.text('QUICK'), findsOneWidget);
  });

  testWidgets('perfect summary uses medal art and actual receipt values', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_harness(_receipt()));
    await tester.pumpAndSettle();

    expect(find.text('Flawless'), findsOneWidget);
    expect(
      find.text('0 mistakes. You’re like a pristine, freshwater pearl.'),
      findsOneWidget,
    );
    expect(find.text('24'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    final art = tester.widget<ReferenceArt>(_summaryArt());
    expect(art.region, LearningArt.medalDuo);
    expect(art.width, closeTo(390 * 772 / 1180, .01));
    expect(art.height, closeTo(390 * 771 / 1180, .01));
    final statRects = [
      tester.getRect(find.byKey(const Key('lesson-summary-stat-xp'))),
      tester.getRect(find.byKey(const Key('lesson-summary-stat-accuracy'))),
      tester.getRect(find.byKey(const Key('lesson-summary-stat-time'))),
    ];
    expect(statRects.map((rect) => rect.top).toSet(), hasLength(1));
    expect(statRects.map((rect) => rect.bottom).toSet(), hasLength(1));
  });

  testWidgets('imperfect summary distinguishes singular and plural mistakes', (
    tester,
  ) async {
    final receipt = _receipt(xp: 9, accuracy: .75);
    await tester.pumpWidget(_harness(receipt, mistakes: 1));

    expect(find.text('Lesson complete!'), findsOneWidget);
    expect(
      find.text('1 mistake reviewed. Keep up the great work!'),
      findsOneWidget,
    );
    var art = tester.widget<ReferenceArt>(_summaryArt());
    expect(art.region, LearningArt.completed);
    expect(art.width / art.height, closeTo(404 / 545, .001));

    await tester.pumpWidget(_harness(receipt, mistakes: 3));
    expect(
      find.text('3 mistakes reviewed. Keep up the great work!'),
      findsOneWidget,
    );
    art = tester.widget<ReferenceArt>(_summaryArt());
    expect(art.region, LearningArt.completed);
  });

  testWidgets('guest and placement receipts use simple practice copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_receipt(xp: 0, accuracy: .8, guest: true), mistakes: 2),
    );

    expect(find.text('Practice complete'), findsOneWidget);
    expect(find.textContaining('mistake'), findsNothing);
    expect(find.textContaining('ranked'), findsNothing);
    expect(find.textContaining('reward'), findsNothing);

    await tester.pumpWidget(
      _harness(_receipt(xp: 0, accuracy: .8, placement: true), mistakes: 2),
    );
    expect(find.text('Practice complete'), findsOneWidget);
    expect(find.textContaining('mistake'), findsNothing);
  });

  testWidgets('stats expose spoken-reader labels with actual data', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _harness(
          _receipt(
            xp: 17,
            accuracy: .83,
            elapsed: const Duration(minutes: 2, seconds: 1),
          ),
          mistakes: 2,
        ),
      );

      expect(find.bySemanticsLabel('Total XP, 17'), findsOneWidget);
      expect(find.bySemanticsLabel('Accuracy, 83 percent'), findsOneWidget);
      expect(find.bySemanticsLabel('Time, 2 minutes 1 second'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('320 text two and reduced motion stack without clipping', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _harness(
        _receipt(accuracy: .67, elapsed: const Duration(seconds: 49)),
        mistakes: 2,
        textScale: 2,
        reducedMotion: true,
      ),
    );

    expect(tester.takeException(), isNull);
    final xp = tester.getTopLeft(
      find.byKey(const Key('lesson-summary-stat-xp')),
    );
    final accuracy = tester.getTopLeft(
      find.byKey(const Key('lesson-summary-stat-accuracy')),
    );
    final time = tester.getTopLeft(
      find.byKey(const Key('lesson-summary-stat-time')),
    );
    expect(accuracy.dy, greaterThan(xp.dy));
    expect(time.dy, greaterThan(accuracy.dy));
    expect(find.text('24'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('0:49'), findsOneWidget);
    expect(find.bySemanticsLabel('Time, 49 seconds'), findsOneWidget);
  });
}

Finder _summaryArt() => find.byWidgetPredicate(
  (widget) =>
      widget is ReferenceArt &&
      (widget.region == LearningArt.medalDuo ||
          widget.region == LearningArt.completed),
);

class _AlternateCompletionRepository implements CompletionRepository {
  SessionReceipt? receivedReceipt;
  int? receivedMistakes;

  @override
  CompletionStreak streak(int days) =>
      const MockCompletionRepository().streak(days);

  @override
  CompletionSummary summary(
    SessionReceipt receipt, {
    required int mistakeCount,
  }) {
    receivedReceipt = receipt;
    receivedMistakes = mistakeCount;
    return const CompletionSummary(
      title: 'A fresh result',
      description: 'Repository description',
      perfect: true,
      claimLabel: 'REVIEW RESULT',
      xp: CompletionStat(
        label: 'POINTS',
        semanticLabel: 'Points, 37',
        value: '37',
        animatedValue: 37,
      ),
      accuracy: CompletionStat(
        label: 'RECALL',
        semanticLabel: 'Recall, 82 percent',
        value: '82%',
        animatedValue: 82,
        suffix: '%',
      ),
      time: CompletionStat(
        label: 'DURATION',
        semanticLabel: 'Duration, 2 minutes 13 seconds',
        value: '2:13',
      ),
    );
  }
}
