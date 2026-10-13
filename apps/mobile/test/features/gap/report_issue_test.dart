import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/report/application/issue_report_provider.dart';
import 'package:cocenglish/features/report/data/issue_report_repository.dart';
import 'package:cocenglish/features/report/domain/issue_report.dart';
import 'package:cocenglish/features/report/presentation/report_issue_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';
import '../../support/settle_images.dart';

/// Audit row 10: report an issue in a lesson (sc_f2f569c1 → sc_2082f9ab).
Future<(ProviderContainer, MockIssueReportRepository)> _pump(
  WidgetTester t, {
  bool reduced = true,
  bool succeed = true,
  double scale = 1,
}) async {
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final reports = MockIssueReportRepository(succeed: succeed);
  final container = ProviderContainer(
    overrides: [
      learningRepositoryProvider.overrideWithValue(
        MockLearningRepository(delay: Duration.zero, enforcesHearts: true),
      ),
      issueReportRepositoryProvider.overrideWithValue(reports),
    ],
  );
  addTearDown(container.dispose);
  final choice = mockEnglishExercises.firstWhere(
    (e) => e.kind == ExerciseKind.choice,
  );
  final image = mockEnglishExercises.firstWhere(
    (e) => e.kind == ExerciseKind.imageChoice,
  );
  await container
      .read(lessonControllerProvider.notifier)
      .start(exercises: [choice, image]);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(top: 56, bottom: 34),
          ),
          child: child!,
        ),
        home: const LessonScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  // Answer wrong so the feedback panel with its report flag is up.
  await t.tap(find.text('boy'));
  await t.pumpAndSettle();
  await t.tap(find.text('CHECK'));
  await t.pumpAndSettle();
  if (find.text('KEEP GOING').evaluate().isNotEmpty) {
    await t.tap(find.text('KEEP GOING'));
    await t.pumpAndSettle();
  }
  await settleImages(t);
  return (container, reports);
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await ReferenceArt.preloadFiles(['lesson-01', 'lesson-03', 'lesson-05']);
  });
  const categories = IssueReportContent();

  for (final reduced in [true, false]) {
    testWidgets('flag opens the action list and reports, reduced=$reduced', (
      t,
    ) async {
      final (c, reports) = await _pump(t, reduced: reduced);
      await t.tap(find.byTooltip('Report exercise'));
      if (!reduced) {
        await t.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey('report-issue-menu')), findsOneWidget);
      }
      await t.pumpAndSettle();
      for (final category in categories.categories) {
        expect(find.text(category), findsOneWidget);
      }
      await t.tap(find.text('The audio is missing.'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-issue-menu')), findsNothing);
      expect(find.text('Issue successfully reported!'), findsOneWidget);
      expect(reports.submitted.single.category, 'The audio is missing.');
      expect(reports.submitted.single.exerciseId, isNotEmpty);
      expect(c.read(previewControllerProvider).reports, [
        'The audio is missing.',
      ]);
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(find.text('Issue successfully reported!'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('dismissing the list reports nothing', (t) async {
    final (_, reports) = await _pump(t);
    await t.tap(find.byTooltip('Report exercise'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(350, 20));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-issue-menu')), findsNothing);
    expect(reports.submitted, isEmpty);
    expect(find.byType(IssueReportedToast), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed submit shows the repository error', (t) async {
    await _pump(t, succeed: false);
    await t.tap(find.byTooltip('Report exercise'));
    await t.pumpAndSettle();
    await t.tap(find.text('The hints are wrong.'));
    await t.pumpAndSettle();
    expect(find.text('Report not sent. Try again.'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('action list scrolls at text scale 2', (t) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    String? picked;
    await t.pumpWidget(
      MaterialApp(
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showReportIssueMenu(
                context,
                content: categories,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(
      find.text('Something else went wrong.'),
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('report-issue-menu')),
        matching: find.byType(Scrollable),
      ),
    );
    await t.tap(find.text('Something else went wrong.'));
    await t.pumpAndSettle();
    expect(picked, 'Something else went wrong.');
  });

  testWidgets('report menu and toast goldens at 360', (t) async {
    await _pump(t);
    await t.tap(find.byTooltip('Report exercise'));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/report_issue_menu_360.png'),
    );
    await t.tap(find.text('The audio is missing.'));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/report_issue_toast_360.png'),
    );
    await t.pump(const Duration(seconds: 3));
    await t.pumpWidget(const SizedBox.shrink());
  });

  test('menu motion tokens', () {
    expect(ReportMenuMotion.duration, const Duration(milliseconds: 250));
  });
}
