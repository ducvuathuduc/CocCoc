import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/billing_repository.dart';
import '../domain/billing_models.dart';

class BillingState {
  const BillingState({
    this.busy = false,
    this.loaded = false,
    this.snapshot = const BillingSnapshot(),
    this.message,
    this.hasError = false,
  });
  final bool busy, loaded;
  final BillingSnapshot snapshot;
  final String? message;
  final bool hasError;
}

final billingControllerProvider =
    NotifierProvider<BillingController, BillingState>(BillingController.new);

class BillingController extends Notifier<BillingState> {
  late BillingRepository _repository;
  int _epoch = 0;
  bool _alive = false;
  Timer? _expiry;
  @override
  BillingState build() {
    _repository = ref.watch(billingRepositoryProvider);
    _epoch++;
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _epoch++;
      _expiry?.cancel();
    });
    Future.microtask(restore);
    return const BillingState();
  }

  Future<bool> _run(
    Future<BillingSnapshot> Function() action,
    String success,
  ) async {
    if (!_alive || state.busy) return false;
    final epoch = _epoch;
    final previous = state.snapshot;
    state = BillingState(busy: true, loaded: state.loaded, snapshot: previous);
    try {
      final snapshot = await action();
      if (!_alive || epoch != _epoch) return false;
      state = BillingState(loaded: true, snapshot: snapshot, message: success);
      _expiry?.cancel();
      final expires = snapshot.activeUntil ?? snapshot.receipt?.expiresAt;
      if (snapshot.selection != null && expires != null) {
        final delay = expires.difference(DateTime.now());
        _expiry = Timer(delay.isNegative ? Duration.zero : delay, () {
          if (!_alive || epoch != _epoch) return;
          state = BillingState(
            loaded: true,
            snapshot: BillingSnapshot(receipt: state.snapshot.receipt),
          );
          unawaited(restore());
        });
      }
      return true;
    } on PaymentDeclined {
      if (_alive && epoch == _epoch) {
        state = BillingState(
          loaded: true,
          snapshot: previous,
          message: 'Demo payment declined. No plan was activated.',
          hasError: true,
        );
      }
    } catch (_) {
      if (_alive && epoch == _epoch) {
        state = BillingState(
          loaded: true,
          snapshot: previous,
          message: 'Could not verify payment. Restore or retry to check the same order.',
          hasError: true,
        );
      }
    }
    return false;
  }

  Future<bool> restore() => _run(_repository.restore, 'Subscription checked.');
  Future<bool> purchase(BillingProduct product, DemoPaymentOutcome outcome) =>
      _run(
        () => _repository.purchase(product, outcome),
        outcome == DemoPaymentOutcome.pending
            ? 'Payment pending. Premium stays locked until confirmed.'
            : 'Demo payment confirmed.',
      );
  Future<bool> checkPending() =>
      _run(_repository.checkPending, 'Payment status checked.');
  Future<bool> cancelRenewal() => _run(
    _repository.cancelRenewal,
    'Renewal canceled. Access continues until the expiry date.',
  );
}
