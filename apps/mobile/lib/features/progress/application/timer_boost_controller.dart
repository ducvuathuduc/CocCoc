import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preview_controller.dart';

class TimerBoostState {
  const TimerBoostState({
    this.pack = 5,
    this.receipt = 0,
    this.added = 0,
    this.error,
  });
  final int pack, receipt, added;
  final String? error;
}

final timerBoostControllerProvider =
    NotifierProvider<TimerBoostController, TimerBoostState>(
      TimerBoostController.new,
    );

class TimerBoostController extends Notifier<TimerBoostState> {
  @override
  TimerBoostState build() => const TimerBoostState();
  void begin() => state = TimerBoostState(
    pack: state.pack,
    receipt: state.receipt + (state.added > 0 ? 1 : 0),
  );
  void select(int count) {
    if (!timerBoostPrices.containsKey(count) || state.added > 0) return;
    state = TimerBoostState(pack: count, receipt: state.receipt);
  }

  void useDemoBalance() {
    ref.read(previewControllerProvider.notifier).useDemoBalance();
    state = TimerBoostState(pack: state.pack, receipt: state.receipt);
  }

  bool purchase() {
    if (state.added > 0) return false;
    final bought = ref
        .read(previewControllerProvider.notifier)
        .buyTimerBoost('timer-boost-${state.receipt}', state.pack);
    state = TimerBoostState(
      pack: state.pack,
      receipt: state.receipt,
      added: bought ? state.pack : 0,
      error: bought ? null : 'Not enough gems',
    );
    return bought;
  }
}
