import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/application/profile_summary_provider.dart';
import 'package:cocenglish/features/progress/application/profile_weekly_progress_provider.dart';
import 'package:cocenglish/features/progress/presentation/profile_weekly_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'canvas labels inherit font and repaint when typography changes',
    (tester) async {
      await tester.runAsync(() async {
        await (FontLoader(
          'DuolingoSans',
        )..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))).load();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      Future<CustomPainter> painterFor(String fontFamily) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: referenceTheme(),
              home: Scaffold(
                body: DefaultTextStyle(
                  style: TextStyle(fontFamily: fontFamily),
                  child: const ProfileWeeklyProgress(userId: 'James Smith'),
                ),
              ),
            ),
          ),
        );
        return tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('profile-weekly-chart')),
            )
            .painter!;
      }

      Future<List<int>> renderedLabels(CustomPainter painter) async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(310, 190));
        final picture = recorder.endRecording();
        final image = await picture.toImage(310, 190);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final copy = bytes!.buffer.asUint8List().toList(growable: false);
        image.dispose();
        picture.dispose();
        return copy;
      }

      final reference = await painterFor('DuolingoSans');
      final fallback = await painterFor('Ahem');
      expect(fallback.shouldRepaint(reference), isTrue);
      final referencePixels = await tester.runAsync(
        () => renderedLabels(reference),
      );
      final fallbackPixels = await tester.runAsync(
        () => renderedLabels(fallback),
      );
      expect(referencePixels, isNot(equals(fallbackPixels)));
      expect((await painterFor('Ahem')).shouldRepaint(fallback), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'weekly fixtures cover known profiles and expose immutable seven days',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final userId in sampleProfileIds) {
        final weekly = container.read(profileWeeklyProgressProvider(userId));
        final summary = container.read(profileSummaryProvider(userId));
        expect(weekly, isNotNull, reason: 'Missing weekly fixture for $userId');
        expect(weekly!.owner.points, hasLength(7));
        expect(weekly.you.points, hasLength(7));
        expect(weekly.owner.totalXp, lessThanOrEqualTo(summary!.xp));
        expect(() => weekly.owner.points.add(1), throwsUnsupportedError);
      }
      expect(container.read(profileWeeklyProgressProvider('Unknown')), isNull);
    },
  );

  test('learner receipts change only You weekly progress', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = container.read(profileWeeklyProgressProvider('Alex'))!;
    final foreignHeaderXp = container.read(profileSummaryProvider('Alex'))!.xp;

    container
        .read(learningStateProvider.notifier)
        .claim(
          const SessionReceipt(
            id: 'weekly-you',
            nodeId: 'weekly-node',
            xp: 99,
            accuracy: 1,
            elapsed: Duration(minutes: 2),
            firstCompletion: true,
            guest: false,
            placement: false,
          ),
        );
    final after = container.read(profileWeeklyProgressProvider('Alex'))!;

    expect(after.owner.points, before.owner.points);
    expect(after.owner.totalXp, before.owner.totalXp);
    expect(after.you.points.take(6), everyElement(0));
    expect(after.you.points.last, 99);
    expect(after.you.totalXp, 99);
    expect(container.read(profileSummaryProvider('Alex'))!.xp, foreignHeaderXp);
  });

  test('axis keeps a zero floor and expands for large learner values', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final initial = container.read(profileWeeklyProgressProvider('Alex'))!;
    expect(initial.axisTicks, hasLength(4));
    expect(initial.axisTicks.first, 0);
    expect(
      initial.axisMaximum,
      greaterThanOrEqualTo(
        initial.owner.points.reduce((a, b) => a > b ? a : b),
      ),
    );

    container
        .read(learningStateProvider.notifier)
        .claim(
          const SessionReceipt(
            id: 'weekly-large',
            nodeId: 'weekly-large-node',
            xp: 100000,
            accuracy: 1,
            elapsed: Duration(minutes: 2),
            firstCompletion: true,
            guest: false,
            placement: false,
          ),
        );
    final large = container.read(profileWeeklyProgressProvider('Alex'))!;
    expect(large.axisTicks.first, 0);
    expect(large.axisMaximum, greaterThanOrEqualTo(100000));
    expect(large.axisTicks, orderedEquals([...large.axisTicks]..sort()));
  });

  testWidgets('320 text2 chart remains accessible without overflow', (
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
                child: ProfileWeeklyProgress(userId: 'James Smith'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly progress'), findsOneWidget);
    expect(
      find.bySemanticsLabel('James Smith weekly progress, 132 XP'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('You weekly progress, 0 XP'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Weekly XP chart\. James Smith:')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
