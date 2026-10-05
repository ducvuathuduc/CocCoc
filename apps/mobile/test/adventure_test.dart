import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/practice/application/adventure_controller.dart';
import 'package:cocenglish/features/practice/presentation/adventure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'airport wrong answer preserves choice; retry and reward are idempotent',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(adventureControllerProvider.notifier);
      vm.start();
      vm.explore();
      vm.select('A dog!');
      vm.check();
      expect(c.read(adventureControllerProvider).selected, 'A dog!');
      expect(c.read(adventureControllerProvider).stage, 2);
      vm.next();
      expect(c.read(adventureControllerProvider).stage, 2);
      vm.select('An American passport!');
      vm.check();
      vm.check();
      expect(c.read(adventureControllerProvider).attempted, 2);
      vm.next();
      vm.next();
      expect(c.read(adventureControllerProvider).stage, 4);
      vm.explore();
      vm.select('passport');
      vm.check();
      vm.next();
      expect(c.read(adventureControllerProvider).complete, isTrue);
      expect(c.read(adventureControllerProvider).accuracy, 67);
      expect(vm.claim(), isTrue);
      expect(vm.claim(), isFalse);
      vm.start();
      expect(vm.claim(), isFalse);
    },
  );

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('airport native panels fit $width text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = ProviderContainer();
        addTearDown(c.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              theme: referenceTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: const AdventureScreen(),
              ),
            ),
          ),
        );
        final vm = c.read(adventureControllerProvider.notifier);
        for (final action in [
          vm.start,
          vm.explore,
          () {
            vm.select('An American passport!');
            vm.check();
          },
          vm.next,
          vm.next,
          vm.explore,
          () {
            vm.select('passport');
            vm.check();
          },
          vm.next,
        ]) {
          action();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Adventure complete!'), findsOneWidget);
      });
    }
  }
}
