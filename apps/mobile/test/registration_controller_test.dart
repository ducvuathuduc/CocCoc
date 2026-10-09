import 'package:cocenglish/features/account/application/registration_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registration preserves input on duplicate email and clears password after success', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(registrationControllerProvider.notifier);
    vm.edit(age: '25');
    await vm.next();
    vm.edit(first: 'Sam', last: 'Lee');
    await vm.next();
    vm.edit(email: 'demo@cocenglish.test');
    await vm.next();
    vm.edit(password: 'long-demo-password');
    await vm.next();
    expect(c.read(registrationControllerProvider).step, 3);
    expect(c.read(registrationControllerProvider).error, isNotNull);
    expect(
      c.read(registrationControllerProvider).password,
      'long-demo-password',
    );
    vm.edit(email: 'sam@example.test');
    await vm.next();
    expect(c.read(registrationControllerProvider).step, 4);
    expect(c.read(registrationControllerProvider).password, isEmpty);
    expect(c.read(previewControllerProvider).name, 'Sam Lee');
  });
  test('invalid age does not advance and Back keeps existing names', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(registrationControllerProvider.notifier);
    vm.edit(age: '-1');
    await vm.next();
    expect(c.read(registrationControllerProvider).step, 0);
    vm.edit(age: '25');
    await vm.next();
    vm.edit(first: 'Alex');
    vm.back();
    expect(c.read(registrationControllerProvider).first, 'Alex');
  });
}
