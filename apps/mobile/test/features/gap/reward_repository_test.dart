import 'package:cocenglish/features/ads/data/ads_repository.dart';
import 'package:cocenglish/features/hearts/data/hearts_repository.dart';
import 'package:cocenglish/features/progress/data/energy_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('practice and ad receipts award once and cap hearts', () {
    final repository = MockHeartsRepository();
    repository.beginPractice();
    expect(repository.earn('practice-1').balance, 1);
    expect(repository.earn('practice-1').balance, 1);
    expect(repository.load().practicePending, isFalse);
    for (var i = 0; i < 10; i++) {
      repository.earn('ad-$i');
    }
    expect(repository.load().balance, 5);
  });
  test('mock completion needs an impression and can replay safely', () async {
    final repository = MockAdsRepository();
    expect(
      await repository.complete('unseen', 'LESSON_END_INTERSTITIAL'),
      isFalse,
    );
    await repository.impression('watched', 'LESSON_END_INTERSTITIAL');
    expect(
      await repository.complete('watched', 'LESSON_END_INTERSTITIAL'),
      isTrue,
    );
    expect(
      await repository.complete('watched', 'LESSON_END_INTERSTITIAL'),
      isTrue,
    );
  });
  test('refills clamp to capacity', () async {
    final repository = MockEnergyRepository();
    expect(await repository.refill(repository.offers[1], 24), 25);
    expect(await repository.refill(repository.offers[2], 24), 25);
  });
}
