import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'extended_controller.dart';

enum MaxStage { offer, comparison, reminder, plans }

class MaxState {
  const MaxState({
    this.stage = MaxStage.offer,
    this.selectedPlan = 'max-individual',
    this.reminderDays,
    this.tourStep = -1,
    this.appIcon = false,
    this.tourComplete = false,
  });
  final MaxStage stage;
  final String selectedPlan;
  final int? reminderDays;
  final int tourStep;
  final bool appIcon;
  final bool tourComplete;
  MaxState copyWith({
    MaxStage? stage,
    String? selectedPlan,
    int? reminderDays,
    int? tourStep,
    bool? appIcon,
    bool? tourComplete,
  }) => MaxState(
    stage: stage ?? this.stage,
    selectedPlan: selectedPlan ?? this.selectedPlan,
    reminderDays: reminderDays ?? this.reminderDays,
    tourStep: tourStep ?? this.tourStep,
    appIcon: appIcon ?? this.appIcon,
    tourComplete: tourComplete ?? this.tourComplete,
  );
}

final maxControllerProvider = NotifierProvider<MaxController, MaxState>(
  MaxController.new,
);

class MaxController extends Notifier<MaxState> {
  @override
  MaxState build() {
    ref.listen(extendedControllerProvider, (before, after) {
      if (before?.isMax == true && !after.isMax) state = const MaxState();
    });
    return const MaxState();
  }

  void next() {
    if (state.stage == MaxStage.plans ||
        (state.stage == MaxStage.reminder && state.reminderDays == null)) {
      return;
    }
    state = state.copyWith(stage: MaxStage.values[state.stage.index + 1]);
  }

  bool back() {
    if (state.stage == MaxStage.offer) return false;
    state = state.copyWith(stage: MaxStage.values[state.stage.index - 1]);
    return true;
  }

  void chooseReminder(int days) {
    if (days == 2 || days == 3) state = state.copyWith(reminderDays: days);
  }

  void choosePlan(String plan) {
    if (plan == 'max-individual' || plan == 'max-family') {
      state = state.copyWith(selectedPlan: plan);
    }
  }

  bool confirmCheckout() {
    if (state.stage != MaxStage.plans || state.reminderDays == null) {
      return false;
    }
    final vm = ref.read(extendedControllerProvider.notifier);
    vm.choosePlan(state.selectedPlan);
    final confirmed = vm.confirmPlan();
    if (confirmed) state = state.copyWith(tourStep: -1, tourComplete: false);
    return confirmed;
  }

  void advanceTour() => state = state.copyWith(
    tourStep: state.tourComplete ? 0 : (state.tourStep + 1).clamp(-1, 7),
    tourComplete: false,
  );
  void finishTour() => state = state.copyWith(tourComplete: true);
  void setAppIcon(bool value) => state = state.copyWith(appIcon: value);
}
