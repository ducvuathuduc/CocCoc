import '../domain/house_ad.dart';

abstract class AdsRepository {
  HouseAd get houseAd;
  Future<void> impression(String id, String placement);
  Future<bool> complete(String id, String placement);
}

class MockAdsRepository implements AdsRepository {
  MockAdsRepository({this.houseAd = const HouseAd()});
  @override
  final HouseAd houseAd;
  final _impressions = <String>{};
  final _completed = <String>{};
  @override
  Future<void> impression(String id, String placement) async {
    _impressions.add(id);
  }

  @override
  Future<bool> complete(String id, String placement) async {
    if (!_impressions.contains(id)) return false;
    _completed.add(id);
    return true;
  }
}
