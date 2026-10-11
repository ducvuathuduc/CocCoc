import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gift_models.dart';

/// Gift subscription catalog and checkout. The mock never charges anything;
/// a store-backed implementation can override [giftRepositoryProvider].
abstract class GiftRepository {
  List<GiftPlan> get plans;
  List<GiftRecipient> get friends;
  List<GiftFaq> get faqs;
  List<GiftOrder> get sentGifts;
  Future<GiftOrder> purchase({
    required GiftPlan plan,
    required GiftRecipient recipient,
    required String note,
  });
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

final giftRepositoryProvider = Provider<GiftRepository>(
  (ref) => MockGiftRepository(),
);
