import 'dart:async';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../progress/data/progress_snapshot.dart';
import '../domain/streak_repair.dart';

abstract class StreakRepairRepository {
  StreakRepairContent get content;

  /// The repairable lost streak, or null when nothing can be repaired.
  StreakRepairOffer? loadOffer();

  /// The streak length the last successful repair restored, when known.
  int? get lastRestoredStreak;

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
  int? _restoredStreak;
  @override
  StreakRepairOffer? loadOffer() => offer;
  @override
  int? get lastRestoredStreak => _restoredStreak;
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
    _restoredStreak = offer.lostDays;
    return true;
  }
}

/// Server-authoritative repair over `POST /v1/me/streak-repair`.
///
/// The Progress service owns the lost-streak window, the price and the
/// restored streak. There is no read endpoint for the offer yet, so the local
/// offer (when present) only supplies the day to repair.
class ApiStreakRepairRepository implements StreakRepairRepository {
  ApiStreakRepairRepository(
    this.api, {
    this.offer,
    this._source,
    this.content = const StreakRepairContent(),
  });

  final ApiEndpoints api;
  final ProgressSnapshotSource? _source;
  StreakRepairOffer? offer;
  @override
  final StreakRepairContent content;
  int? _lastRestoredStreak;

  @override
  StreakRepairOffer? loadOffer() => offer;

  @override
  int? get lastRestoredStreak => _lastRestoredStreak;

  @override
  Future<bool> repair(
    StreakRepairOffer offer,
    StreakRepairPayment payWith,
    String idempotencyKey,
  ) async {
    try {
      final rewards = await api.repairStreak(
        wire.StreakRepairRequest(
          lostStreakDay: offer.lostStreakDay,
          payWith: payWith == StreakRepairPayment.gems ? 'GEMS' : 'ITEM',
        ),
        idempotencyKey: idempotencyKey,
      );
      this.offer = null;
      _lastRestoredStreak = rewards.currentStreak > 0
          ? rewards.currentStreak
          : null;
      unawaited(_source?.refresh().catchError((Object _) => null));
      return true;
    } on ApiException {
      return false;
    }
  }
}
