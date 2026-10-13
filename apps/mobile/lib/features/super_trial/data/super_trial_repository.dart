import '../domain/super_trial_offer.dart';

/// No trial-offer API contract exists; the trial itself is started from the
/// existing `/super` plan screen. The mock supplies copy and records answers.
abstract class SuperTrialRepository {
  SuperTrialOffer get offer;
  Future<void> record(SuperTrialChoice choice);
}

class MockSuperTrialRepository implements SuperTrialRepository {
  MockSuperTrialRepository({this.offer = const SuperTrialOffer()});
  @override
  final SuperTrialOffer offer;
  final choices = <SuperTrialChoice>[];
  @override
  Future<void> record(SuperTrialChoice choice) async => choices.add(choice);
}
