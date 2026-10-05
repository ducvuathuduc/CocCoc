import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/duo_illustration.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/onboarding_controller.dart';
import '../domain/onboarding_state.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});
  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  Timer? _buildingTimer;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _buildingTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reminders() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Practice reminders'),
        content: const Text(
          'Would you like a daily reminder? You can change this preference later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remind me'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      ref.read(onboardingControllerProvider.notifier).chooseReminders(result);
    }
  }

  Future<void> _continue(OnboardingState state) async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    if (state.step == OnboardingStep.reminder) {
      await _reminders();
      return;
    }
    if (state.step == OnboardingStep.widget) {
      controller.chooseWidget(true);
      return;
    }
    if (state.step == OnboardingStep.plan && state.plan == 1) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Super Duolingo'),
          content: const Text(
            'Explore the Super experience. No purchase is available in this preview.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (result != true || !mounted) return;
    }
    controller.advance();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    ref.listen(onboardingControllerProvider, (previous, next) {
      if (previous?.step != next.step && _scroll.hasClients) _scroll.jumpTo(0);
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
    }.contains(state.step);
    final progress = switch (state.step) {
      OnboardingStep.language => .055,
      OnboardingStep.knowledge => .166,
      OnboardingStep.reasons => .278,
      OnboardingStep.routine => .333,
      OnboardingStep.goal => .39,
      OnboardingStep.promise => .445,
      OnboardingStep.reminder => .50,
      OnboardingStep.widget => .556,
      OnboardingStep.benefits => .778,
      OnboardingStep.plan => .833,
      OnboardingStep.startPoint => .944,
      _ => null,
    };
    final label = switch (state.step) {
      OnboardingStep.goal => 'I’M COMMITTED',
      OnboardingStep.reminder => 'REMIND ME TO PRACTICE',
      OnboardingStep.widget => 'ADD WIDGET',
      _ => 'CONTINUE',
    };
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
                FlowHeader(onBack: controller.back, progress: progress),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: centered || state.step == OnboardingStep.building
                          ? _CenteredStep(
                              state: state,
                              availableHeight: constraints.maxHeight,
                            )
                          : _QuestionStep(state: state),
                    ),
                  ),
                ),
              ),
              if (ref.watch(persistenceErrorProvider))
                _SaveError(onRetry: controller.retrySave),
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
                        label: ref.watch(finalSaveBusyProvider)
                            ? 'SAVING…'
                            : label,
                        onPressed:
                            !ref.watch(finalSaveBusyProvider) &&
                                (state.canContinue ||
                                    state.step == OnboardingStep.reminder ||
                                    state.step == OnboardingStep.widget)
                            ? () => _continue(state)
                            : null,
                      ),
                      if (state.step == OnboardingStep.widget)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextButton(
                            onPressed: () => controller.chooseWidget(false),
                            child: const Text(
                              'NOT NOW',
                              style: TextStyle(
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
  const _SaveError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Couldn’t save your choices.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _CenteredStep extends StatelessWidget {
  const _CenteredStep({required this.state, required this.availableHeight});
  final OnboardingState state;
  final double availableHeight;
  @override
  Widget build(BuildContext context) {
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
                  child: const DuoIllustration(
                    ReferenceArtRegions.building,
                    width: 123,
                    height: 154,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'COURSE BUILDING…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ReferenceColors.disabled,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Get ready to join the '),
                      const TextSpan(
                        text: '7 million people',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            '\ncurrently learning ${state.language ?? 'English'} with\nDuolingo!',
                      ),
                    ],
                  ),
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
    final text = switch (state.step) {
      OnboardingStep.greeting => const TextSpan(text: 'Hi there! I’m Duo!'),
      OnboardingStep.questions => const TextSpan(
        children: [
          TextSpan(text: 'Just '),
          TextSpan(
            text: '7 quick questions',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' before we start your first lesson!'),
        ],
      ),
      _ => TextSpan(
        children: [
          TextSpan(
            text: state.knowledge <= 1
                ? 'Since you know a few words, let’s start at '
                : 'Let’s find the right place for you. Start at ',
          ),
          const TextSpan(
            text: 'Score 10!',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    };
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
          const SizedBox(height: 4),
          Transform.translate(
            offset: Offset((art.source.center.dx - 590) * 390 / 1180, 0),
            child: DuoIllustration(
              art,
              width: art.source.width * 390 / 1180,
              height: art.source.height * 390 / 1180,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionStep extends ConsumerWidget {
  const _QuestionStep({required this.state});
  final OnboardingState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(onboardingControllerProvider.notifier);
    final language = state.language ?? 'English';
    final question = switch (state.step) {
      OnboardingStep.language => const TextSpan(
        text: 'What would you like to learn?',
      ),
      OnboardingStep.knowledge => TextSpan(
        text: 'How much $language do you know?',
      ),
      OnboardingStep.reasons => TextSpan(
        text: state.reasonIds.isEmpty
            ? 'Why are you learning $language?'
            : 'Let’s prepare you for conversations!',
      ),
      OnboardingStep.routine => const TextSpan(
        text: 'Let’s set up a learning routine!',
      ),
      OnboardingStep.goal => const TextSpan(
        text: 'What’s your daily learning goal?',
      ),
      OnboardingStep.promise => const TextSpan(
        children: [
          TextSpan(text: 'That’s '),
          TextSpan(
            text: '50 words',
            style: TextStyle(
              color: ReferenceColors.purple,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: ' in your first week!'),
        ],
      ),
      OnboardingStep.reminder => const TextSpan(
        text: 'I’ll remind you to practice so it becomes a habit!',
      ),
      OnboardingStep.widget => const TextSpan(
        text: 'I’ll cheer you on from your home screen!',
      ),
      OnboardingStep.benefits => const TextSpan(
        text: 'Here’s what you can achieve in 3 months!',
      ),
      OnboardingStep.plan => TextSpan(
        text: state.plan == 0
            ? 'Awesome! You can upgrade anytime.'
            : 'How do you want to get started?',
      ),
      _ => const TextSpan(text: 'Where would you like to start?'),
    };
    final body = switch (state.step) {
      OnboardingStep.language => _LanguageChoices(
        state: state,
        onSelect: c.selectLanguage,
      ),
      OnboardingStep.knowledge => Column(
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: ChoiceCard(
                selected: state.knowledge == i,
                minHeight: 35,
                onTap: () => c.selectKnowledge(i),
                child: Row(
                  children: [
                    _LevelBars(level: i, selected: state.knowledge == i),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        [
                          'I’m new to $language',
                          'I know some common words',
                          'I can have basic conversations',
                          'I can talk about various topics',
                          'I can discuss most topics in detail',
                        ][i],
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
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
          for (var i = 0; i < reasons.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: ChoiceCard(
                selected: state.reasonIds.contains(i),
                onTap: () => c.toggleReason(i),
                child: Row(
                  children: [
                    DuoIllustration(
                      ReferenceArtRegions.reasonIcons[i],
                      width: 40,
                      height: 36,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        reasons[i],
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      checked: state.reasonIds.contains(i),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: state.reasonIds.contains(i)
                              ? const Color(0xFF1CB0F6)
                              : ReferenceColors.surface,
                          border: Border.all(
                            color: state.reasonIds.contains(i)
                                ? const Color(0xFF1CB0F6)
                                : ReferenceColors.border,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: state.reasonIds.contains(i)
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      OnboardingStep.goal => Column(
        children: [
          for (var i = 0; i < goalMinutes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: ChoiceCard(
                selected: state.goal == goalMinutes[i],
                onTap: () => c.selectGoal(goalMinutes[i]),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${goalMinutes[i]} min / day',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      ['Casual', 'Regular', 'Serious', 'Intense'][i],
                      style: TextStyle(
                        fontSize: 16.5,
                        color: state.goal == goalMinutes[i]
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
      OnboardingStep.reminder => const _ReminderIllustration(),
      OnboardingStep.widget => const Center(
        child: DuoIllustration(
          ReferenceArtRegions.phoneWidget,
          width: 290,
          height: 308,
        ),
      ),
      OnboardingStep.benefits => const _Benefits(),
      OnboardingStep.plan => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          children: [
            _DetailChoice(
              title: 'Super Duolingo',
              subtitle: 'Faster progress, no ads',
              selected: state.plan == 1,
              recommended: true,
              onTap: () => c.selectPlan(1),
            ),
            const SizedBox(height: 16),
            _DetailChoice(
              title: 'Learn for free',
              subtitle: 'Core learning features, with ads',
              selected: state.plan == 0,
              onTap: () => c.selectPlan(0),
            ),
          ],
        ),
      ),
      OnboardingStep.startPoint => Column(
        children: [
          _DetailChoice(
            title: 'Start from scratch',
            subtitle: 'Take the easiest lesson of the $language course',
            selected: state.startPoint == 0,
            art: ReferenceArtRegions.book,
            onTap: () => c.selectStart(0),
          ),
          const SizedBox(height: 15),
          _DetailChoice(
            title: 'Find my level',
            subtitle: 'Let Duo recommend where you should start learning',
            selected: state.startPoint == 1,
            art: ReferenceArtRegions.compass,
            recommended: true,
            onTap: () => c.selectStart(1),
          ),
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
                child: SpeechBubble(child: Text.rich(question)),
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
  const _LanguageChoices({required this.state, required this.onSelect});
  final OnboardingState state;
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
                const Expanded(
                  child: Text(
                    'For English speakers',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: ReferenceColors.disabled,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (_expanded)
        for (var i = 0; i < languages.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: ChoiceCard(
              selected: widget.state.language == languages[i],
              onTap: () => widget.onSelect(languages[i]),
              child: Row(
                children: [
                  if (i == 6)
                    const ChineseFlag()
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: DuoIllustration(
                        ReferenceArtRegions.flags[i],
                        width: 40,
                        height: 31,
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      languages[i],
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    ],
  );
}

class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.level, required this.selected});
  final int level;
  final bool selected;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 40,
      height: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 7,
                height: 10.0 + i * 4,
                decoration: BoxDecoration(
                  color: i < level
                      ? ReferenceColors.blue
                      : selected
                      ? const Color(0xFFB6E6F8)
                      : const Color(0xFFD3ECFA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _DetailChoice extends StatelessWidget {
  const _DetailChoice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.recommended = false,
    this.art,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool recommended;
  final ArtRegion? art;
  @override
  Widget build(BuildContext context) => ChoiceCard(
    selected: selected,
    onTap: onTap,
    recommended: recommended,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (art != null) ...[
            SizedBox(
              width: 74,
              child: Center(
                child: DuoIllustration(
                  art!,
                  width: art!.source.width * 390 / 1180,
                  height: art!.source.height * 390 / 1180,
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 16.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Benefits extends StatelessWidget {
  const _Benefits();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DuoIllustration(
                  ReferenceArtRegions.benefitIcons[i],
                  width: 43,
                  height: 42,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          'Converse with confidence',
                          'Build up your vocabulary',
                          'Develop a learning habit',
                        ][i],
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          'Stress-free speaking and listening exercises',
                          'Common words and practical phrases',
                          'Smart reminders, fun challenges, and more',
                        ][i],
                        style: const TextStyle(
                          color: ReferenceColors.muted,
                          fontSize: 16.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ReminderIllustration extends StatelessWidget {
  const _ReminderIllustration();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(47, 14, 47, 12),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8FC),
              border: Border.all(color: ReferenceColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 20, 14, 4),
                  child: Text(
                    '“Duolingo” Would Like to Send You Notifications',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: ReferenceColors.disabled,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 18),
                  child: Text(
                    'Notifications may include alerts, sounds, and icon badges. These can be configured in Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: ReferenceColors.disabled,
                      height: 1.35,
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: ReferenceColors.border),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Don’t Allow',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ReferenceColors.disabled,
                                fontSize: 19,
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, color: ReferenceColors.border),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Allow',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF25B1E7),
                                fontSize: 19,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 44),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: ReferenceColors.blueBorder,
                size: 48,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
