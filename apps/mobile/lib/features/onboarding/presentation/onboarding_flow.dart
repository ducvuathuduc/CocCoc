import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/duo_illustration.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/onboarding_controller.dart';
import '../domain/onboarding_content.dart';
import '../domain/onboarding_state.dart';
import 'widgets/onboarding_motion.dart';
import 'widgets/onboarding_parts.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});
  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  Timer? _buildingTimer;
  bool _forward = true;

  @override
  void dispose() {
    _buildingTimer?.cancel();
    super.dispose();
  }

  Future<bool?> _dialog(DialogCopy copy) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(copy.title),
      content: Text(copy.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(copy.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(copy.confirm),
        ),
      ],
    ),
  );

  Future<void> _continue(OnboardingState state, OnboardingContent copy) async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    if (state.step == OnboardingStep.reminder) {
      final result = await _dialog(copy.reminderDialog);
      if (result != null && mounted) controller.chooseReminders(result);
      return;
    }
    if (state.step == OnboardingStep.widget) {
      controller.chooseWidget(true);
      return;
    }
    if (state.step == OnboardingStep.plan && state.plan == 1) {
      final result = await _dialog(copy.superDialog);
      if (result != true || !mounted) return;
    }
    controller.advance();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final copy = ref.watch(onboardingContentProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    ref.listen(onboardingControllerProvider, (previous, next) {
      if (previous != null && previous.step != next.step) {
        _forward = next.step.index > previous.step.index;
      }
    });
    if (state.step == OnboardingStep.building) {
      _buildingTimer ??= Timer(const Duration(milliseconds: 1800), () {
        _buildingTimer = null;
        if (mounted) {
          ref.read(onboardingControllerProvider.notifier).finishBuilding();
        }
      });
    } else {
      _buildingTimer?.cancel();
      _buildingTimer = null;
    }
    final centered = {
      OnboardingStep.greeting,
      OnboardingStep.questions,
      OnboardingStep.levelConfirmation,
      OnboardingStep.building,
    }.contains(state.step);
    final busy = ref.watch(finalSaveBusyProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) controller.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (state.step != OnboardingStep.building)
                FlowHeader(
                  onBack: controller.back,
                  progress: copy.progress[state.step],
                ),
              Expanded(
                child: OnboardingPageSwitcher(
                  pageKey: ValueKey(state.step),
                  forward: _forward,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: centered
                            ? _CenteredStep(
                                state: state,
                                copy: copy,
                                availableHeight: constraints.maxHeight,
                              )
                            : _QuestionStep(state: state, copy: copy),
                      ),
                    ),
                  ),
                ),
              ),
              if (ref.watch(persistenceErrorProvider))
                _SaveError(copy: copy, onRetry: controller.retrySave),
              if (state.step != OnboardingStep.building)
                Container(
                  decoration:
                      state.step == OnboardingStep.language ||
                          state.step == OnboardingStep.reasons
                      ? const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: ReferenceColors.border,
                              width: 2,
                            ),
                          ),
                        )
                      : null,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    children: [
                      ReferenceButton(
                        label: busy
                            ? copy.savingLabel
                            : copy.buttonLabel(state.step),
                        onPressed:
                            !busy &&
                                (state.canContinue ||
                                    state.step == OnboardingStep.reminder ||
                                    state.step == OnboardingStep.widget)
                            ? () => _continue(state, copy)
                            : null,
                      ),
                      if (state.step == OnboardingStep.widget)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextButton(
                            onPressed: () => controller.chooseWidget(false),
                            child: Text(
                              copy.notNowLabel,
                              style: const TextStyle(
                                color: ReferenceColors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .8,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveError extends StatelessWidget {
  const _SaveError({required this.copy, required this.onRetry});
  final OnboardingContent copy;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(copy.saveErrorText, style: const TextStyle(fontSize: 14)),
        ),
        TextButton(onPressed: onRetry, child: Text(copy.retryLabel)),
      ],
    ),
  );
}

class _CenteredStep extends StatelessWidget {
  const _CenteredStep({
    required this.state,
    required this.copy,
    required this.availableHeight,
  });
  final OnboardingState state;
  final OnboardingContent copy;
  final double availableHeight;
  @override
  Widget build(BuildContext context) {
    final language = state.language ?? copy.fallbackLanguage;
    if (state.step == OnboardingStep.building) {
      return SizedBox(
        height: availableHeight,
        child: Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(3, 0),
                  child: const PopIn(
                    duration: OnboardingMotion.mascot,
                    alignment: Alignment.bottomCenter,
                    child: DuoIllustration(
                      ReferenceArtRegions.building,
                      width: 123,
                      height: 154,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  copy.buildingTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ReferenceColors.disabled,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Text.rich(
                  promptSpan([
                    for (final s in copy.buildingBody) s.resolve(language),
                  ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ReferenceColors.muted,
                    fontSize: 20,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final text = promptSpan(
      copy.prompt(
        state.step,
        language,
        answered:
            state.step == OnboardingStep.levelConfirmation &&
            state.knowledge > 1,
      ),
    );
    final art = switch (state.step) {
      OnboardingStep.greeting => ReferenceArtRegions.waving,
      OnboardingStep.questions => ReferenceArtRegions.excited,
      _ => ReferenceArtRegions.writing,
    };
    final horizontal = state.step == OnboardingStep.greeting
        ? 90 / 390 * MediaQuery.sizeOf(context).width
        : state.step == OnboardingStep.levelConfirmation
        ? 39.0
        : 35.0;
    final painter =
        TextPainter(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'DuolingoSans',
              fontSize: 20,
              height: 1.42,
            ),
            children: [text],
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: (MediaQuery.sizeOf(context).width - 64 - 2 * horizontal)
              .clamp(1, double.infinity),
        );
    final extraHeight = (painter.height - 28.4).clamp(0, double.infinity);
    painter.dispose();
    // The reference intro sits below the vertical center. The content grows
    // and scrolls for accessibility rather than scaling or clipping text.
    return Padding(
      padding: EdgeInsets.only(
        top: (availableHeight * .40 + 1.3 - extraHeight).clamp(24, 270),
        bottom: 24,
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: PopIn(
              delay: const Duration(milliseconds: 120),
              alignment: Alignment.bottomCenter,
              child: SpeechBubble(
                below: true,
                child: Text.rich(
                  text,
                  textAlign: state.step == OnboardingStep.levelConfirmation
                      ? TextAlign.left
                      : TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Transform.translate(
            offset: Offset((art.source.center.dx - 590) * 390 / 1180, 0),
            child: PopIn(
              duration: OnboardingMotion.mascot,
              alignment: Alignment.bottomCenter,
              child: DuoIllustration(
                art,
                width: art.source.width * 390 / 1180,
                height: art.source.height * 390 / 1180,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionStep extends ConsumerWidget {
  const _QuestionStep({required this.state, required this.copy});
  final OnboardingState state;
  final OnboardingContent copy;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(onboardingControllerProvider.notifier);
    final language = state.language ?? copy.fallbackLanguage;
    final answered = switch (state.step) {
      OnboardingStep.reasons => state.reasonIds.isNotEmpty,
      OnboardingStep.plan => state.plan == 0,
      _ => false,
    };
    final question = promptSpan(
      copy.prompt(state.step, language, answered: answered),
    );
    final body = switch (state.step) {
      OnboardingStep.language => _LanguageChoices(
        state: state,
        copy: copy,
        onSelect: c.selectLanguage,
      ),
      OnboardingStep.knowledge => Column(
        children: [
          for (var i = 0; i < copy.knowledgeLevels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: OnboardingOption(
                selected: state.knowledge == i,
                minHeight: 35,
                onTap: () => c.selectKnowledge(i),
                child: Row(
                  children: [
                    LevelBars(level: i, selected: state.knowledge == i),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        copy.knowledgeLevels[i].replaceAll(
                          '{language}',
                          language,
                        ),
                        style: optionTextStyle.copyWith(height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      OnboardingStep.reasons => Column(
        children: [
          for (var i = 0; i < copy.reasons.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: OnboardingOption(
                selected: state.reasonIds.contains(i),
                onTap: () => c.toggleReason(i),
                child: Row(
                  children: [
                    DuoIllustration(
                      ReferenceArtRegions.reasonIcons[copy.reasons[i].artIndex],
                      width: 40,
                      height: 36,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        copy.reasons[i].label,
                        style: optionTextStyle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ReasonCheckbox(checked: state.reasonIds.contains(i)),
                  ],
                ),
              ),
            ),
        ],
      ),
      OnboardingStep.goal => Column(
        children: [
          for (final goal in copy.goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: OnboardingOption(
                selected: state.goal == goal.minutes,
                onTap: () => c.selectGoal(goal.minutes),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${goal.minutes} min / day',
                        style: optionTextStyle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      goal.intensity,
                      style: TextStyle(
                        fontSize: 16.5,
                        color: state.goal == goal.minutes
                            ? ReferenceColors.blue
                            : ReferenceColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      OnboardingStep.reminder => NotificationPreview(
        copy: copy.notificationPreview,
      ),
      OnboardingStep.widget => const Center(
        child: PopIn(
          duration: OnboardingMotion.mascot,
          alignment: Alignment.bottomCenter,
          child: DuoIllustration(
            ReferenceArtRegions.phoneWidget,
            width: 290,
            height: 308,
          ),
        ),
      ),
      OnboardingStep.benefits => BenefitList(items: copy.benefits),
      OnboardingStep.plan => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          children: [
            for (var i = 0; i < copy.plans.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              DetailChoice(
                option: copy.plans[i],
                language: language,
                selected: state.plan == copy.plans[i].value,
                onTap: () => c.selectPlan(copy.plans[i].value),
              ),
            ],
          ],
        ),
      ),
      OnboardingStep.startPoint => Column(
        children: [
          for (var i = 0; i < copy.startOptions.length; i++) ...[
            if (i > 0) const SizedBox(height: 15),
            DetailChoice(
              option: copy.startOptions[i],
              language: language,
              selected: state.startPoint == copy.startOptions[i].value,
              art: copy.startOptions[i].value == 0
                  ? ReferenceArtRegions.book
                  : ReferenceArtRegions.compass,
              onTap: () => c.selectStart(copy.startOptions[i].value),
            ),
          ],
        ],
      ),
      _ => const SizedBox.shrink(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const DuoIllustration(
              ReferenceArtRegions.questionDuo,
              width: 95,
              height: 117,
            ),
            const SizedBox(width: 26),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: switch (state.step) {
                    OnboardingStep.language => 207,
                    OnboardingStep.reasons =>
                      state.reasonIds.isEmpty ? 184 : 220,
                    OnboardingStep.reminder => 238,
                    OnboardingStep.goal ||
                    OnboardingStep.routine ||
                    OnboardingStep.promise => 200,
                    _ => 220,
                  },
                ),
                child: PopIn(
                  key: ValueKey(question.toPlainText()),
                  alignment: Alignment.centerLeft,
                  child: SpeechBubble(child: Text.rich(question)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: switch (state.step) {
            OnboardingStep.language => 8,
            OnboardingStep.widget => 60,
            OnboardingStep.benefits => 30,
            _ => 20,
          },
        ),
        body,
        const SizedBox(height: 18),
      ],
    );
  }
}

class _LanguageChoices extends StatefulWidget {
  const _LanguageChoices({
    required this.state,
    required this.copy,
    required this.onSelect,
  });
  final OnboardingState state;
  final OnboardingContent copy;
  final ValueChanged<String> onSelect;
  @override
  State<_LanguageChoices> createState() => _LanguageChoicesState();
}

class _LanguageChoicesState extends State<_LanguageChoices> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        expanded: _expanded,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.copy.sourceLanguageHeader,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0 : .5,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: ReferenceColors.disabled,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (_expanded)
        for (final option in widget.copy.languages)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: OnboardingOption(
              selected: widget.state.language == option.name,
              onTap: () => widget.onSelect(option.name),
              child: Row(
                children: [
                  if (option.flagIndex == null)
                    const ChineseFlag()
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: DuoIllustration(
                        ReferenceArtRegions.flags[option.flagIndex!],
                        width: 40,
                        height: 31,
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(option.name, style: optionTextStyle)),
                ],
              ),
            ),
          ),
    ],
  );
}
