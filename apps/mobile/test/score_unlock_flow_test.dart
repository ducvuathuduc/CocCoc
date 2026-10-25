import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/results/domain/score_unlock.dart';
import 'package:cocenglish/features/results/presentation/results_chain.dart';
import 'package:cocenglish/features/results/presentation/score_unlock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cocenglish/features/progress/application/score_information_controller.dart';

import 'features/gap/screen_pump.dart';
import 'support/app_fonts.dart';

const _receipt = SessionReceipt(
  id: 'first',
  nodeId: 'n1',
  xp: 20,
  accuracy: 1,
  elapsed: Duration(seconds: 30),
  firstCompletion: true,
  guest: false,
  placement: false,
);

void main() {
  setUpAll(loadAppFonts);
  test('only a claimed first demo completion exposes its existing score', () {
    const progress = LearningState(
      score: 5,
      completedLessons: 1,
      claimedReceiptIds: {'first'},
    );
    expect(
      scoreUnlockForReceipt(
        api: false,
        completionId: 'first',
        receipt: _receipt,
        progress: progress,
      ),
      5,
    );
    expect(
      scoreUnlockForReceipt(
        api: true,
        completionId: 'first',
        receipt: _receipt,
        progress: progress,
      ),
      isNull,
    );
    expect(
      scoreUnlockForReceipt(
        api: false,
        completionId: 'first',
        receipt: _receipt,
        progress: const LearningState(),
      ),
      isNull,
    );
    expect(
      scoreUnlockForReceipt(
        api: false,
        completionId: 'first',
        receipt: _receipt,
        progress: progress.copyWith(completedLessons: 2),
      ),
      isNull,
    );
    expect(
      scoreUnlockForReceipt(
        api: false,
        completionId: 'another-receipt',
        receipt: _receipt,
        progress: progress,
      ),
      isNull,
    );
  });
  test('a demo receipt is presented only once per tracker lifecycle', () {
    const progress = LearningState(
      score: 5,
      completedLessons: 1,
      claimedReceiptIds: {'first'},
    );
    final tracker = ScoreUnlockPresentationTracker(
      config: const AppConfig(),
      accountId: 'learner-1',
    );
    expect(
      tracker.take(
        completionId: 'first',
        receipt: _receipt,
        progress: progress,
      ),
      5,
    );
    expect(
      tracker.take(
        completionId: 'first',
        receipt: _receipt,
        progress: progress,
      ),
      isNull,
    );
  });
  for (final (size, scale) in [
    (const Size(360, 780), 1.0),
    (const Size(430, 932), 1.0),
    (const Size(320, 568), 2.0),
  ]) {
    testWidgets('score celebration continues once at $size/$scale', (t) async {
      var next = 0;
      await pumpScreen(
        t,
        '/celebration',
        ScoreUnlockScreen(score: 5, onContinue: () => next++),
        size: size,
        scale: scale,
      );
      expect(find.text('5'), findsOneWidget);
      expect(
        find.text('You unlocked your Duolingo\nEnglish Score!'),
        findsOneWidget,
      );
      await t.tap(find.text('CONTINUE'));
      await t.pump();
      await t.tap(find.text('CONTINUE'));
      await t.pump();
      expect(next, 1);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Score details return and copy preserve the celebration', (
    t,
  ) async {
    String? copied;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ScoreUnlockScreen(score: 5, onContinue: () {}),
        ),
        GoRoute(
          path: '/score',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Back from score'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          scoreClipboardWriterProvider.overrideWithValue((value) async {
            copied = value;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    final info = t.widget<TextButton>(
      find.widgetWithText(TextButton, 'MORE ABOUT SCORE'),
    );
    info.onPressed!();
    info.onPressed!();
    await t.pumpAndSettle();
    expect(find.text('Back from score', skipOffstage: false), findsOneWidget);
    await t.tap(find.text('Back from score'));
    await t.pumpAndSettle();
    final share = t.widget<IconButton>(find.byType(IconButton));
    share.onPressed!();
    share.onPressed!();
    await t.pumpAndSettle();
    expect(find.text('Share English Score'), findsOneWidget);
    await t.tap(find.text('COPY'));
    await t.pumpAndSettle();
    expect(copied, contains('5'));
    expect(find.text('Copied'), findsOneWidget);
    await t.tap(find.text('CLOSE'));
    await t.pumpAndSettle();
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('results chain freezes the initially accepted score', (t) async {
    Widget app(int? score) => ProviderScope(
      child: MaterialApp(
        home: ResultsChainScreen(
          unlockedScore: score,
          streakGrew: false,
          gemsEarned: false,
          guest: false,
          onFinished: () {},
          onCreateProfile: () {},
        ),
      ),
    );
    await t.pumpWidget(app(5));
    await t.pump();
    expect(find.byType(ScoreUnlockScreen), findsOneWidget);
    await t.pumpWidget(app(null));
    await t.pump();
    expect(find.byType(ScoreUnlockScreen), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
