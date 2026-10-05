import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';

void main() {
  test('invalid reason or own profile never blocks or records a report', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(profileActionsProvider.notifier);
    expect(vm.reportAndBlock('me', 'Spam'), isFalse);
    expect(vm.reportAndBlock('Alex', 'invented'), isFalse);
    expect(vm.reportAndBlock('unknown', 'Spam'), isFalse);
    expect(c.read(profileActionsProvider).reports, isEmpty);
    expect(c.read(profileActionsProvider).blocked, isEmpty);
  });
  test('report once removes following; unblock never auto-follows', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(previewControllerProvider.notifier).follow('Alex');
    final vm = c.read(profileActionsProvider.notifier);
    expect(vm.reportAndBlock('Alex', 'Spam'), isTrue);
    expect(vm.reportAndBlock('Alex', 'Spam'), isFalse);
    expect(c.read(profileActionsProvider).reports.length, 1);
    expect(c.read(profileActionsProvider).blocked, contains('Alex'));
    expect(
      c.read(previewControllerProvider).following,
      isNot(contains('Alex')),
    );
    vm.unblock('Alex');
    expect(c.read(profileActionsProvider).blocked, isEmpty);
    expect(
      c.read(previewControllerProvider).following,
      isNot(contains('Alex')),
    );
  });
  test(
    'clipboard pending blocks duplicate; exact URL survives failure/retry',
    () async {
      final gate = Completer<void>();
      final urls = <String>[];
      var fail = true;
      final c = ProviderContainer(
        overrides: [
          profileClipboardWriterProvider.overrideWithValue((url) async {
            urls.add(url);
            if (urls.length == 1) await gate.future;
            if (fail) throw StateError('platform unavailable');
          }),
        ],
      );
      addTearDown(c.dispose);
      final vm = c.read(profileActionsProvider.notifier);
      final pending = vm.copyLink('Sam Lee');
      expect(await vm.copyLink('Sam Lee'), isFalse);
      expect(urls.length, 1);
      gate.complete();
      expect(await pending, isFalse);
      expect(c.read(profileActionsProvider).copyError, isNotNull);
      fail = false;
      expect(await vm.copyLink('Sam Lee'), isTrue);
      expect(urls, [
        profilePreviewUrl('Sam Lee'),
        profilePreviewUrl('Sam Lee'),
      ]);
      expect(c.read(profileActionsProvider).copyError, isNull);
      expect(c.read(profileActionsProvider).copiedUser, 'Sam Lee');
    },
  );
  test('disposing during platform copy has no stale state write', () async {
    final gate = Completer<void>();
    final c = ProviderContainer(
      overrides: [
        profileClipboardWriterProvider.overrideWithValue((_) => gate.future),
      ],
    );
    final pending = c.read(profileActionsProvider.notifier).copyLink('Alex');
    c.dispose();
    gate.complete();
    expect(await pending, isFalse);
  });
}
