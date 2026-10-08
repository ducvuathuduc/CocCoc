import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/learning_path.dart';
import 'package:cocenglish/features/progress/application/score_information_controller.dart';
import 'package:cocenglish/features/progress/domain/score_information.dart';
import 'package:cocenglish/features/progress/presentation/score_information_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('official inclusive score boundaries map to nine bands', () {
    expect(
      [
        0,
        9,
        10,
        19,
        20,
        29,
        30,
        59,
        60,
        79,
        80,
        99,
        100,
        114,
        115,
        129,
        130,
        160,
      ].map(scoreBandIndex),
      [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8],
    );
  });

  test('range selection and playback never change learning score', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = container.read(learningStateProvider).score;
    final controller = container.read(scoreInformationProvider.notifier);

    controller.selectRange(8);
    expect(container.read(scoreInformationProvider).selectedRange, 8);
    expect(container.read(scoreInformationProvider).band.locked, isTrue);
    controller.selectRange(1);
    controller.play(0);
    expect(container.read(scoreInformationProvider).playingExample, 0);
    controller.play(1);
    expect(container.read(scoreInformationProvider).playingExample, 1);
    controller.pause();
    expect(container.read(scoreInformationProvider).playingExample, isNull);
    expect(container.read(learningStateProvider).score, before);
  });

  test(
    'clipboard work ignores duplicates and completion after disposal',
    () async {
      final write = Completer<void>();
      var writes = 0;
      final container = ProviderContainer(
        overrides: [
          scoreClipboardWriterProvider.overrideWithValue((_) {
            writes += 1;
            return write.future;
          }),
        ],
      );
      final controller = container.read(scoreInformationProvider.notifier);

      final pending = controller.copyScore(10);
      await controller.copyScore(10);
      expect(writes, 1);
      expect(container.read(scoreInformationProvider).copyBusy, isTrue);

      container.dispose();
      controller.pause();
      controller.resetCopyFeedback();
      write.complete();
      await pending;
    },
  );

  test(
    'reset invalidates stale clipboard completion and permits retry',
    () async {
      final first = Completer<void>();
      final second = Completer<void>();
      var writes = 0;
      final container = ProviderContainer(
        overrides: [
          scoreClipboardWriterProvider.overrideWithValue((_) {
            writes += 1;
            return writes == 1 ? first.future : second.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(scoreInformationProvider.notifier);

      final stale = controller.copyScore(10);
      controller.resetCopyFeedback();
      expect(container.read(scoreInformationProvider).copyBusy, isFalse);
      final retry = controller.copyScore(10);
      second.complete();
      await retry;
      expect(container.read(scoreInformationProvider).copied, isTrue);

      first.completeError(StateError('stale failure'));
      await stale;
      expect(writes, 2);
      expect(container.read(scoreInformationProvider).copied, isTrue);
      expect(container.read(scoreInformationProvider).copyError, isFalse);
    },
  );

  testWidgets('current high score scrolls its selected range into view', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    for (var index = 0; index < 26; index += 1) {
      container
          .read(learningStateProvider.notifier)
          .claim(
            SessionReceipt(
              id: 'high-score-$index',
              nodeId: 'node-$index',
              xp: 1,
              accuracy: 1,
              elapsed: const Duration(minutes: 1),
              firstCompletion: true,
              guest: false,
              placement: false,
            ),
          );
    }
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: referenceTheme(),
          home: const ScoreInformationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(learningStateProvider).score, 130);
    expect(
      find.byKey(const ValueKey('score-band-8')).hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Score 130–160'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('locked range, clipboard retry and narrow text2 remain usable', (
    tester,
  ) async {
    var attempts = 0;
    final router = GoRouter(
      initialLocation: '/score',
      routes: [
        GoRoute(
          path: '/score',
          builder: (_, _) => const ScoreInformationScreen(),
        ),
        GoRoute(
          path: '/profile/me',
          builder: (_, _) => const Scaffold(body: Text('profile-return')),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scoreClipboardWriterProvider.overrideWithValue((_) async {
            attempts += 1;
            if (attempts == 1) throw StateError('clipboard unavailable');
          }),
        ],
        child: MaterialApp.router(
          theme: referenceTheme(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('130–160'));
    await tester.pumpAndSettle();
    expect(
      find.text('Course content at this Score range is not yet available.'),
      findsOneWidget,
    );
    final selectedRange = tester.getSemantics(
      find.bySemanticsLabel('Score 130–160'),
    );
    expect(selectedRange.flagsCollection.isSelected, Tristate.isTrue);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Content between 130–160 will align with the ',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Share English Score'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COPY'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t copy. Try again.'), findsOneWidget);
    await tester.tap(find.text('COPY'));
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course panel derives score progress from learning state', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(learningStateProvider.notifier)
        .claim(
          const SessionReceipt(
            id: 'score-progress',
            nodeId: 'score-node',
            xp: 10,
            accuracy: 1,
            elapsed: Duration(minutes: 1),
            firstCompletion: true,
            guest: false,
            placement: false,
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: referenceTheme(),
          home: const Scaffold(body: LearningPath()),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Courses'));
    await tester.pump();
    expect(find.byKey(const ValueKey('course-score-start')), findsOneWidget);
    expect(find.text('Your English Score is 5'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('course-score-progress')),
    );
    expect(progress.value, .5);
  });

  testWidgets('playback pauses in background and timer is disposed safely', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: referenceTheme(),
          home: const ScoreInformationScreen(),
        ),
      ),
    );
    await tester.pump();
    container.read(scoreInformationProvider.notifier)
      ..selectRange(1)
      ..play(0);
    await tester.pump();
    expect(container.read(scoreInformationProvider).playingExample, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(container.read(scoreInformationProvider).playingExample, isNull);
    container.read(scoreInformationProvider.notifier).play(1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('close returns to the prior profile route', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/profile/me',
      routes: [
        GoRoute(
          path: '/profile/me',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.push('/score'),
                child: const Text('open-score'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/score',
          builder: (_, _) => const ScoreInformationScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: referenceTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.tap(find.text('open-score'));
    await tester.pumpAndSettle();
    container.read(scoreInformationProvider.notifier).play(0);
    expect(container.read(scoreInformationProvider).playingExample, 0);
    await tester.tap(find.byTooltip('Close score information'));
    await tester.pump();
    expect(container.read(scoreInformationProvider).playingExample, isNull);
    await tester.pumpAndSettle();
    expect(find.text('open-score'), findsOneWidget);
  });

  testWidgets('close returns with the course popover still open', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: LearningPath()),
        ),
        GoRoute(
          path: '/score',
          builder: (_, _) => const ScoreInformationScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: referenceTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Courses'));
    await tester.pump();
    await tester.tap(find.text('MORE ABOUT SCORE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close score information'));
    await tester.pumpAndSettle();
    expect(find.text('MORE ABOUT SCORE'), findsOneWidget);
  });
}
