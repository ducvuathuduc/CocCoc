import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/completion_providers.dart';
import 'package:cocenglish/features/learning/data/completion_repository.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const resultReceipt = SessionReceipt(
  id: 'golden-completion',
  nodeId: 'node-0',
  xp: 20,
  accuracy: 1,
  elapsed: Duration(seconds: 58),
  firstCompletion: true,
  guest: false,
  placement: false,
);

class _ResultFixture extends LessonController {
  _ResultFixture(this.step, this.fixtureReceipt);
  final int step;
  final SessionReceipt fixtureReceipt;
  @override
  LessonState build() => LessonState(
    stage: LessonStage.completed,
    receipt: fixtureReceipt,
    resultStep: step,
    attempted: 10,
    originalCorrect: 10,
  );
}

class _ProgressFixture extends LearningStateController {
  @override
  LearningState build() => const LearningState(streak: 2, xp: 87);
}

Future<ProviderContainer> openResult(
  WidgetTester tester, {
  int step = 0,
  bool reduced = false,
  double width = 390,
  double height = 844,
  double scale = 1,
  CompletionRepository? completionRepository,
  SessionReceipt receipt = resultReceipt,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      if (completionRepository != null)
        completionRepositoryProvider.overrideWithValue(completionRepository),
      lessonControllerProvider.overrideWith(
        () => _ResultFixture(step, receipt),
      ),
      learningStateProvider.overrideWith(_ProgressFixture.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: referenceTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: RepaintBoundary(
            key: const ValueKey('completion-master-screen'),
            child: child!,
          ),
        ),
        home: const LessonResults(),
      ),
    ),
  );
  return container;
}

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

  testWidgets(
    '390x844 completion and celebration goldens never claim XP on a timer',
    (tester) async {
      final container = await openResult(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.byKey(const ValueKey('lesson-completion-confetti')),
        findsOneWidget,
      );
      await expectLater(
        find.byKey(const ValueKey('completion-master-screen')),
        matchesGoldenFile('goldens/ui_master/core_completion_celebrating.png'),
      );
      await tester.pumpAndSettle();
      expect(find.text('20'), findsOneWidget);
      expect(container.read(learningStateProvider).xp, 87);
      expect(container.read(learningStateProvider).claimedReceiptIds, isEmpty);
      await expectLater(
        find.byKey(const ValueKey('completion-master-screen')),
        matchesGoldenFile('goldens/ui_master/core_completion.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '390x844 streak counts to actual mock value and exposes final semantics',
    (tester) async {
      final container = await openResult(tester, step: 3);
      expect(find.bySemanticsLabel('Streak, 2 days'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('1'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(container.read(learningStateProvider).xp, 87);
      await expectLater(
        find.byKey(const ValueKey('completion-master-screen')),
        matchesGoldenFile('goldens/ui_master/core_streak.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'completion $width text $scale reduced motion retains claim CTA',
        (tester) async {
          await openResult(tester, reduced: true, width: width, scale: scale);
          await tester.pumpAndSettle();
          expect(find.text('CLAIM XP').hitTestable(), findsOneWidget);
          expect(
            find.byKey(const ValueKey('lesson-completion-confetti')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
