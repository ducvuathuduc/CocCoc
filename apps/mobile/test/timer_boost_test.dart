import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/practice/application/journey_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/timer_boost_controller.dart';
import 'package:cocenglish/features/progress/presentation/timer_boost_screen.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/main.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boost purchase preserves insufficient selection, then spends once from demo balance', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(timerBoostControllerProvider.notifier);
    vm.begin();
    expect(c.read(timerBoostControllerProvider).pack, 5);
    vm.select(1);
    expect(vm.purchase(), isFalse);
    expect(c.read(previewControllerProvider).timerBoosts, 0);
    expect(c.read(previewControllerProvider).spentGems, 0);
    expect(c.read(timerBoostControllerProvider).pack, 1);
    expect(c.read(timerBoostControllerProvider).error, isNotNull);
    c.read(previewControllerProvider.notifier).useDemoBalance();
    expect(c.read(previewWalletProvider), 1035);
    expect(vm.purchase(), isTrue);
    expect(vm.purchase(), isFalse);
    expect(c.read(previewWalletProvider), 585);
    expect(c.read(previewControllerProvider).timerBoosts, 1);
    c.read(previewControllerProvider.notifier).useDemoBalance();
    expect(c.read(previewWalletProvider), 585);
    vm.begin();
    vm.select(99);
    expect(c.read(timerBoostControllerProvider).pack, 1);
    expect(c.read(timerBoostControllerProvider).error, isNull);
  });
  test('ledger validates boost pack and duplicate receipt without trusting a supplied price', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(previewControllerProvider.notifier);
    vm.useDemoBalance();
    expect(vm.buyTimerBoost('receipt-a', 99), isFalse);
    expect(vm.buyTimerBoost('receipt-a', 1), isTrue);
    expect(vm.buyTimerBoost('receipt-a', 1), isFalse);
    expect(vm.buyTimerBoost('receipt-b', 5), isFalse);
    expect(c.read(previewWalletProvider), 585);
    expect(c.read(previewControllerProvider).timerBoosts, 1);
  });
  test(
    'one owned boost resumes only expired rapid question and preserves answer',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final rapid = c.read(journeyControllerProvider('rapid').notifier);
      final ledger = c.read(previewControllerProvider.notifier);
      ledger.useDemoBalance();
      ledger.buyTimerBoost('owned', 1);
      expect(rapid.useTimerBoost(), isFalse);
      rapid.start();
      rapid.select(rapid.question!.options.first);
      final selected = c.read(journeyControllerProvider('rapid')).selected;
      rapid.tick(105);
      expect(rapid.useTimerBoost(), isTrue);
      final resumed = c.read(journeyControllerProvider('rapid'));
      expect(resumed.remaining, 60);
      expect(resumed.expired, isFalse);
      expect(resumed.selected, selected);
      expect(c.read(previewControllerProvider).timerBoosts, 0);
      expect(rapid.useTimerBoost(), isFalse);
      rapid.tick(60);
      expect(rapid.useTimerBoost(), isFalse);
      expect(c.read(journeyControllerProvider('rapid')).expired, isTrue);
    },
  );
  testWidgets(
    'real modal retains dismissed choice and purchase returns to paused rapid question',
    (tester) async {
      await tester.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byTooltip('Practice'));
      final c = ProviderScope.containerOf(context);
      final rapid = c.read(journeyControllerProvider('rapid').notifier);
      rapid.start();
      rapid.select(rapid.question!.options.first);
      final selected = c.read(journeyControllerProvider('rapid')).selected;
      rapid.tick(105);
      GoRouter.of(context).push('/journeys/rapid/session');
      await tester.pumpAndSettle();
      await tester.tap(find.text('GET TIMER BOOSTS'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Single'));
      await tester.tap(find.text('Single'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NO THANKS'));
      await tester.pumpAndSettle();
      expect(c.read(previewControllerProvider).spentGems, 0);
      await tester.tap(find.text('GET TIMER BOOSTS'));
      await tester.pumpAndSettle();
      expect(c.read(timerBoostControllerProvider).pack, 1);
      await tester.tap(find.text('GET TIMER BOOSTS').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('USE DEMO BALANCE'));
      await tester.tap(find.text('USE DEMO BALANCE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GET TIMER BOOSTS').last);
      await tester.pumpAndSettle();
      expect(find.text('Timer Boost\n+1'), findsOneWidget);
      await tester.tap(find.text('BACK TO CHALLENGE'));
      await tester.pumpAndSettle();
      expect(c.read(journeyControllerProvider('rapid')).expired, isTrue);
      await tester.tap(find.text('USE TIMER BOOST +60s'));
      await tester.tap(find.text('USE TIMER BOOST +60s'));
      await tester.pump();
      expect(find.byType(TimerBoostOffer), findsNothing);
      expect(c.read(previewControllerProvider).timerBoosts, 0);
      expect(c.read(journeyControllerProvider('rapid')).selected, selected);
      await tester.pump(const Duration(seconds: 2));
      final remaining = c.read(journeyControllerProvider('rapid')).remaining;
      expect(remaining, lessThan(60));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 5));
      expect(c.read(journeyControllerProvider('rapid')).remaining, remaining);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(
        c.read(journeyControllerProvider('rapid')).remaining,
        lessThan(remaining),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Shop modal at width360 text2 purchases and Home shows the same wallet',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byTooltip('Shop')),
      );
      await tester.tap(find.byTooltip('Shop'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('GET'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('GET'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Single'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Single'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GET TIMER BOOSTS'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('USE DEMO BALANCE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USE DEMO BALANCE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GET TIMER BOOSTS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BACK TO SHOP'));
      await tester.pumpAndSettle();
      expect(find.text('585'), findsOneWidget);
      expect(c.read(previewControllerProvider).timerBoosts, 1);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('585'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('boost offer and success render width$width text$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = ProviderContainer();
        addTearDown(c.dispose);
        c.read(timerBoostControllerProvider.notifier).begin();
        Widget frame(Widget child) => UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: referenceTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: child,
            ),
          ),
        );
        await tester.pumpWidget(frame(const Scaffold(body: TimerBoostOffer())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Single'));
        await tester.tap(find.text('Single'));
        await tester.pumpAndSettle();
        expect(c.read(timerBoostControllerProvider).pack, 1);
        await tester.ensureVisible(find.text('GET TIMER BOOSTS'));
        await tester.tap(find.text('GET TIMER BOOSTS'));
        await tester.pumpAndSettle();
        expect(find.text('Not enough gems'), findsOneWidget);
        await tester.ensureVisible(find.text('USE DEMO BALANCE'));
        await tester.tap(find.text('USE DEMO BALANCE'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('GET TIMER BOOSTS'));
        await tester.tap(find.text('GET TIMER BOOSTS'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(frame(const TimerBoostSuccessScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Timer Boost\n+1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
