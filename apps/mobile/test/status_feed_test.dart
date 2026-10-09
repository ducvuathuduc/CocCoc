import 'package:cocenglish/features/progress/application/social_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('status draft cancels, commits, clears and rejects unknown IDs', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(statusControllerProvider.notifier);
    vm.begin();
    vm.choose('popcorn');
    vm.cancel();
    expect(c.read(statusControllerProvider).selected, isNull);
    expect(c.read(statusControllerProvider).draft, isNull);
    vm.choose('popcorn');
    expect(vm.save(), isTrue);
    vm.choose('invalid');
    expect(c.read(statusControllerProvider).draft, 'popcorn');
    vm.begin();
    vm.choose('eyes');
    expect(vm.save(), isFalse);
    expect(c.read(statusControllerProvider).selected, 'popcorn');
    vm.cancel();
    expect(c.read(statusControllerProvider).draft, 'popcorn');
    vm.clear();
    expect(c.read(statusControllerProvider).selected, isNull);
  });
  test('premium status checks internal wallet and buys only once per icon', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(statusControllerProvider.notifier);
    final wallet = c.read(previewControllerProvider.notifier);
    vm.choose('cool');
    expect(vm.purchaseSelected(), isFalse);
    expect(c.read(previewWalletProvider), 5);
    expect(c.read(statusControllerProvider).draft, 'cool');
    wallet.useDemoBalance();
    expect(vm.purchaseSelected(), isTrue);
    expect(c.read(previewWalletProvider), 535);
    expect(vm.purchaseSelected(), isFalse);
    expect(vm.save(), isTrue);
    vm.clear();
    vm.choose('cool');
    expect(vm.save(), isTrue);
    expect(c.read(previewWalletProvider), 535);
    vm.choose('eyes');
    expect(vm.purchaseSelected(), isTrue);
    expect(c.read(previewWalletProvider), 35);
    vm.choose('flex');
    expect(vm.purchaseSelected(), isFalse);
    expect(wallet.buyStatusIcon('invalid'), isFalse);
    expect(c.read(previewWalletProvider), 35);
  });
  test('suggested friends add once and never unfollow existing selections', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(feedControllerProvider.notifier);
    expect(vm.addSuggested(), 2);
    expect(vm.addSuggested(), 0);
    expect(c.read(previewControllerProvider).following, {'Alex', 'Sam Lee'});
    vm.toggleSuggestion('unknown');
    expect(c.read(feedControllerProvider).selectedSuggestions, {
      'Alex',
      'Sam Lee',
    });
    vm.toggleSuggestion('Alex');
    expect(vm.addSuggested(), 0);
    expect(c.read(previewControllerProvider).following, {'Alex', 'Sam Lee'});
  });
  test('feed reactions and validated comments preserve local state', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(feedControllerProvider.notifier);
    vm.like('stores');
    expect(c.read(feedControllerProvider).liked, {'stores'});
    vm.like('stores');
    vm.like('unknown');
    expect(c.read(feedControllerProvider).liked, isEmpty);
    expect(vm.comment('first-friend', '  Great job!  '), isNull);
    expect(c.read(feedControllerProvider).comments['first-friend'], [
      'Great job!',
    ]);
    expect(vm.comment('first-friend', '  '), isNotNull);
    expect(vm.comment('first-friend', 'x' * 281), isNotNull);
    expect(vm.comment('unknown', 'hi'), isNotNull);
    expect(c.read(feedControllerProvider).comments['first-friend'], [
      'Great job!',
    ]);
  });
}
