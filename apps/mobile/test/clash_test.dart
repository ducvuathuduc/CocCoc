import 'package:cocenglish/features/practice/application/clash_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clash checks validated answer once and ends only after foreground sixty seconds', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(clashControllerProvider.notifier);
    vm.tick(100);
    expect(c.read(clashControllerProvider).remaining, 60);
    vm
      ..advance()
      ..advance()
      ..advance();
    expect(c.read(clashControllerProvider).stage, ClashStage.playing);
    vm.choose('unknown');
    expect(c.read(clashControllerProvider).answer, isEmpty);
    vm.choose('sister');
    expect(vm.check(), isTrue);
    expect(vm.check(), isFalse);
    expect(c.read(clashControllerProvider).correct, 1);
    vm.tick(10);
    expect(c.read(clashControllerProvider).remaining, 50);
    vm.tick(-1);
    expect(c.read(clashControllerProvider).remaining, 50);
    vm.tick(100);
    expect(c.read(clashControllerProvider).stage, ClashStage.timeUp);
    expect(c.read(clashControllerProvider).remaining, 0);
    vm.choose('school');
    expect(c.read(clashControllerProvider).answer, ['sister']);
    vm.advance();
    expect(c.read(clashControllerProvider).stage, ClashStage.waiting);
    vm.tick(5);
    vm.advance();
    expect(c.read(clashControllerProvider).correct, 1);
  });
  test(
    'word bank retains order, can remove and retry wrong without extra score',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(clashControllerProvider.notifier);
      vm
        ..advance()
        ..advance()
        ..advance()
        ..choose('school');
      expect(vm.check(), isTrue);
      expect(c.read(clashControllerProvider).correct, 0);
      vm.advance();
      vm
        ..choose('I')
        ..choose('am')
        ..choose('window')
        ..choose('window')
        ..choose('opening')
        ..choose('the')
        ..choose('window');
      expect(c.read(clashControllerProvider).answer, [
        'I',
        'am',
        'opening',
        'the',
        'window',
      ]);
      expect(vm.check(), isTrue);
      expect(vm.check(), isFalse);
      expect(c.read(clashControllerProvider).correct, 1);
      vm.quit();
      expect(c.read(clashControllerProvider).stage, ClashStage.intro);
      expect(c.read(clashControllerProvider).correct, 0);
    },
  );
}
