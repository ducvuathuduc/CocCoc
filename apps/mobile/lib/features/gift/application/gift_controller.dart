import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gift_repository.dart';
import '../domain/gift_models.dart';

class GiftState {
  const GiftState({
    required this.plans,
    required this.friends,
    required this.faqs,
    required this.sent,
    required this.planId,
    this.recipientId,
    this.note = '',
    this.purchasing = false,
    this.lastOrder,
  });
  final List<GiftPlan> plans;
  final List<GiftRecipient> friends;
  final List<GiftFaq> faqs;
  final List<GiftOrder> sent;
  final String planId;
  final String? recipientId;
  final String note;
  final bool purchasing;
  final GiftOrder? lastOrder;

  GiftPlan get plan => plans.firstWhere((p) => p.id == planId);
  GiftRecipient? get recipient => recipientId == null
      ? null
      : friends.where((f) => f.id == recipientId).firstOrNull;
  bool get canContinue => recipient != null;

  GiftState copyWith({
    List<GiftOrder>? sent,
    String? planId,
    String? recipientId,
    String? note,
    bool? purchasing,
    GiftOrder? lastOrder,
  }) => GiftState(
    plans: plans,
    friends: friends,
    faqs: faqs,
    sent: sent ?? this.sent,
    planId: planId ?? this.planId,
    recipientId: recipientId ?? this.recipientId,
    note: note ?? this.note,
    purchasing: purchasing ?? this.purchasing,
    lastOrder: lastOrder ?? this.lastOrder,
  );
}

/// Gift Super flow: intro → recipient & plan → note → mock checkout → sent.
class GiftController extends Notifier<GiftState> {
  GiftRepository get _repo => ref.read(giftRepositoryProvider);

  @override
  GiftState build() => _fresh();

  GiftState _fresh() => GiftState(
    plans: _repo.plans,
    friends: _repo.friends,
    faqs: _repo.faqs,
    sent: _repo.sentGifts,
    planId: _repo.plans.first.id,
  );

  /// Starts a new gift (keeps the history of sent gifts).
  void start() => state = _fresh();
  void selectPlan(String id) => state = state.copyWith(planId: id);
  void selectRecipient(String id) => state = state.copyWith(recipientId: id);
  void setNote(String note) => state = state.copyWith(note: note);

  Future<GiftOrder?> purchase() async {
    final recipient = state.recipient;
    if (recipient == null || state.purchasing) return null;
    state = state.copyWith(purchasing: true);
    final order = await _repo.purchase(
      plan: state.plan,
      recipient: recipient,
      note: state.note.trim(),
    );
    state = state.copyWith(
      purchasing: false,
      lastOrder: order,
      sent: _repo.sentGifts,
    );
    return order;
  }
}

final giftControllerProvider = NotifierProvider<GiftController, GiftState>(
  GiftController.new,
);
