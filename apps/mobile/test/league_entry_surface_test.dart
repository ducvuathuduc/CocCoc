import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/features/progress/presentation/league_entry_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('locked entry shows remaining count and starts one lesson', (
    tester,
  ) async {
    var starts = 0;
    var continues = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LeagueEntrySurface(
          remainingLessons: 8,
          onStartLesson: () => starts++,
          onContinue: () => continues++,
        ),
      ),
    );

    expect(find.byType(ReferenceArt), findsOneWidget);
    expect(find.textContaining('Finish 8 lessons'), findsOneWidget);
    expect(find.text('START A LESSON'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);

    await tester.tap(find.bySemanticsLabel('START A LESSON'));
    await tester.pump();
    expect(starts, 1);
    expect(continues, 0);
  });

  testWidgets('eligible entry shows source welcome and continues once', (
    tester,
  ) async {
    var starts = 0;
    var continues = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LeagueEntrySurface(
          remainingLessons: 0,
          onStartLesson: () => starts++,
          onContinue: () => continues++,
        ),
      ),
    );

    expect(find.text('Welcome to Leaderboards!'), findsOneWidget);
    expect(
      find.text(
        'Join other learners in a weekly contest.\n'
        'Earn XP from lessons to climb the ranks!',
      ),
      findsOneWidget,
    );
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('START A LESSON'), findsNothing);

    await tester.tap(find.bySemanticsLabel('CONTINUE'));
    await tester.pump();
    expect(continues, 1);
    expect(starts, 0);
  });

  testWidgets('320 wide text scale two can scroll to its action without clip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: LeagueEntrySurface(
          remainingLessons: 1,
          onStartLesson: () {},
          onContinue: () {},
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('START A LESSON'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.textContaining('Finish 1 lesson'), findsOneWidget);
    expect(find.text('START A LESSON'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
