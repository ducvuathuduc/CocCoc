import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/idempotency.dart';
import '../domain/boost.dart';
import 'boost_repository.dart';

class ApiBoostRepository implements BoostRepository {
  ApiBoostRepository(this.api);
  final ApiEndpoints api;
  final _keys = <String, String>{};
  final _receipts = <String, Boost>{};
  Boost? _current;
  @override
  Boost? get current => _current;
  @override
  BoostCopy get copy => const BoostCopy();

  @override
  Future<Boost> activate(BoostReward reward) async {
    final cached = _receipts[reward.itemId];
    if (cached != null) return cached;
    final receipt = await api.activateBoost(
      wire.BoostRequest(itemId: reward.itemId),
      idempotencyKey: _keys.putIfAbsent(reward.itemId, UuidV4Generator().next),
    );
    final duration = DateTime.parse(receipt.endsAt)
        .difference(DateTime.parse(receipt.startsAt));
    final boost = Boost(
      multiplier: receipt.multiplier,
      minutes: duration.inMinutes,
    );
    _receipts[reward.itemId] = boost;
    return _current = boost;
  }
}
