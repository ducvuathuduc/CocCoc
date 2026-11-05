import 'package:flutter_riverpod/flutter_riverpod.dart';

class AndroidSuperState {
  const AndroidSuperState({
    this.step = 0,
    this.selection = 'individual',
    this.busy = false,
  });
  final int step;
  final String selection;
  final bool busy;
}

final androidSuperControllerProvider =
    NotifierProvider.autoDispose<AndroidSuperController, AndroidSuperState>(
      AndroidSuperController.new,
    );

class AndroidSuperController extends Notifier<AndroidSuperState> {
  @override
  AndroidSuperState build() => const AndroidSuperState();
  void next() {
    if (!state.busy && state.step < 2) {
      state = AndroidSuperState(
        step: state.step + 1,
        selection: state.selection,
      );
    }
  }

  void back() {
    if (!state.busy && state.step > 0) {
      state = AndroidSuperState(
        step: state.step - 1,
        selection: state.selection,
      );
    }
  }

  void choose(String selection) {
    if (!state.busy &&
        {'individual', 'monthly', 'family'}.contains(selection)) {
      state = AndroidSuperState(step: state.step, selection: selection);
    }
  }

  bool beginCheckout() {
    if (state.busy || state.step != 2) return false;
    state = AndroidSuperState(
      step: state.step,
      selection: state.selection,
      busy: true,
    );
    return true;
  }

  void endCheckout() {
    if (ref.mounted) {
      state = AndroidSuperState(step: state.step, selection: state.selection);
    }
  }
}
