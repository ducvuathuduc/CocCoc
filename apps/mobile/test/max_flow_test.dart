import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/application/max_controller.dart';
import 'package:cocenglish/features/progress/presentation/max_screen.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Max requires reminder and checkout, keeps existing entitlement until confirmation', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final existing = c.read(extendedControllerProvider.notifier);
    existing
      ..choosePlan('family')
      ..confirmPlan()
      ..invite('Sam');
    final vm = c.read(maxControllerProvider.notifier);
    expect(vm.confirmCheckout(), isFalse);
    vm
      ..next()
      ..next()
      ..next();
    expect(c.read(maxControllerProvider).stage, MaxStage.reminder);
    vm.chooseReminder(8);
    expect(c.read(maxControllerProvider).reminderDays, isNull);
    vm
      ..chooseReminder(3)
      ..next()
      ..choosePlan('max-individual');
    expect(c.read(extendedControllerProvider).plan, 'family');
    expect(vm.back(), isTrue);
    expect(c.read(maxControllerProvider).selectedPlan, 'max-individual');
    vm.next();
    expect(vm.confirmCheckout(), isTrue);
    expect(c.read(extendedControllerProvider).isMax, isTrue);
    expect(c.read(extendedControllerProvider).invited, isEmpty);
    existing.cancelPlan('Too expensive');
    expect(c.read(extendedControllerProvider).unlimited, isFalse);
    expect(c.read(maxControllerProvider).stage, MaxStage.offer);
    expect(c.read(maxControllerProvider).reminderDays, isNull);
    expect(c.read(maxControllerProvider).tourStep, -1);
  });
  test('Max Family preserves family members, individual plans remove stale invites', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(extendedControllerProvider.notifier);
    vm
      ..choosePlan('max-family')
      ..confirmPlan();
    expect(c.read(extendedControllerProvider).isFamily, isTrue);
    for (final name in ['Sam', 'Lea', 'Alex', 'Max', 'Mom']) {
      expect(vm.invite(name), isNull);
    }
    expect(vm.invite('Dad'), isNotNull);
    vm
      ..choosePlan('family')
      ..confirmPlan();
    expect(c.read(extendedControllerProvider).invited.length, 5);
    vm
      ..choosePlan('monthly')
      ..confirmPlan();
    expect(c.read(extendedControllerProvider).invited, isEmpty);
  });
  testWidgets(
    'routed mock checkout dismiss preserves selection and confirms only explicitly',
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
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Duolingo Max'), 180);
      await tester.tap(find.text('Duolingo Max'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TRY FOR \$0.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START MY FREE WEEK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('3 days before'));
      await tester.tap(find.text('3 days before'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START MY FREE WEEK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Family Plan'));
      await tester.tap(find.text('Family Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START MY FREE WEEK'));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byTooltip('Close checkout')),
      );
      expect(c.read(extendedControllerProvider).plan, isNull);
      await tester.tap(find.byTooltip('Close checkout'));
      await tester.pumpAndSettle();
      expect(c.read(maxControllerProvider).selectedPlan, 'max-family');
      await tester.tap(find.text('START MY FREE WEEK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('CONFIRM'));
      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();
      expect(c.read(extendedControllerProvider).plan, 'max-family');
      expect(find.text('Your plan is ready.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LET’S GO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SKIP'));
      await tester.pumpAndSettle();
      final tourIndex = c.read(maxControllerProvider).tourStep;
      final navigator = Navigator.of(tester.element(find.text('NEXT')));
      await navigator.maybePop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Duolingo Max'), 180);
      await tester.tap(find.text('Duolingo Max'));
      await tester.pumpAndSettle();
      expect(c.read(maxControllerProvider).tourStep, tourIndex);
      expect(find.text('NEXT'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Your 7-day trial is ready!'), findsOneWidget);
      await tester.tap(find.text('LET’S GO'));
      await tester.pumpAndSettle();
      expect(find.text('SECTION 1, UNIT 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Max states fit $width text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final vm = c.read(maxControllerProvider.notifier);
        Future<void> show(Widget screen) async {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: c,
              child: MaterialApp(
                theme: referenceTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        for (var i = 0; i < 4; i++) {
          await show(const MaxScreen());
          vm.chooseReminder(2);
          vm.next();
        }
        c.read(extendedControllerProvider.notifier)
          ..choosePlan('max-family')
          ..confirmPlan();
        for (var i = 0; i < 9; i++) {
          await show(const MaxTourScreen());
          vm.advanceTour();
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
