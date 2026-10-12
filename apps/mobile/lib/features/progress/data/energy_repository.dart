import '../../../core/api/client/api_endpoints.g.dart';
import '../domain/energy_offer.dart';

abstract class EnergyRepository {
  List<EnergyOffer> get offers;
  int get capacity;
  String get fullMessage;
  String get partialMessage;
  String get retryLabel;
  Future<int> readBalance(int previewBalance);
  Future<int> refill(EnergyOffer offer, int balance);
}

class MockEnergyRepository implements EnergyRepository {
  @override
  int get capacity => 25;
  @override
  String get fullMessage => 'Your energy is full.';
  @override
  String get partialMessage => 'Recharge your energy to keep learning.';
  @override
  String get retryLabel => 'TRY AGAIN';
  @override
  List<EnergyOffer> get offers => const [
    EnergyOffer(EnergyRefillKind.recharge, 25, 'Recharge', '500', cost: 500),
    EnergyOffer(EnergyRefillKind.ad, 5, '+5 energy', 'WATCH AD'),
    EnergyOffer(EnergyRefillKind.free, 2, '+2 energy', 'FREE'),
  ];
  @override
  Future<int> readBalance(int previewBalance) async => previewBalance;
  @override
  Future<int> refill(EnergyOffer offer, int balance) async =>
      (offer.kind == EnergyRefillKind.recharge
              ? capacity
              : balance + offer.amount)
          .clamp(0, capacity);
}

/// Existing getEnergy contract supports reads. There is no free/recharge
/// command: those preview actions stay disabled in API mode.
class ApiEnergyRepository extends MockEnergyRepository {
  ApiEnergyRepository(this.api);
  final ApiEndpoints api;
  @override
  Future<int> readBalance(int previewBalance) async =>
      (await api.getEnergy()).balance;
  @override
  Future<int> refill(EnergyOffer offer, int balance) => readBalance(balance);
}
