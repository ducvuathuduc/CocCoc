import 'package:flutter_riverpod/flutter_riverpod.dart';

final adventureControllerProvider =
    NotifierProvider<AdventureController, AdventureState>(
      AdventureController.new,
    );

class AdventureState {
  const AdventureState({
    this.stage = 0,
    this.selected,
    this.feedback,
    this.correct = 0,
    this.attempted = 0,
    this.claimed = false,
  });
  final int stage, correct, attempted;
  final String? selected;
  final bool? feedback;
  final bool claimed;
  bool get complete => stage == 6;
  int get accuracy => attempted == 0 ? 0 : (correct * 100 / attempted).round();
}

// In-memory language preview, with no billing or service-owned XP writes.
class AdventureController extends Notifier<AdventureState> {
  @override
  AdventureState build() => const AdventureState();
  void start() => state = const AdventureState(stage: 1);
  void explore() {
    if (state.stage == 1 || state.stage == 4) _move(state.stage + 1);
  }

  List<String> get options => state.stage == 2
      ? const ['An American passport!', 'A dog!']
      : state.stage == 5
      ? const ['sandwich', 'phone', 'pizza', 'passport']
      : const [];
  void select(String value) {
    if (state.feedback == null && options.contains(value)) {
      state = AdventureState(
        stage: state.stage,
        selected: value,
        correct: state.correct,
        attempted: state.attempted,
      );
    }
  }

  void check() {
    if (state.feedback != null || state.selected == null || options.isEmpty) {
      return;
    }
    final correct =
        state.selected ==
        (state.stage == 2 ? 'An American passport!' : 'passport');
    state = AdventureState(
      stage: state.stage,
      selected: state.selected,
      feedback: correct,
      correct: state.correct + (correct ? 1 : 0),
      attempted: state.attempted + 1,
    );
  }

  void next() {
    if (state.stage == 3) {
      _move(4);
    } else if (state.feedback == true) {
      _move(state.stage + 1);
    } else if (state.feedback == false) {
      _move(state.stage);
    }
  }

  void _move(int stage) => state = AdventureState(
    stage: stage,
    correct: state.correct,
    attempted: state.attempted,
  );
  bool claim() {
    if (!state.complete || state.claimed) return false;
    state = AdventureState(
      stage: state.stage,
      correct: state.correct,
      attempted: state.attempted,
      claimed: true,
    );
    return true;
  }
}
