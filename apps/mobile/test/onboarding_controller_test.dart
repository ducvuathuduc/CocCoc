import 'dart:async';

import 'package:cocenglish/features/onboarding/application/onboarding_controller.dart';
import 'package:cocenglish/features/onboarding/data/onboarding_repository.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer containerFor({
  OnboardingState? initial,
  OnboardingRepository? repository,
}) => ProviderContainer(
  overrides: [
    initialOnboardingProvider.overrideWithValue(initial ?? OnboardingState()),
    onboardingRepositoryProvider.overrideWithValue(
      repository ?? MemoryOnboardingRepository(),
    ),
  ],
);

void main() {
  test(
    'final step stays reviewable until its snapshot is saved successfully',
    () async {
      final repository = _FailingRepository();
      final container = containerFor(
        repository: repository,
        initial: OnboardingState(
          step: OnboardingStep.levelConfirmation,
          language: 'French',
          knowledge: 1,
          reasonIds: {0},
          reminders: false,
          widgetRequested: false,
          plan: 0,
          startPoint: 1,
        ),
      );
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);
      controller.advance();
      await controller.flush();
      expect(
        container.read(onboardingControllerProvider).step,
        OnboardingStep.levelConfirmation,
      );
      expect(container.read(persistenceErrorProvider), true);
      repository.fail = false;
      controller.advance();
      await controller.flush();
      expect(
        container.read(onboardingControllerProvider).step,
        OnboardingStep.lessonEntry,
      );
      expect((await repository.load()).step, OnboardingStep.lessonEntry);
    },
  );
  test(
    'required answers block Continue; Back retains language and level',
    () async {
      final container = containerFor(
        initial: OnboardingState(step: OnboardingStep.language),
      );
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);
      controller.advance();
      expect(
        container.read(onboardingControllerProvider).step,
        OnboardingStep.language,
      );
      controller.selectLanguage('French');
      controller.advance();
      controller.finishBuilding();
      controller.advance();
      expect(
        container.read(onboardingControllerProvider).step,
        OnboardingStep.knowledge,
      );
      controller.selectKnowledge(1);
      controller.advance();
      controller.back();
      controller.back();
      final state = container.read(onboardingControllerProvider);
      expect(state.step, OnboardingStep.language);
      expect(state.language, 'French');
      expect(state.knowledge, 1);
      controller.selectLanguage('Japanese');
      expect(container.read(onboardingControllerProvider).knowledge, -1);
      await controller.flush();
    },
  );

  test(
    'reasons toggle independently and removing the last disables Continue',
    () async {
      final container = containerFor(
        initial: OnboardingState(
          step: OnboardingStep.reasons,
          language: 'French',
          knowledge: 1,
        ),
      );
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);
      controller.toggleReason(0);
      controller.toggleReason(2);
      controller.toggleReason(0);
      expect(container.read(onboardingControllerProvider).reasonIds, {2});
      controller.toggleReason(2);
      controller.advance();
      expect(
        container.read(onboardingControllerProvider).step,
        OnboardingStep.reasons,
      );
      controller.toggleReason(3);
      controller.advance();
      expect(
        container.read(onboardingControllerProvider).step,
        OnboardingStep.routine,
      );
      await controller.flush();
    },
  );

  test('goal and denied reminder survive restart; scratch bypasses level confirmation', () async {
    final repository = MemoryOnboardingRepository();
    final container = containerFor(
      repository: repository,
      initial: OnboardingState(
        step: OnboardingStep.goal,
        language: 'French',
        knowledge: 1,
        reasonIds: {0},
      ),
    );
    addTearDown(container.dispose);
    final controller = container.read(onboardingControllerProvider.notifier);
    controller.selectGoal(15);
    controller.advance();
    controller.advance();
    controller.chooseReminders(false);
    controller.chooseWidget(false);
    controller.advance();
    controller.selectPlan(0);
    controller.advance();
    controller.selectStart(0);
    controller.advance();
    await controller.flush();
    final restored = OnboardingState.fromJson(
      (await repository.load()).toJson(),
    );
    expect(restored.step, OnboardingStep.lessonEntry);
    expect(restored.goal, 15);
    expect(restored.reminders, false);
    expect(restored.widgetRequested, false);
    controller.back();
    controller.selectStart(1);
    controller.advance();
    expect(
      container.read(onboardingControllerProvider).step,
      OnboardingStep.levelConfirmation,
    );
    await controller.flush();
  });

  test(
    'queued writes preserve latest selection while a prior save is blocked',
    () async {
      final repository = _DelayedRepository();
      final container = containerFor(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);
      controller.selectGoal(5);
      controller.selectGoal(20);
      await Future<void>.delayed(Duration.zero);
      expect(repository.writes, [5]);
      repository.first.complete();
      await controller.flush();
      expect(repository.writes, [5, 20]);
      expect((await repository.load()).goal, 20);
    },
  );

  test('save failure keeps input and retry clears the error', () async {
    final repository = _FailingRepository();
    final container = containerFor(repository: repository);
    addTearDown(container.dispose);
    final controller = container.read(onboardingControllerProvider.notifier);
    controller.selectGoal(15);
    await controller.flush();
    expect(container.read(persistenceErrorProvider), true);
    expect(container.read(onboardingControllerProvider).goal, 15);
    repository.fail = false;
    controller.retrySave();
    await controller.flush();
    expect(container.read(persistenceErrorProvider), false);
    expect((await repository.load()).goal, 15);
  });

  test('corrupt/unknown snapshots reset safely; missing earlier answer resumes there', () {
    expect(
      OnboardingState.fromJson({'version': 99}).step,
      OnboardingStep.welcome,
    );
    expect(
      OnboardingState.fromJson({'version': 1, 'step': 'invalid'}).step,
      OnboardingStep.welcome,
    );
    final incomplete = OnboardingState(
      step: OnboardingStep.plan,
      language: 'French',
      knowledge: 1,
      reasonIds: {0},
    );
    final restored = OnboardingState.fromJson(incomplete.toJson());
    expect(restored.step, OnboardingStep.reminder);
    expect(restored.language, 'French');
    expect(restored.reasonIds, {0});
  });
}

class _DelayedRepository extends MemoryOnboardingRepository {
  final first = Completer<void>();
  final writes = <int>[];
  @override
  Future<void> save(OnboardingState state) async {
    writes.add(state.goal);
    if (writes.length == 1) await first.future;
    await super.save(state);
  }
}

class _FailingRepository extends MemoryOnboardingRepository {
  bool fail = true;
  @override
  Future<void> save(OnboardingState state) async {
    if (fail) throw StateError('Disk unavailable');
    await super.save(state);
  }
}
