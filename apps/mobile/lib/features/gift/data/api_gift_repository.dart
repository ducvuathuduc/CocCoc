import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../domain/gift_models.dart';
import 'gift_repository.dart';

/// Gift checkout via `POST /v1/gifts`. Billing stays MOCK (user decision
/// 2026-10-12): the server simulates the store outcome; no real money.
/// Plan catalog and FAQ come from [catalog]; recipients come from the
/// learner's real friends so `recipientUserId` passes server validation.
class ApiGiftRepository implements GiftRepository {
  ApiGiftRepository({required this.api, required this.catalog});

  final ApiEndpoints api;
  final GiftRepository catalog;
  final List<GiftOrder> _sent = [];
  final List<GiftRecipient> _friends = [];

  @override
  List<GiftPlan> get plans => catalog.plans;

  @override
  List<GiftRecipient> get friends => List.unmodifiable(_friends);

  @override
  List<GiftFaq> get faqs => catalog.faqs;

  @override
  List<GiftOrder> get sentGifts => List.unmodifiable(_sent);

  static String _displayName(String nickname, String fallback) {
    final trimmed = nickname.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  /// `PublicProfile` carries no handle; derive a stable demo-style one.
  static String _handle(String nickname, String userId) {
    final slug = nickname
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');
    return slug.isEmpty ? userId.toLowerCase() : slug;
  }

  @override
  Future<List<GiftRecipient>> loadFriends() async {
    final byId = <String, GiftRecipient>{};
    String? cursor;
    do {
      final page = await api.listFriends(cursor: cursor, limit: 100);
      for (final profile in page.items) {
        byId[profile.userId] = GiftRecipient(
          id: profile.userId,
          name: _displayName(profile.nickname, profile.userId),
          username: _handle(profile.nickname, profile.userId),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null && byId.length < 500);
    _friends
      ..clear()
      ..addAll(byId.values);
    return List.unmodifiable(_friends);
  }

  static int _days(GiftPlan plan) {
    final d = plan.duration.toLowerCase();
    final n = int.tryParse(RegExp(r'\d+').firstMatch(d)?.group(0) ?? '') ?? 1;
    if (d.contains('year')) return (365 * n).clamp(1, 365);
    if (d.contains('month')) return (30 * n).clamp(1, 365);
    if (d.contains('week')) return (7 * n).clamp(1, 365);
    return n.clamp(1, 365);
  }

  @override
  Future<GiftRedemption> redeemGift(String giftId) async {
    final entitlement = await api.redeemGift(giftId);
    return GiftRedemption(
      giftId: giftId,
      plan: entitlement.plan,
      expiresAt: DateTime.tryParse(entitlement.expiresAt ?? ''),
    );
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
