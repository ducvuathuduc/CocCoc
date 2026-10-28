import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/gift/application/gift_controller.dart';
import 'package:cocenglish/features/gift/data/api_gift_repository.dart';
import 'package:cocenglish/features/gift/data/gift_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

Map<String, Object?> publicProfile(String userId, String nickname) => {
  'userId': userId,
  'nickname': nickname,
  'avatarId': null,
  'studyXp': 42,
  'streak': 3,
  'achievementIds': <String>[],
  'followStatus': 'friend',
};

Map<String, Object?> friendshipPage(List<Map<String, Object?>> items) => {
  'items': items,
  'nextCursor': null,
  'asOf': isoNow,
};

Map<String, Object?> gift(String recipientId) => {
  'giftId': 'gift-9',
  'senderId': 'u-self',
  'recipientId': recipientId,
  'plan': 'SUPER',
  'durationDays': 365,
  'note': 'Enjoy!',
  'status': 'DELIVERED',
  'deliveredAt': isoNow,
};

Map<String, Object?> entitlement() => {
  'plan': 'SUPER',
  'status': 'ACTIVE',
  'source': 'GIFT',
  'expiresAt': '2027-10-12T00:00:00.000Z',
  'autoRenew': false,
  'familyGroupId': null,
  'unlimitedEnergy': true,
  'adFree': true,
  'conversations': false,
  'revision': 2,
  'asOf': isoNow,
};

ApiGiftRepository apiGiftRepository(FakeApiTransport transport) =>
    ApiGiftRepository(
      api: ApiEndpoints(fakeClient(transport)),
      catalog: MockGiftRepository(latency: Duration.zero),
    );

void main() {
  test('API mode fills gift recipients from GET /v1/friends', () async {
    final transport = FakeApiTransport()
      ..json(
        'GET /base/v1/friends',
        friendshipPage([
          publicProfile('u-alex', 'Alex Smith'),
          publicProfile('u-linh', 'Linh Nguyen'),
        ]),
      );
    final repo = apiGiftRepository(transport);

    expect(repo.friends, isEmpty); // no demo ids before the network answers
    final friends = await repo.loadFriends();

    expect(friends.map((f) => f.id), ['u-alex', 'u-linh']);
    expect(friends.first.name, 'Alex Smith');
    expect(friends.first.username, 'alex.smith');
    expect(repo.friends.map((f) => f.id), ['u-alex', 'u-linh']);
    expect(
      transport.to('GET /base/v1/friends').single.headers['Authorization'],
      'Bearer jwt-test',
    );
  });

  test('API gift posts the friend userId, not a demo recipient id', () async {
    final transport = FakeApiTransport()
      ..json(
        'GET /base/v1/friends',
        friendshipPage([publicProfile('u-alex', 'Alex Smith')]),
      )
      ..json('POST /base/v1/gifts', gift('u-alex'));
    final repo = apiGiftRepository(transport);
    final friends = await repo.loadFriends();

    final order = await repo.purchase(
      plan: repo.plans.first,
      recipient: friends.single,
      note: 'Enjoy!',
    );

    expect(order.id, 'gift-9');
    final body = bodyOf(transport.to('POST /base/v1/gifts').single);
    expect(body['recipientUserId'], 'u-alex');
    expect(body['simulationOutcome'], 'ACTIVE');
  });

  test('API gift redeem posts the received gift id', () async {
    final transport = FakeApiTransport()
      ..json('POST /base/v1/gifts/gift-9/redeem', entitlement());
    final repo = apiGiftRepository(transport);

    final redemption = await repo.redeemGift('gift-9');

    expect(redemption.giftId, 'gift-9');
    expect(redemption.plan, 'SUPER');
    expect(redemption.expiresAt, DateTime.utc(2027, 10, 12));
    final request = transport.requests.single;
    expect(request.method, 'POST');
    expect(request.headers['Idempotency-Key'], isNotEmpty);
  });

  test('controller loads API recipients and redeems a pending gift', () async {
    final transport = FakeApiTransport()
      ..json(
        'GET /base/v1/friends',
        friendshipPage([publicProfile('u-alex', 'Alex Smith')]),
      )
      ..json('POST /base/v1/gifts/gift-9/redeem', entitlement());
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(dataSource: DataSource.api),
        ),
        giftRepositoryProvider.overrideWithValue(apiGiftRepository(transport)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(giftControllerProvider, (_, _) {});
    await pumpEventQueue();

    final vm = container.read(giftControllerProvider.notifier);
    expect(container.read(giftControllerProvider).friends.single.id, 'u-alex');
    vm.selectRecipient('u-alex');
    expect(container.read(giftControllerProvider).canContinue, isTrue);

    final redemption = await vm.receiveGift('gift-9');
    expect(redemption?.giftId, 'gift-9');
    expect(
      container.read(giftControllerProvider).lastRedemption?.plan,
      'SUPER',
    );
  });

  test('mock mode keeps the demo recipients and local checkout', () async {
    final container = ProviderContainer(
      overrides: [
        giftRepositoryProvider.overrideWithValue(
          MockGiftRepository(latency: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(giftControllerProvider, (_, _) {});
    await pumpEventQueue();

    final state = container.read(giftControllerProvider);
    expect(state.friends.map((f) => f.id), ['alex', 'maya', 'linh', 'sam']);
    final order = await container
        .read(giftControllerProvider.notifier)
        .purchase();
    expect(order, isNull);
    container.read(giftControllerProvider.notifier).selectRecipient('maya');
    expect(
      (await container.read(giftControllerProvider.notifier).purchase())?.id,
      'gift-1',
    );
  });
}
