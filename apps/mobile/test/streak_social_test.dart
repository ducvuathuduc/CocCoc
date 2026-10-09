import 'package:cocenglish/features/progress/application/streak_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incoming accept is validated, once-only and reserves one slot', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(streakControllerProvider.notifier);
    expect(vm.accept('unknown'), isFalse);
    expect(vm.accept('alex'), isTrue);
    expect(vm.accept('alex'), isFalse);
    expect(c.read(streakControllerProvider).remaining, 4);
    expect(
      c.read(streakControllerProvider).friends['alex'],
      FriendStreakStatus.active,
    );
    expect(c.read(streakControllerProvider).incoming, isEmpty);
  });
  test(
    'declining frees candidate, invitation and removal cannot duplicate',
    () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(streakControllerProvider.notifier);
      expect(vm.invite('alex'), isFalse);
      expect(vm.decline('alex'), isTrue);
      expect(vm.decline('alex'), isFalse);
      expect(vm.invite('alex'), isTrue);
      expect(vm.invite('alex'), isFalse);
      expect(vm.invite('unknown'), isFalse);
      expect(
        c.read(streakControllerProvider).friends['alex'],
        FriendStreakStatus.pending,
      );
      expect(vm.remove('alex'), isTrue);
      expect(vm.remove('alex'), isFalse);
      expect(c.read(streakControllerProvider).remaining, 5);
    },
  );
  test('all five candidates reserve slots without overfilling', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(streakControllerProvider.notifier);
    vm.decline('alex');
    for (final person in streakPeople) {
      expect(vm.invite(person.id), isTrue);
    }
    expect(c.read(streakControllerProvider).remaining, 0);
    expect(vm.invite('alex'), isFalse);
  });
  test('calendar crosses year and switching personal clears edit without losing friends', () {
    final c = ProviderContainer(
      overrides: [streakClockProvider.overrideWithValue(DateTime(2026, 1, 5))],
    );
    addTearDown(c.dispose);
    final vm = c.read(streakControllerProvider.notifier);
    vm.changeMonth(-1);
    expect(c.read(streakControllerProvider).month, DateTime(2025, 12));
    vm.changeMonth(1);
    expect(c.read(streakControllerProvider).month, DateTime(2026, 1));
    vm.accept('alex');
    vm.selectFriends(true);
    vm.toggleEdit();
    vm.selectFriends(false);
    expect(c.read(streakControllerProvider).editing, isFalse);
    expect(c.read(streakControllerProvider).friends.length, 1);
  });
}
