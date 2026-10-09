import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/onboarding_repository.dart';
import '../domain/onboarding_state.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => MemoryOnboardingRepository(),
);
final initialOnboardingProvider = Provider<OnboardingState>(
  (ref) => OnboardingState(),
);
final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
final persistenceErrorProvider = NotifierProvider<PersistenceError, bool>(
  PersistenceError.new,
);
final finalSaveBusyProvider = NotifierProvider<PersistenceError, bool>(
  PersistenceError.new,
);

class PersistenceError extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class OnboardingController extends Notifier<OnboardingState> {
  Future<void> _pending = Future.value();
  bool _disposed = false;

  @override
  OnboardingState build() {
    ref.onDispose(() => _disposed = true);
    return ref.read(initialOnboardingProvider);
  }

  void _update(OnboardingState next) {
    if (ref.read(finalSaveBusyProvider)) return;
    state = next;
    final repository = ref.read(onboardingRepositoryProvider);
    // Every snapshot is immutable; queued writes cannot finish out of order.
    _pending = _pending
        .then((_) => repository.save(next))
        .then(
          (_) {
            if (!_disposed) {
              ref.read(persistenceErrorProvider.notifier).set(false);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!_disposed) {
              ref.read(persistenceErrorProvider.notifier).set(true);
            }
          },
        );
  }

  Future<void> flush() => _pending;
  void retrySave() => _update(state);

  void selectLanguage(String value) {
    if (!languages.contains(value)) return;
    _update(
      state.language == value
          ? state
          : state.copyWith(language: value, knowledge: -1, startPoint: -1),
    );
  }

  void selectKnowledge(int value) {
    if (value < 0 || value > 4) return;
    _update(state.copyWith(knowledge: value, startPoint: value == 0 ? 0 : 1));
  }

  void toggleReason(int value) {
    if (value < 0 || value >= reasons.length) return;
    final ids = {...state.reasonIds};
    ids.contains(value) ? ids.remove(value) : ids.add(value);
    _update(state.copyWith(reasonIds: ids));
  }

  void selectGoal(int value) {
    if (goalMinutes.contains(value)) _update(state.copyWith(goal: value));
  }

  void selectPlan(int value) {
    if (value == 0 || value == 1) _update(state.copyWith(plan: value));
  }

  void selectStart(int value) {
    if (value == 0 || value == 1) _update(state.copyWith(startPoint: value));
  }

  void chooseReminders(bool value) {
    _update(state.copyWith(reminders: value));
    advance();
  }

  void chooseWidget(bool value) {
    _update(state.copyWith(widgetRequested: value));
    advance();
  }

  void finishBuilding() {
    if (state.step == OnboardingStep.building) {
      _update(state.copyWith(step: OnboardingStep.knowledge));
    }
  }

  void advance() {
    if (ref.read(finalSaveBusyProvider)) return;
    if (!state.canContinue) return;
    final next =
        state.step == OnboardingStep.startPoint && state.startPoint == 0
        ? OnboardingStep.lessonEntry
        : OnboardingStep.values[state.step.index + 1];
    if (next == OnboardingStep.lessonEntry) {
      final snapshot = state.copyWith(step: next);
      final repository = ref.read(onboardingRepositoryProvider);
      ref.read(finalSaveBusyProvider.notifier).set(true);
      _pending = _pending
          .then((_) => repository.save(snapshot))
          .then(
            (_) {
              if (_disposed) return;
              ref.read(persistenceErrorProvider.notifier).set(false);
              ref.read(finalSaveBusyProvider.notifier).set(false);
              state = snapshot;
            },
            onError: (Object error, StackTrace stack) {
              if (_disposed) return;
              ref.read(persistenceErrorProvider.notifier).set(true);
              ref.read(finalSaveBusyProvider.notifier).set(false);
            },
          );
    } else {
      _update(state.copyWith(step: next));
    }
  }

  void back() {
    if (ref.read(finalSaveBusyProvider)) return;
    if (state.step == OnboardingStep.welcome) return;
    final previous = switch (state.step) {
      OnboardingStep.knowledge ||
      OnboardingStep.building => OnboardingStep.language,
      OnboardingStep.lessonEntry => OnboardingStep.startPoint,
      _ => OnboardingStep.values[state.step.index - 1],
    };
    _update(state.copyWith(step: previous));
  }
}
