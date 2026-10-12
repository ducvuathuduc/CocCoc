import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/idempotency.dart';
import '../domain/house_ad.dart';
import 'ads_repository.dart';

/// Local house creative; the Progress API alone authorizes completion rewards.
class ApiAdsRepository implements AdsRepository {
  ApiAdsRepository(this.api);
  final ApiEndpoints api;
  final _impressionIds = <String, String>{};
  @override
  HouseAd get houseAd => const HouseAd();
  @override
  Future<void> impression(String id, String placement) async {
    final impressionId = _impressionIds.putIfAbsent(
      id,
      () => UuidV4Generator().next(),
    );
    await api.recordAdEvent(
      wire.AdEventRequest(
        adEventId: impressionId,
        placement: placement,
        kind: 'IMPRESSION',
      ),
      idempotencyKey: impressionId,
    );
  }

  @override
  Future<bool> complete(String id, String placement) async {
    await api.recordAdEvent(
      wire.AdEventRequest(
        adEventId: id,
        placement: placement,
        kind: 'REWARDED_COMPLETION',
      ),
      idempotencyKey: id,
    );
    return true;
  }
}
