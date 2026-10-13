import '../domain/streak_repair.dart';

abstract class StreakRepairRepository {
  StreakRepairContent get content;

  /// The repairable lost streak, or null when nothing can be repaired.
  StreakRepairOffer? loadOffer();

  /// Repairs [offer]'s streak; false when the server refuses it.
  Future<bool> repair(
    StreakRepairOffer offer,
    StreakRepairPayment payWith,
    String idempotencyKey,
  );
}

/// In-memory repair. A fresh learner has never lost a streak, so the default
/// mock has no offer; fixtures pass [offer] to exercise the flow.
class MockStreakRepairRepository implements StreakRepairRepository {
  MockStreakRepairRepository({
    this.offer,
    this.content = const StreakRepairContent(),
    this.succeed = true,
  });
  StreakRepairOffer? offer;
  @override
  final StreakRepairContent content;
  final bool succeed;
  final requests = <(String, StreakRepairPayment)>[];
  final _keys = <String>{};
  @override
  StreakRepairOffer? loadOffer() => offer;
  @override
  Future<bool> repair(
    StreakRepairOffer offer,
    StreakRepairPayment payWith,
    String idempotencyKey,
  ) async {
    if (_keys.contains(idempotencyKey)) return true;
    if (!succeed || this.offer == null) return false;
    if (payWith == StreakRepairPayment.item && offer.repairItems < 1) {
      return false;
    }
    _keys.add(idempotencyKey);
    requests.add((offer.lostStreakDay, payWith));
    this.offer = null;
    return true;
  }
}
