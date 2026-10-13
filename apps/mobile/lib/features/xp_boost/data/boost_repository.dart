import '../domain/boost.dart';

abstract class BoostRepository {
  Boost? get current;
  BoostCopy get copy;
  Future<Boost> activate(BoostReward reward);
}

class MockBoostRepository implements BoostRepository {
  MockBoostRepository({
    Boost? initial = const Boost(multiplier: 2, minutes: 15),
  }) : _current = initial;
  Boost? _current;
  final _receipts = <String, Boost>{};
  @override
  Boost? get current => _current;
  @override
  BoostCopy get copy => const BoostCopy();
  @override
  Future<Boost> activate(BoostReward reward) async =>
      _current = _receipts.putIfAbsent(
        reward.itemId,
        () => Boost(multiplier: reward.multiplier, minutes: reward.minutes),
      );
}
