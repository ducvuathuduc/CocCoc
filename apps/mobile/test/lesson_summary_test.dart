import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/learning_visuals.dart';
import 'package:cocenglish/features/learning/presentation/lesson_summary.dart';
import 'package:flutter/material.dart';
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
}) => MaterialApp(
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
);

void main() {
  testWidgets('perfect summary uses medal art and actual receipt values', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_harness(_receipt()));

    expect(find.text('Flawless'), findsOneWidget);
    expect(
      find.text('0 mistakes. You’re like a pristine, freshwater pearl.'),
      findsOneWidget,
    );
    expect(find.text('24'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    final art = tester.widget<ReferenceArt>(find.byType(ReferenceArt));
    expect(art.region, LearningArt.medalDuo);
    expect(art.width, 245);
    expect(art.height, 245);
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
    var art = tester.widget<ReferenceArt>(find.byType(ReferenceArt));
    expect(art.region, LearningArt.completed);
    expect(art.width / art.height, closeTo(404 / 545, .001));

    await tester.pumpWidget(_harness(receipt, mistakes: 3));
    expect(
      find.text('3 mistakes reviewed. Keep up the great work!'),
      findsOneWidget,
    );
    art = tester.widget<ReferenceArt>(find.byType(ReferenceArt));
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
