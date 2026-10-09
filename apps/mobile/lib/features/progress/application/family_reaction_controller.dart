import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'extended_controller.dart';

class FamilyReactionState {
  const FamilyReactionState({this.selected = 0, this.nudged = const {}});
  final int selected;
  final Set<String> nudged;
}

final familyReactionControllerProvider =
    NotifierProvider<FamilyReactionController, FamilyReactionState>(
      FamilyReactionController.new,
    );

class FamilyReactionController extends Notifier<FamilyReactionState> {
  @override
  FamilyReactionState build() {
    ref.listen(extendedControllerProvider, (before, after) {
      if (!after.isFamily) {
        state = const FamilyReactionState();
        return;
      }
      state = FamilyReactionState(
        selected: state.selected,
        nudged: Set.unmodifiable(state.nudged.where(after.invited.contains)),
      );
    });
    return const FamilyReactionState();
  }

  void select(int value) {
    if (value < 0 || value > 3) return;
    state = FamilyReactionState(selected: value, nudged: state.nudged);
  }

  bool send(String name) {
    final family = ref.read(extendedControllerProvider);
    if (!family.isFamily ||
        !family.invited.contains(name) ||
        state.nudged.contains(name)) {
      return false;
    }
    state = FamilyReactionState(
      selected: state.selected,
      nudged: Set.unmodifiable({...state.nudged, name}),
    );
    return true;
  }
}
