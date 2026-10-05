import 'package:cocenglish/features/practice/application/journey_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/practice/presentation/journey_screens.dart';
import 'package:cocenglish/features/practice/presentation/challenge_intro.dart';

void main() {
  testWidgets('rapid clock pauses in background and on hidden routes', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(journeyControllerProvider('rapid').notifier);
    vm.start();
    Widget harness(bool visible) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: referenceTheme(),
        home: TickerMode(
          enabled: visible,
          child: const JourneyScreen(kind: 'rapid', clockEnabled: true),
        ),
      ),
    );
    await tester.pumpWidget(harness(true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final before = c.read(journeyControllerProvider('rapid')).remaining;
    expect(before, 103);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(c.read(journeyControllerProvider('rapid')).remaining, before);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(c.read(journeyControllerProvider('rapid')).remaining, 101);
    await tester.pumpWidget(harness(false));
    await tester.pump(const Duration(seconds: 10));
    expect(c.read(journeyControllerProvider('rapid')).remaining, 101);
    await tester.pumpWidget(harness(true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(c.read(journeyControllerProvider('rapid')).remaining, 99);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('challenge states fit width$width text$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final kind in ['rapid', 'legendary']) {
          final c = ProviderContainer();
          final vm = c.read(journeyControllerProvider(kind).notifier);
          Future<void> render(Widget page) async {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: c,
                child: MaterialApp(
                  theme: referenceTheme(),
                  home: page,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: kind);
          }

          await render(ChallengeIntroScreen(kind: kind));
          vm.start();
          await render(JourneyScreen(kind: kind, clockEnabled: false));
          while (!c.read(journeyControllerProvider(kind)).complete) {
            for (final word in vm.question!.answer) {
              vm.select(word);
            }
            vm
              ..check()
              ..next();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            vm.dismissMilestone();
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (kind == 'rapid') {
            vm
              ..start()
              ..tick(105);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          c.dispose();
        }
      });
    }
  }
  test(
    'rapid countdown expires, preserves input, and retry starts a fresh clock',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(journeyControllerProvider('rapid').notifier);
      vm.start();
      vm.select('that');
      vm.tick(104);
      expect(c.read(journeyControllerProvider('rapid')).remaining, 1);
      vm.tick(1);
      expect(c.read(journeyControllerProvider('rapid')).expired, true);
      expect(c.read(journeyControllerProvider('rapid')).selected, ['that']);
      vm.check();
      vm.next();
      vm.select('simple');
      expect(c.read(journeyControllerProvider('rapid')).step, 0);
      expect(c.read(journeyControllerProvider('rapid')).selected, ['that']);
      vm.start();
      expect(c.read(journeyControllerProvider('rapid')).remaining, 105);
      expect(c.read(journeyControllerProvider('rapid')).expired, false);
    },
  );
  test('challenge wrong answer retries the same exercise and completion freezes time', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(journeyControllerProvider('rapid').notifier);
    vm.start();
    vm.select('simple');
    vm.check();
    vm.next();
    expect(c.read(journeyControllerProvider('rapid')).step, 0);
    while (!c.read(journeyControllerProvider('rapid')).complete) {
      for (final word in vm.question!.answer) {
        vm.select(word);
      }
      vm
        ..check()
        ..next();
    }
    final done = c.read(journeyControllerProvider('rapid'));
    vm.tick(120);
    expect(c.read(journeyControllerProvider('rapid')), same(done));
    expect(done.correct, 4);
    expect(done.attempted, 5);
  });
  test(
    'Legendary has no ticking clock and does not advance on wrong feedback',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(journeyControllerProvider('legendary').notifier);
      vm.start();
      vm.tick(300);
      expect(c.read(journeyControllerProvider('legendary')).expired, false);
      for (final word in vm.question!.options) {
        vm.select(word);
      }
      vm.check();
      expect(c.read(journeyControllerProvider('legendary')).feedback, false);
      vm.next();
      expect(c.read(journeyControllerProvider('legendary')).step, 0);
    },
  );
}
