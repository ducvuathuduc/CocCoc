import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_providers.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/progress/application/energy_controller.dart';
import 'package:cocenglish/features/progress/application/extended_controller.dart';
import 'package:cocenglish/features/progress/application/league_join_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/application/year_review_controller.dart';
import 'package:cocenglish/features/progress/data/energy_repository.dart';
import 'package:cocenglish/features/progress/data/league_repository.dart';
import 'package:cocenglish/features/progress/data/progress_snapshot.dart';
import 'package:cocenglish/features/progress/domain/energy_offer.dart';
import 'package:cocenglish/features/progress/domain/league_ranking.dart';
import 'package:cocenglish/features/progress/domain/league_result.dart';
import 'package:cocenglish/features/progress/domain/year_review.dart';
import 'package:cocenglish/features/quests/data/api_quests_repository.dart';
import 'package:cocenglish/features/shop/application/shop_controller.dart';
import 'package:cocenglish/features/shop/data/api_shop_repository.dart';
import 'package:cocenglish/features/shop/data/shop_repository.dart';
import 'package:cocenglish/features/streak_repair/application/streak_repair_controller.dart';
import 'package:cocenglish/features/streak_repair/data/streak_repair_repository.dart';
import 'package:cocenglish/features/streak_repair/domain/streak_repair.dart';
import 'package:cocenglish/features/xp_boost/domain/boost.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

const _offer = StreakRepairOffer(lostDays: 47, lostStreakDay: '2026-10-12');

Map<String, Object?> rewards({int gems = 500, int streak = 47}) => {
  'completionId': null,
  'status': 'credited',
  'studyXp': 300,
  'leagueXp': 120,
  'gems': gems,
  'freezeSlots': 1,
  'currentStreak': streak,
  'awardXp': null,
  'revision': 3,
  'asOf': isoNow,
};

Map<String, Object?> energyJson(int balance, {int capacity = 25}) => {
  'mode': 'LIMITED',
  'balance': balance,
  'capacity': capacity,
  'nextUnitAt': null,
  'fullAt': null,
  'revision': 2,
  'asOf': isoNow,
};

Map<String, Object?> leagueJson({int tier = 3}) => {
  'weekId': '2026-W42',
  'cohortId': 'cohort-1',
  'tier': tier,
  'status': 'OPEN',
  'members': [
    {
      'userId': 'me',
      'nickname': 'Thanh',
      'eligibleXp': 120,
      'rank': 1,
      'lastXpAt': null,
    },
    {
      'userId': 'u2',
      'nickname': 'Linh',
      'eligibleXp': 90,
      'rank': 2,
      'lastXpAt': null,
    },
  ],
  'asOf': isoNow,
  'nextCursor': null,
};

Map<String, Object?> yearReviewJson() => {
  'year': 2025,
  'generatedAt': isoNow,
  'totalXp': 3210,
  'activeDays': 40,
  'longestStreak': 88,
  'lessonsCompleted': 123,
  'wordsLearned': 500,
  'minutesSpent': 640,
  'achievementsEarned': 4,
  'topLeagueTier': 3,
  'courseIds': ['vi_en'],
};

Map<String, Object?> shopJson({bool withBoost = true}) => {
  'catalogVersion': 'shop-v1',
  'gems': 900,
  'freezeSlots': 1,
  'items': [
    if (withBoost)
      {
        'itemId': 'xp_boost_15',
        'kind': 'XP_BOOST',
        'priceGems': 100,
        'maxOwned': 3,
        'owned': 1,
        'durationMinutes': 15,
        'available': true,
      },
    {
      'itemId': 'energy_refill',
      'kind': 'ENERGY_REFILL',
      'priceGems': 50,
      'maxOwned': 0,
      'owned': 0,
      'durationMinutes': null,
      'available': true,
    },
  ],
  'inventory': [
    if (withBoost)
      {'itemId': 'xp_boost_15', 'quantity': 1, 'expiresAt': null},
  ],
  'asOf': isoNow,
};

Map<String, Object?> purchaseJson(String item, int qty) => {
  'operationId': 'op',
  'itemId': item,
  'quantity': qty,
  'gemsSpent': 50,
  'gems': 850,
  'freezeSlots': 1,
  'inventory': null,
  'energyGrantPending': true,
  'asOf': isoNow,
};

Map<String, Object?> boostJson() => {
  'boostId': 'boost-1',
  'kind': 'XP_BOOST',
  'multiplier': 2,
  'startsAt': isoNow,
  'endsAt': '2026-10-12T08:15:00.000Z',
  'inventory': null,
};

Map<String, Object?> receiptJson() => {
  'operationId': 'op',
  'status': 'accepted',
  'requestId': 'req-1',
};

Map<String, Object?> questPage() => {
  'items': [
    {
      'questId': 'friend_lessons10',
      'period': 'WEEK',
      'periodKey': '2026-W42',
      'target': 10,
      'metricValue': 3,
      'claimed': false,
      'rewardGems': 10,
    },
  ],
  'nextCursor': null,
  'asOf': isoNow,
};

class _EnergyState extends ExtendedController {
  @override
  ExtendedState build() => const ExtendedState(energy: 10);
}

class _FakeLeagueRepository implements LeagueRepository {
  bool joinCalled = false;

  @override
  bool get joined => false;

  @override
  Future<LeagueRanking?> join() async {
    joinCalled = true;
    return LeagueRanking(
      tier: LeagueTier.gold,
      entries: const [
        LeagueRankingEntry(
          userId: 'me',
          name: 'Thanh',
          xp: 120,
          rank: 1,
          isOwn: true,
        ),
      ],
    );
  }

  @override
  LeagueResultFixture? lastResult() => null;

  @override
  Future<void> markResultSeen() async {}

  @override
  LeagueRanking? ranking() => null;
}

class _FakeYearReviewRepository implements YearReviewRepository {
  _FakeYearReviewRepository(this.snapshot);

  final YearReviewSnapshot snapshot;
  int loads = 0;

  @override
  Future<YearReviewSnapshot> load() async {
    loads += 1;
    return snapshot;
  }
}

class _AvailableChestShop implements ShopRepository {
  @override
  Future<void> buyItem(
    String id,
    int displayCost, {
    required String commandId,
  }) async {}

  @override
  Future<ShopState> loadShop({bool refresh = false}) async => const ShopState(
    wallet: 900,
    freezes: 1,
    timerBoosts: 0,
    specialOffers: [
      ShopOffer(
        id: 'friends-chest',
        title: 'Friends Chest',
        actionLabel: 'CLAIM',
        xpBoost: BoostReward(itemId: 'xp_boost_15', multiplier: 2, minutes: 15),
      ),
    ],
    timerBoostOffers: [],
    freezeOffer: ShopOffer(id: 'freeze', title: '1-day', price: 200),
  );
}

void main() {
  late FakeApiTransport transport;
  late ApiEndpoints api;

  setUp(() {
    transport = FakeApiTransport();
    api = ApiEndpoints(fakeClient(transport));
  });

  group('streak repair', () {
    test('posts the contract request and keeps the server streak', () async {
      transport.json('POST /base/v1/me/streak-repair', rewards());
      final repository = ApiStreakRepairRepository(api, offer: _offer);

      expect(
        await repository.repair(
          _offer,
          StreakRepairPayment.gems,
          '00000000-0000-4000-8000-000000000001',
        ),
        isTrue,
      );

      final request = transport
          .to('POST /base/v1/me/streak-repair')
          .single;
      expect(bodyOf(request), {
        'lostStreakDay': '2026-10-12',
        'payWith': 'GEMS',
      });
      expect(
        request.headers['Idempotency-Key'],
        '00000000-0000-4000-8000-000000000001',
      );
      expect(repository.lastRestoredStreak, 47);
    });

    test('an expired server offer refuses without a local gem spend', () async {
      transport.on(
        'POST /base/v1/me/streak-repair',
        (_) => jsonResponse(
          errorEnvelope('STREAK_REPAIR_EXPIRED'),
          status: 409,
        ),
      );
      final repository = ApiStreakRepairRepository(api, offer: _offer);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          streakRepairRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        streakRepairControllerProvider.notifier,
      );
      expect(await controller.repair(StreakRepairPayment.gems), isFalse);
      expect(container.read(previewControllerProvider).spentGems, 0);
      expect(
        container.read(streakRepairControllerProvider).error,
        const StreakRepairContent().failed,
      );
    });

    test('API success never charges the local preview wallet', () async {
      transport.json('POST /base/v1/me/streak-repair', rewards());
      final repository = ApiStreakRepairRepository(api, offer: _offer);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          streakRepairRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        streakRepairControllerProvider.notifier,
      );
      expect(await controller.repair(StreakRepairPayment.gems), isTrue);
      expect(container.read(previewControllerProvider).spentGems, 0);
      expect(
        container.read(streakRepairControllerProvider).repairedDays,
        47,
      );
    });
  });

  group('league', () {
    test('join posts once and applies the server tier and standings', () async {
      transport.json('POST /base/v1/league/join', leagueJson());
      final repository = ApiLeagueRepository(ProgressSnapshotSource(api));

      final ranking = await repository.join();

      expect(ranking!.tier, LeagueTier.sapphire);
      expect(ranking.entries.map((entry) => entry.name), ['Thanh', 'Linh']);
      final request = transport.to('POST /base/v1/league/join').single;
      expect(request.headers['Idempotency-Key'], isNotNull);
    });

    test('the gate controller joins the server before the local opt-in', () async {
      final repository = _FakeLeagueRepository();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          leagueRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(previewControllerProvider).leagueOptIn, isFalse);
      final joined = await container
          .read(leagueJoinControllerProvider.notifier)
          .join();
      expect(joined, isTrue);
      expect(repository.joinCalled, isTrue);
      expect(container.read(previewControllerProvider).leagueOptIn, isTrue);
    });
  });

  group('year review', () {
    test('the API repository maps the server year review', () async {
      transport.json('GET /base/v1/me/year-review/2025', yearReviewJson());
      final repository = ApiYearReviewRepository(api, year: 2025);

      final snapshot = await repository.load();

      expect(snapshot.year, 2025);
      expect(snapshot.lessons, 123);
      expect(snapshot.totalXp, 3210);
      expect(snapshot.longestStreak, 88);
      expect(snapshot.minutesSpent, 640);
      expect(snapshot.league, 'Sapphire');
      expect(snapshot.course, 'English');
    });

    test('the controller shares the loaded server snapshot, not the fixture', () async {
      final server = YearReviewSnapshot(
        year: 2025,
        course: 'English',
        lessons: 5,
        totalXp: 900,
        percentile: 93,
        studentTopPercent: 8,
        league: 'Gold',
        leagueWeeks: 2,
        englishScore: 19,
        longestStreak: 12,
        minutesSpent: 30,
        asOf: DateTime(2025, 12, 1),
      );
      final repository = _FakeYearReviewRepository(server);
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          yearReviewRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(yearReviewControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(yearReviewControllerProvider).snapshot.lessons, 5);
      expect(repository.loads, 1);
    });
  });

  group('friend quest', () {
    test('opt-in posts the contract id and refreshes the quest page', () async {
      transport
        ..json('POST /base/v1/friend-quests/opt-in', receiptJson())
        ..json('GET /base/v1/quests', questPage());
      final repository = ApiQuestsRepository(api);

      expect(await repository.optInFriendQuest(), isTrue);

      final request = transport
          .to('POST /base/v1/friend-quests/opt-in')
          .single;
      expect(request.headers['Idempotency-Key'], isNotNull);
      expect(request.body, anyOf(isNull, isEmpty));
      expect(transport.to('GET /base/v1/quests'), isNotEmpty);
      expect(repository.loadQuests().friendsQuest.userLessons, 3);
    });
  });

  group('energy', () {
    test('ad refill waits for the server grant instead of echoing input', () async {
      transport
        ..once(
          'GET /base/v1/me/energy',
          (_) => jsonResponse(energyJson(10)),
        )
        ..json('GET /base/v1/me/energy', energyJson(15));
      final repository = ApiEnergyRepository(
        api,
        pollInterval: Duration.zero,
      );

      final balance = await repository.refill(
        const EnergyOffer(EnergyRefillKind.ad, 5, '+5 energy', 'WATCH AD'),
        10,
      );

      expect(balance, 15);
      expect(transport.to('GET /base/v1/me/energy'), hasLength(2));
    });

    test('recharge buys the server ENERGY_REFILL item, then reads energy', () async {
      transport
        ..json('GET /base/v1/shop', shopJson(withBoost: false))
        ..json(
          'POST /base/v1/shop/purchases',
          purchaseJson('energy_refill', 1),
        )
        ..once(
          'GET /base/v1/me/energy',
          (_) => jsonResponse(energyJson(9)),
        )
        ..json('GET /base/v1/me/energy', energyJson(25));
      final repository = ApiEnergyRepository(
        api,
        pollInterval: Duration.zero,
      );

      final balance = await repository.refill(
        const EnergyOffer(
          EnergyRefillKind.recharge,
          25,
          'Recharge',
          '500',
          cost: 500,
        ),
        9,
      );

      expect(balance, 25);
      expect(
        bodyOf(
          transport.to('POST /base/v1/shop/purchases').single,
        )['itemId'],
        'energy_refill',
      );
      expect(
        transport
            .to('POST /base/v1/shop/purchases')
            .single
            .headers['Idempotency-Key'],
        isNotNull,
      );
    });

    test('the controller hydrates server energy and never spends preview gems', () async {
      transport
        ..json('GET /base/v1/me/energy', energyJson(10))
        ..once(
          'GET /base/v1/me/energy',
          (_) => jsonResponse(energyJson(10)),
        )
        ..json('GET /base/v1/me/energy', energyJson(15));
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          apiEndpointsProvider.overrideWithValue(api),
          extendedControllerProvider.overrideWith(_EnergyState.new),
        ],
      );
      addTearDown(container.dispose);

      container.listen(energyControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(extendedControllerProvider).energy, 10);

      final offers = container.read(energyOffersProvider);
      final ad = offers.firstWhere(
        (offer) => offer.kind == EnergyRefillKind.ad,
      );
      await container
          .read(energyControllerProvider.notifier)
          .refill(ad, adRewarded: true);

      expect(container.read(extendedControllerProvider).energy, 15);
      expect(container.read(previewControllerProvider).spentGems, 0);
    });
  });

  group('shop special offers', () {
    test('the friends chest state comes from the server inventory', () async {
      transport.json('GET /base/v1/shop', shopJson());
      final repository = ApiShopRepository(api);

      final state = await repository.loadShop();
      final chest = state.specialOffers.firstWhere(
        (offer) => offer.id == 'friends-chest',
      );

      expect(chest.available, isTrue);
      expect(chest.actionLabel, 'CLAIM');
      expect(chest.xpBoost?.itemId, 'xp_boost_15');
      expect(chest.rewardGems, isNull);
      expect(
        state.specialOffers
            .where((offer) => offer.id != 'friends-chest')
            .every((offer) => !offer.available),
        isTrue,
      );
    });

    test('opening the server chest activates the owned boost', () async {
      transport
        ..json('GET /base/v1/shop', shopJson())
        ..json('POST /base/v1/me/boosts', boostJson());
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          apiEndpointsProvider.overrideWithValue(api),
          shopRepositoryProvider.overrideWithValue(
            _AvailableChestShop(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(shopControllerProvider, (_, _) {}, fireImmediately: true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final opened = await container
          .read(shopControllerProvider.notifier)
          .openSpecialOffer('friends-chest');

      expect(opened, isTrue);
      expect(
        bodyOf(transport.to('POST /base/v1/me/boosts').single),
        {'itemId': 'xp_boost_15'},
      );
    });
  });
}
