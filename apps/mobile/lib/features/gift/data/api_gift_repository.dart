import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../domain/gift_models.dart';
import 'gift_repository.dart';

/// Gift checkout via `POST /v1/gifts`. Billing stays MOCK (user decision
/// 2026-10-12): the server simulates the store outcome; no real money.
/// Plan catalog, FAQ and recipients come from [catalog].
class ApiGiftRepository implements GiftRepository {
  ApiGiftRepository({required this.api, required this.catalog});

  final ApiEndpoints api;
  final GiftRepository catalog;
  final List<GiftOrder> _sent = [];

  @override
  List<GiftPlan> get plans => catalog.plans;

  @override
  List<GiftRecipient> get friends => catalog.friends;

  @override
  List<GiftFaq> get faqs => catalog.faqs;

  @override
  List<GiftOrder> get sentGifts => List.unmodifiable(_sent);

  static int _days(GiftPlan plan) {
    final d = plan.duration.toLowerCase();
    final n = int.tryParse(RegExp(r'\d+').firstMatch(d)?.group(0) ?? '') ?? 1;
    if (d.contains('year')) return (365 * n).clamp(1, 365);
    if (d.contains('month')) return (30 * n).clamp(1, 365);
    if (d.contains('week')) return (7 * n).clamp(1, 365);
    return n.clamp(1, 365);
  }

  @override
  Future<GiftOrder> purchase({
    required GiftPlan plan,
    required GiftRecipient recipient,
    required String note,
  }) async {
    final trimmed = note.trim();
    final gift = await api.sendGift(
      wire.GiftRequest(
        recipientUserId: recipient.id,
        plan: plan.name.toUpperCase().contains('MAX') ? 'MAX' : 'SUPER',
        durationDays: _days(plan),
        note: trimmed.isEmpty
            ? null
            : trimmed.substring(0, trimmed.length.clamp(0, 160)),
        simulationOutcome: 'ACTIVE',
      ),
    );
    final order = GiftOrder(
      id: gift.giftId,
      plan: plan,
      recipient: recipient,
      note: note,
    );
    _sent.add(order);
    return order;
  }
}
