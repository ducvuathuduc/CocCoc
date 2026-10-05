import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/practice/application/practice_controller.dart';
import 'package:cocenglish/features/practice/domain/practice_models.dart';
import 'package:cocenglish/features/practice/presentation/words_screen.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/presentation/super_screen.dart';
import 'package:cocenglish/features/progress/presentation/energy_screen.dart';
import 'package:cocenglish/features/learning/presentation/sections_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('extended screens fit width$width text$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final screen in const [
          WordsScreen(),
          SectionsScreen(),
          SectionDetailScreen(section: 1),
          EnergyScreen(),
          SuperScreen(),
          SuperTourScreen(),
          SubscriptionScreen(),
          CancelSubscriptionScreen(),
          FamilyPlanScreen(),
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: referenceTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: screen.runtimeType.toString(),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  test('plan checkout is local, selected, and cancellation clears unlimited energy', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(extendedControllerProvider.notifier);
    expect(vm.confirmPlan(), isFalse);
    vm.choosePlan('family');
    expect(vm.confirmPlan(), isTrue);
    expect(c.read(extendedControllerProvider).unlimited, isTrue);
    expect(c.read(extendedControllerProvider).plan, 'family');
    vm.cancelPlan();
    expect(c.read(extendedControllerProvider).unlimited, isFalse);
    expect(c.read(extendedControllerProvider).plan, isNull);
  });
  test('word sorting preserves recall and the current flashcard', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(practiceControllerProvider.notifier);
    vm.reveal();
    vm.remember();
    final before = c.read(practiceControllerProvider);
    vm.sort(WordSort.alphabetical);
    final after = c.read(practiceControllerProvider);
    expect(after.current?.id, before.current?.id);
    expect(after.recalledIds, before.recalledIds);
    expect(after.sortedWords.first.term, 'bear');
    vm.sort(WordSort.recent);
    expect(c.read(practiceControllerProvider).sortedWords.first.term, 'woman');
  });
  test(
    'family membership requires a family plan, deduplicates, and caps at six',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(extendedControllerProvider.notifier);
      expect(vm.invite('Sam'), 'Choose the Family Plan first.');
      vm
        ..choosePlan('family')
        ..confirmPlan();
      expect(vm.invite(' '), isNotNull);
      for (final name in ['Sam', 'Lea', 'Alex', 'Max', 'Mom']) {
        expect(vm.invite(name), isNull);
      }
      expect(vm.invite(' Sam '), isNull);
      expect(c.read(extendedControllerProvider).invited.length, 5);
      expect(vm.invite('Dad'), 'Your family has no more spaces.');
      vm.cancelPlan('Too expensive');
      expect(c.read(extendedControllerProvider).invited, isEmpty);
      expect(c.read(extendedControllerProvider).cancelReason, 'Too expensive');
    },
  );
  testWidgets('native words opens sort sheet and renders reordered rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: referenceTheme(), home: const WordsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Practice your\nEnglish words'), findsOneWidget);
    await tester.tap(find.text('SORT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alphabetically'));
    await tester.pumpAndSettle();
    final terms = tester
        .widgetList<Text>(find.byKey(const ValueKey('word-term')))
        .map((t) => t.data)
        .toList();
    expect(terms.first, 'bear');
    expect(find.text('Sort'), findsNothing);
  });
}
