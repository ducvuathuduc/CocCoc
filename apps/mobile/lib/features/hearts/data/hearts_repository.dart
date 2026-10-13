import '../domain/hearts.dart';

/// Hearts are an archived reference preview; there is no hearts API contract.
abstract class HeartsRepository {
  HeartsContent get content;
  LivesModel get livesModel;
  HeartsState load();
  HeartsState beginPractice();
  HeartsState earn(String receipt);
  HeartsState refill();
}

class MockHeartsRepository implements HeartsRepository {
  MockHeartsRepository({
    HeartsState initial = const HeartsState(),
    this.content = const HeartsContent(),
    this.livesModel = LivesModel.energy,
  }) : _state = initial;
  @override
  final LivesModel livesModel;
  HeartsState _state;
  @override
  final HeartsContent content;
  @override
  HeartsState load() => _state;
  @override
  HeartsState beginPractice() => _state = HeartsState(
    balance: _state.balance,
    capacity: _state.capacity,
    nextHeartIn: _state.nextHeartIn,
    practicePending: true,
    claims: _state.claims,
  );
  @override
  HeartsState earn(String receipt) {
    if (receipt.isEmpty || _state.claims.contains(receipt)) return _state;
    return _state = HeartsState(
      balance: (_state.balance + 1).clamp(0, _state.capacity),
      capacity: _state.capacity,
      nextHeartIn: _state.nextHeartIn,
      claims: {..._state.claims, receipt},
    );
  }

  @override
  HeartsState refill() => _state = HeartsState(
    balance: _state.capacity,
    capacity: _state.capacity,
    nextHeartIn: _state.nextHeartIn,
    claims: _state.claims,
  );
}
