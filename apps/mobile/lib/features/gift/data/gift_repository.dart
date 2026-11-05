import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gift_models.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import 'api_gift_repository.dart';

/// Gift subscription catalog and checkout. The mock never charges anything;
/// a store-backed implementation can override [giftRepositoryProvider].
abstract class GiftRepository {
  List<GiftPlan> get plans;

  /// Recipients known right now: demo fixtures in mock mode, the last
  /// successful [loadFriends] in API mode. Never demo ids in API mode, because
  /// `POST /v1/gifts` validates `recipientUserId` against real profiles.
  List<GiftRecipient> get friends;

  /// Refreshes recipients from the learner's friends (`GET /v1/friends`).
  Future<List<GiftRecipient>> loadFriends();
  List<GiftFaq> get faqs;
  List<GiftOrder> get sentGifts;
  Future<GiftOrder> purchase({
    required GiftPlan plan,
    required GiftRecipient recipient,
    required String note,
  });

  /// Collects a received gift (`POST /v1/gifts/{giftId}/redeem`).
  Future<GiftRedemption> redeemGift(String giftId);
}

class MockGiftRepository implements GiftRepository {
  MockGiftRepository({this.latency = const Duration(milliseconds: 400)});
  final Duration latency;
  final List<GiftOrder> _sent = [];

  @override
  final List<GiftPlan> plans = const [
    GiftPlan(
      id: 'super-1y',
      name: 'Super',
      duration: '1 year',
      priceLabel: r'$95.99',
    ),
    GiftPlan(
      id: 'max-1y',
      name: 'Max',
      duration: '1 year',
      priceLabel: r'$167.99',
    ),
  ];

  @override
  final List<GiftRecipient> friends = const [
    GiftRecipient(id: 'alex', name: 'Alex', username: 'alexlearns'),
    GiftRecipient(id: 'maya', name: 'Maya', username: 'maya.speaks'),
    GiftRecipient(id: 'linh', name: 'Linh', username: 'linhnguyen'),
    GiftRecipient(id: 'sam', name: 'Sam', username: 'samwords'),
  ];

  @override
  final List<GiftFaq> faqs = const [
    GiftFaq(
      'What’s the difference between Super and Max?',
      'Super gives unlimited energy, no ads and unlimited practice. Max adds '
          'Video Call, Roleplay and Explain My Answer on top of Super.',
    ),
    GiftFaq(
      'Which plan is best for speaking?',
      'Max is best for speaking: Video Call and Roleplay let you practice '
          'real conversations.',
    ),
    GiftFaq(
      'How does Family Plan work?',
      'One manager shares a subscription with up to 5 other people. Each '
          'member keeps their own profile and progress.',
    ),
  ];

  @override
  List<GiftOrder> get sentGifts => List.unmodifiable(_sent);

  /// Demo fixtures only; the mock never touches the network.
  @override
  Future<List<GiftRecipient>> loadFriends() async => friends;

  @override
  Future<GiftRedemption> redeemGift(String giftId) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return GiftRedemption(giftId: giftId, plan: plans.first.name.toUpperCase());
  }

  @override
  Future<GiftOrder> purchase({
    required GiftPlan plan,
    required GiftRecipient recipient,
    required String note,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final order = GiftOrder(
      id: 'gift-${_sent.length + 1}',
      plan: plan,
      recipient: recipient,
      note: note,
    );
    _sent.add(order);
    return order;
  }
}

final giftRepositoryProvider = Provider<GiftRepository>((ref) {
  if (ref.watch(appConfigProvider).isApi) {
    return ApiGiftRepository(
      api: ref.watch(apiEndpointsProvider),
      catalog: MockGiftRepository(),
    );
  }
  return MockGiftRepository();
});
