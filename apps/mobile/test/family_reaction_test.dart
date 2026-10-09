import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/application/family_reaction_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reaction sends only once to an invited member of active family', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final family = c.read(extendedControllerProvider.notifier),
        vm = c.read(familyReactionControllerProvider.notifier);
    expect(vm.send('Alex Smith'), isFalse);
    family
      ..choosePlan('max-family')
      ..confirmPlan()
      ..invite('Alex Smith');
    vm.select(2);
    expect(c.read(familyReactionControllerProvider).selected, 2);
    vm.select(99);
    expect(c.read(familyReactionControllerProvider).selected, 2);
    expect(vm.send('someone else'), isFalse);
    expect(vm.send('Alex Smith'), isTrue);
    expect(vm.send('Alex Smith'), isFalse);
    family.cancelPlan();
    expect(c.read(familyReactionControllerProvider).nudged, isEmpty);
    expect(vm.send('Alex Smith'), isFalse);
  });
}
