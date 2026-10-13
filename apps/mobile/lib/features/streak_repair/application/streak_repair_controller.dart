import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/idempotency.dart';
import '../../progress/application/preview_controller.dart';
import '../data/streak_repair_repository.dart';
import '../domain/streak_repair.dart';

final streakRepairRepositoryProvider = Provider<StreakRepairRepository>(
  (ref) => MockStreakRepairRepository(),
);
final streakRepairContentProvider = Provider<StreakRepairContent>(
  (ref) => ref.watch(streakRepairRepositoryProvider).content,
);
final streakRepairControllerProvider =
    NotifierProvider<StreakRepairController, StreakRepairState>(
      StreakRepairController.new,
    );

class StreakRepairController extends Notifier<StreakRepairState> {
  @override
  StreakRepairState build() => StreakRepairState(
    offer: ref.watch(streakRepairRepositoryProvider).loadOffer(),
  );

  Future<bool> repair(StreakRepairPayment payWith) async {
    final offer = state.offer;
    if (offer == null || state.busy || state.repaired) return false;
    final content = ref.read(streakRepairContentProvider);
    final gems = payWith == StreakRepairPayment.gems;
    if (gems && ref.read(previewWalletProvider) < offer.gemCost) {
      state = StreakRepairState(offer: offer, error: content.notEnoughGems);
      return false;
    }
    state = StreakRepairState(offer: offer, busy: true);
    final ok = await ref
        .read(streakRepairRepositoryProvider)
        .repair(offer, payWith, UuidV4Generator().next());
    if (!ok) {
      state = StreakRepairState(offer: offer, error: content.failed);
      return false;
    }
    if (gems) {
      ref.read(previewControllerProvider.notifier).spendGems(offer.gemCost);
    }
    state = StreakRepairState(repairedDays: offer.lostDays);
    return true;
  }
}
