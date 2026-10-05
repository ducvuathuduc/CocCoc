import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'quest and purchase receipts are idempotent and reject invalid funds',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(previewControllerProvider.notifier);
      expect(controller.claimQuest('daily-2', eligible: false), false);
      expect(container.read(previewControllerProvider).bonusGems, 0);
      expect(controller.claimQuest('daily-2', eligible: true), true);
      expect(controller.claimQuest('daily-2', eligible: true), false);
      expect(container.read(previewControllerProvider).bonusGems, 10);
      expect(controller.buyFreeze('buy-1'), false);
      expect(container.read(previewControllerProvider).freezes, 0);
      expect(controller.buyFreeze('overspend'), false);
      expect(container.read(previewWalletProvider), 15);
      controller.useDemoBalance();
      expect(controller.buyFreeze('buy-2'), true);
      expect(controller.buyFreeze('buy-2'), false);
      expect(container.read(previewWalletProvider), 835);
      expect(container.read(previewControllerProvider).freezes, 1);
      expect(container.read(previewControllerProvider).spentGems, 200);
    },
  );
}
