import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/api/client/idempotency.dart';
import '../../../core/config/app_config.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/data/progress_snapshot.dart';
import '../data/streak_repair_repository.dart';
import '../domain/streak_repair.dart';

final streakRepairRepositoryProvider = Provider<StreakRepairRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return MockStreakRepairRepository();
  return ApiStreakRepairRepository(
    ref.watch(apiEndpointsProvider),
    source: ref.watch(progressSnapshotSourceProvider),
  );
});
final streakRepairContentProvider = Provider<StreakRepairContent>(
  (ref) => ref.watch(streakRepairRepositoryProvider).content,
);
final streakRepairControllerProvider =
    NotifierProvider<StreakRepairController, StreakRepairState>(
      StreakRepairController.new,
    );

class StreakRepairController extends Notifier<StreakRepairState> {
  /// Reused across retries of the same offer so a timed-out request replays
  /// instead of spending a second time.
  String? _key;

  @override
  StreakRepairState build() => StreakRepairState(
    offer: ref.watch(streakRepairRepositoryProvider).loadOffer(),
  );

  Future<bool> repair(StreakRepairPayment payWith) async {
    final offer = state.offer;
    if (offer == null || state.busy || state.repaired) return false;
    final content = ref.read(streakRepairContentProvider);
    final apiMode = ref.read(appConfigProvider).isApi;
    final gems = payWith == StreakRepairPayment.gems;
    // The server owns the balance in API mode; the preview ledger is mock-only.
    if (!apiMode && gems && ref.read(previewWalletProvider) < offer.gemCost) {
      state = StreakRepairState(offer: offer, error: content.notEnoughGems);
      return false;
    }
    state = StreakRepairState(offer: offer, busy: true);
    bool ok;
    try {
      ok = await ref
          .read(streakRepairRepositoryProvider)
          .repair(offer, payWith, _key ??= UuidV4Generator().next());
    } catch (_) {
      ok = false;
    }
    if (!ref.mounted) return false;
    if (!ok) {
      state = StreakRepairState(offer: offer, error: content.failed);
      return false;
    }
    _key = null;
    if (!apiMode && gems) {
      ref.read(previewControllerProvider.notifier).spendGems(offer.gemCost);
    }
    final restored = ref
        .read(streakRepairRepositoryProvider)
        .lastRestoredStreak;
    state = StreakRepairState(repairedDays: restored ?? offer.lostDays);
    return true;
  }
}
