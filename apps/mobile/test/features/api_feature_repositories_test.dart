import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/features/account/data/account_repository.dart';
import 'package:cocenglish/features/account/data/api_account_repositories.dart';
import 'package:cocenglish/features/account/data/settings_repository.dart';
import 'package:cocenglish/features/account/domain/account_models.dart';
import 'package:cocenglish/features/auth/data/mock_auth_repository.dart';
import 'package:cocenglish/features/gift/data/api_gift_repository.dart';
import 'package:cocenglish/features/gift/data/gift_repository.dart';
import 'package:cocenglish/features/profile/data/api_friends_repository.dart';
import 'package:cocenglish/features/shop/data/api_shop_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api_transport.dart';

Map<String, Object?> shop({int gems = 900, int timer = 3}) => {
  'catalogVersion': 'c1',
  'gems': gems,
  'freezeSlots': 1,
  'items': [
    {
      'itemId': 'streak-freeze',
      'kind': 'FREEZE',
      'priceGems': 200,
      'maxOwned': 2,
      'owned': 1,
      'durationMinutes': null,
      'available': true,
    },
    {
      'itemId': 'timer-boost',
      'kind': 'TIMER_BOOST',
      'priceGems': 450,
      'maxOwned': 99,
      'owned': timer,
      'durationMinutes': null,
      'available': true,
    },
  ],
  'inventory': [
    {'itemId': 'timer-boost', 'quantity': timer, 'expiresAt': null},
  ],
  'asOf': isoNow,
};

Map<String, Object?> purchase(String item, int qty) => {
  'operationId': 'op',
  'itemId': item,
  'quantity': qty,
  'gemsSpent': 0,
  'gems': 0,
  'freezeSlots': 1,
  'inventory': null,
  'energyGrantPending': false,
  'asOf': isoNow,
};

Map<String, Object?> profile(int revision) => {
  'userId': 'u1',
  'nickname': '',
  'avatarId': null,
  'publicOptIn': false,
  'dailyGoal': 10,
  'learningZone': 'Asia/Ho_Chi_Minh',
  'pendingZone': null,
  'zoneEffectiveAt': null,
  'revision': revision,
  'achievementIds': <String>[],
};

void main() {
  late FakeApiTransport transport;
  late ApiEndpoints api;

  setUp(() {
    transport = FakeApiTransport();
    api = ApiEndpoints(fakeClient(transport));
  });

  // Shop is also checked against every schema it must validate (via DTOs).
  group('ApiShopRepository', () {
    test('reads wallet, freezes and timer boosts from the server', () async {
      transport.json('GET /base/v1/shop', shop());
      final repo = ApiShopRepository(api);
      expect(await repo.getWallet(), 900);
      expect(await repo.getFreezes(), 1);
      expect(await repo.getTimerBoosts(), 3);
      expect(transport.to('GET /base/v1/shop'), hasLength(1), reason: 'cached');
    });

    test(
      'buys by server item id in <=10 batches, ignoring client price',
      () async {
        transport
          ..json('GET /base/v1/shop', shop())
          ..json('POST /base/v1/shop/purchases', purchase('timer-boost', 10));
        final repo = ApiShopRepository(api);
        await repo.buyItem('timer-15', 1);
        final bodies = transport
            .to('POST /base/v1/shop/purchases')
            .map(bodyOf)
            .toList();
        expect(bodies, [
          {'itemId': 'timer-boost', 'quantity': 10, 'catalogVersion': 'c1'},
          {'itemId': 'timer-boost', 'quantity': 5, 'catalogVersion': 'c1'},
        ]);
        final keys = transport
            .to('POST /base/v1/shop/purchases')
            .map((r) => r.headers['Idempotency-Key'])
            .toSet();
        expect(keys, hasLength(2));
        expect(
          transport.to('GET /base/v1/shop'),
          hasLength(2),
          reason: 'refresh',
        );
      },
    );

    test('offers keep the UI catalog', () async {
      final repo = ApiShopRepository(api);
      expect(await repo.getTimerBoostOffers(), isNotEmpty);
      expect(transport.requests, isEmpty);
    });
  });

  test('ApiFriendsRepository maps public profiles and pages', () async {
    transport
      ..once(
        'GET /base/v1/friends',
        (r) => jsonResponse({
          'items': [
            {
              'userId': 'a',
              'nickname': 'Linh',
              'avatarId': null,
              'studyXp': 1200,
              'streak': 30,
              'achievementIds': <String>[],
              'followStatus': 'friend',
            },
          ],
          'nextCursor': 'next',
          'asOf': isoNow,
        }),
      )
      ..json('GET /base/v1/friends', {
        'items': [
          {
            'userId': 'b',
            'nickname': 'Minh',
            'avatarId': null,
            'studyXp': 40,
            'streak': 2,
            'achievementIds': <String>[],
            'followStatus': 'following',
          },
        ],
        'nextCursor': null,
        'asOf': isoNow,
      });
    final friends = await ApiFriendsRepository(api).getFriends();
    expect(friends.map((f) => f.name), ['Linh', 'Minh']);
    expect(friends.first.isFollower, isTrue);
    expect(friends.last.isFollower, isFalse);
    expect(friends.last.isFollowing, isTrue);
    expect(transport.requests.last.uri.queryParameters['cursor'], 'next');
  });

  group('ApiSettingsRepository', () {
    test('joins a classroom by code', () async {
      transport.json('POST /base/v1/classrooms/join', {
        'classroomId': 'cls1',
        'name': 'Cô Hạnh · 10A1',
        'courseId': 'vi_en',
        'status': 'ACTIVE',
        'joinedAt': isoNow,
      });
      final repo = ApiSettingsRepository(
        api: api,
        content: MockSettingsRepository(),
      );
      final join = await repo.joinClassroom(' abc123 ');
      expect(join.classroom, 'Cô Hạnh · 10A1');
      expect(bodyOf(transport.requests.single), {'joinCode': 'ABC123'});
    });

    test('unknown classroom -> friendly failure', () async {
      final repo = ApiSettingsRepository(
        api: api,
        content: MockSettingsRepository(),
      );
      final join = await repo.joinClassroom('ZZZ999');
      expect(join.error, contains('couldn’t find'));
    });

    test('feedback carries a slug topic and platform', () async {
      transport.json('POST /base/v1/feedback', {
        'operationId': 'o',
        'status': 'accepted',
        'requestId': 'r',
      });
      final repo = ApiSettingsRepository(
        api: api,
        content: MockSettingsRepository(),
      );
      await repo.sendFeedback('Report a bug', 'Audio stops');
      final body = bodyOf(transport.requests.single);
      expect(body['topic'], 'report-a-bug');
      expect(body['message'], 'Audio stops');
      expect(body['platform'], isNotNull);
    });
  });

  group('ApiAccountRepository', () {
    ApiAccountRepository build(List<String> registered) => ApiAccountRepository(
      api: api,
      auth: MockAuthRepository(delay: Duration.zero),
      content: MockAccountRepository(
        onRegister: (_, _) => null,
        onDelete: () {},
      ),
      onRegister: (name, email) {
        registered.add('$name <$email>');
        return null;
      },
    );

    test('signs up, initializes and sets the nickname', () async {
      transport
        ..json('POST /base/v1/me/initialize', profile(1))
        ..json('PATCH /base/v1/me', profile(2));
      final registered = <String>[];
      final error = await build(registered).createProfile(
        const NewProfile(
          age: 20,
          firstName: 'Thành',
          lastName: 'Huỳnh',
          email: 'thanh@cocenglish.test',
          password: 'very-long-password',
        ),
      );
      expect(error, isNull);
      expect(registered, ['Thành Huỳnh <thanh@cocenglish.test>']);
      expect(bodyOf(transport.to('PATCH /base/v1/me').single), {
        'nickname': 'Thành Huỳnh',
        'expectedRevision': 1,
      });
    });

    test('deletion posts the DELETE confirmation', () async {
      transport.json('POST /base/v1/me/deletion', {
        'requestId': '00000000-0000-4000-8000-000000000009',
        'status': 'REQUESTED',
        'requestedAt': isoNow,
      }, status: 202);
      expect(await build([]).requestDeletion(), isNull);
      expect(bodyOf(transport.requests.single), {'confirmation': 'DELETE'});
    });

    test('server failure returns safe copy', () async {
      expect(await build([]).requestDeletion(), isNotNull);
    });
  });

  test('ApiGiftRepository sends a simulated gift', () async {
    transport.json('POST /base/v1/gifts', {
      'giftId': 'g1',
      'senderId': 'u1',
      'recipientId': 'friend-1',
      'plan': 'SUPER',
      'durationDays': 365,
      'note': 'Chúc mừng!',
      'status': 'DELIVERED',
      'deliveredAt': isoNow,
    });
    final catalog = MockGiftRepository(latency: Duration.zero);
    final repo = ApiGiftRepository(api: api, catalog: catalog);
    final order = await repo.purchase(
      plan: catalog.plans.first,
      recipient: catalog.friends.first,
      note: 'Chúc mừng!',
    );
    expect(order.id, 'g1');
    final body = bodyOf(transport.requests.single);
    expect(body['simulationOutcome'], 'ACTIVE');
    expect(body['recipientUserId'], catalog.friends.first.id);
    expect(repo.sentGifts, hasLength(1));
  });
}
