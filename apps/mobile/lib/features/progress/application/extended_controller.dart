import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExtendedState {
  const ExtendedState({
    this.selectedPlan,
    this.plan,
    this.energy = 25,
    this.invited = const {},
    this.cancelReason,
  });
  final String? selectedPlan, plan, cancelReason;
  final int energy;
  final Set<String> invited;
  bool get unlimited => plan != null;
  bool get isMax => plan == 'max-individual' || plan == 'max-family';
  bool get isFamily => plan == 'family' || plan == 'max-family';
}

final extendedControllerProvider =
    NotifierProvider<ExtendedController, ExtendedState>(ExtendedController.new);

class ExtendedController extends Notifier<ExtendedState> {
  @override
  ExtendedState build() => const ExtendedState();

  void choosePlan(String plan) {
    if (!{
      'individual',
      'family',
      'monthly',
      'max-individual',
      'max-family',
    }.contains(plan)) {
      return;
    }
    state = ExtendedState(
      selectedPlan: plan,
      plan: state.plan,
      energy: state.energy,
      invited: state.invited,
    );
  }

  bool confirmPlan() {
    if (state.selectedPlan == null) return false;
    state = ExtendedState(
      selectedPlan: state.selectedPlan,
      plan: state.selectedPlan,
      energy: state.energy,
      invited:
          state.selectedPlan == 'family' || state.selectedPlan == 'max-family'
          ? state.invited
          : const {},
    );
    return true;
  }

  void cancelPlan([String? reason]) =>
      state = ExtendedState(energy: state.energy, cancelReason: reason);

  String? invite(String name) {
    final value = name.trim();
    if (!state.isFamily) return 'Choose the Family Plan first.';
    if (value.isEmpty || value.length > 60) {
      return 'Enter a name between 1 and 60 characters.';
    }
    if (state.invited.length >= 5 && !state.invited.contains(value)) {
      return 'Your family has no more spaces.';
    }
    state = ExtendedState(
      selectedPlan: state.selectedPlan,
      plan: state.plan,
      energy: state.energy,
      invited: Set.unmodifiable({...state.invited, value}),
    );
    return null;
  }
}
