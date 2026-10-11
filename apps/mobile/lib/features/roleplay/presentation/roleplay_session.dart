import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../practice/application/journey_controller.dart';
import '../domain/roleplay_models.dart';
import 'roleplay_widgets.dart';

const _kind = 'roleplay';

/// The roleplay session for a scenario picked in the library. Hosted by the
/// existing `/journeys/roleplay/session` JourneyScreen and driven by the same
/// JourneyController; the scenario supplies dialogue, scene and copy.
class RoleplaySessionView extends ConsumerStatefulWidget {
  const RoleplaySessionView({required this.onExit, super.key});
  final VoidCallback onExit;
  @override
  ConsumerState<RoleplaySessionView> createState() => _SessionState();
}

class _SessionState extends ConsumerState<RoleplaySessionView> {
  bool translation = false;
  int epoch = 0;

  void _send(JourneyController vm) {
    vm.send();
    if (ref.read(journeyControllerProvider(_kind)).error == null) {
      setState(() {
        translation = false;
        epoch++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journeyControllerProvider(_kind));
    final vm = ref.read(journeyControllerProvider(_kind).notifier);
    final scenario = vm.scenario;
    final lines = vm.roleplayLines;
    if (state.complete) return _WellDone(scenario: scenario);
    final line = lines[state.step.clamp(0, lines.length - 1)];
    final intro = !state.introSeen;
    final restaurant = scenario.scene == RoleplayScene.restaurant;
    final width = MediaQuery.sizeOf(context).width;
    final sceneHeight = width * (restaurant ? 1170 : 1060) / 1180;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _SessionHeader(
              progress: (state.step + .25) / lines.length,
              onExit: widget.onExit,
            ),
            Expanded(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: restaurant ? 60 : 116,
                    child: ReferenceArt(
                      RoleplayArt.scene(scenario.scene),
                      width: width,
                      height: sceneHeight,
                    ),
                  ),
                  if (!intro)
                    Positioned(
                      left: restaurant ? 16 : 64,
                      right: restaurant ? 16 : 64,
                      top: restaurant ? 30 : 108,
                      child: _PromptBubble(
                        line: line,
                        translation: translation,
                        onTranslate: () =>
                            setState(() => translation = !translation),
                      ),
                    ),
                  if (intro)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: RoleplaySheetCard(
                        title: scenario.title,
                        body: scenario.setting,
                        onContinue: vm.dismissIntro,
                      ),
                    ),
                ],
              ),
            ),
            if (!intro) ...[
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: ReferenceColors.border, width: 2),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ReferenceColors.border, width: 2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('scenario-reply-${state.step}-$epoch'),
                          initialValue: state.draft,
                          onChanged: vm.edit,
                          onFieldSubmitted: (_) => _send(vm),
                          maxLength: 500,
                          maxLines: 3,
                          minLines: 1,
                          style: const TextStyle(fontSize: 18),
                          decoration: InputDecoration(
                            hintText: 'Respond in English…',
                            hintStyle: const TextStyle(
                              color: ReferenceColors.disabled,
                              fontSize: 18,
                            ),
                            errorText: state.error,
                            counterText: '',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Send reply',
                        style: IconButton.styleFrom(
                          backgroundColor: LearningColors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(46, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _send(vm),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              if (line.hints.isNotEmpty)
                RoleplayHintRow(
                  hints: line.hints,
                  onPick: (phrase) {
                    final draft = ref
                        .read(journeyControllerProvider(_kind))
                        .draft
                        .trim();
                    vm.edit(draft.isEmpty ? phrase : '$draft $phrase');
                    setState(() => epoch++);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.progress, required this.onExit});
  final double progress;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 16, 6),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Exit roleplay',
          onPressed: onExit,
          icon: const Icon(
            Icons.close_rounded,
            color: ReferenceColors.disabled,
            size: 34,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 16,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: ReferenceColors.border),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.05, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            RoleplayColors.maxCyan,
                            RoleplayColors.maxGreen,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        const MaxBadge(),
      ],
    ),
  );
}

class _PromptBubble extends StatelessWidget {
  const _PromptBubble({
    required this.line,
    required this.translation,
    required this.onTranslate,
  });
  final RoleplayLine line;
  final bool translation;
  final VoidCallback onTranslate;
  @override
  Widget build(BuildContext context) => SpeechBubble(
    below: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3, right: 8),
              child: Icon(
                Icons.volume_up_rounded,
                color: LearningColors.blue,
                size: 22,
              ),
            ),
            Expanded(
              child: Text(
                line.prompt,
                style: const TextStyle(
                  color: ReferenceColors.ink,
                  fontSize: 18,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTranslate,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.translate_rounded,
                color: LearningColors.blue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'TRANSLATE',
                style: TextStyle(
                  color: LearningColors.blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
        ),
        if (translation) ...[
          const SizedBox(height: 6),
          Text(
            line.translation,
            style: const TextStyle(fontSize: 15, color: ReferenceColors.muted),
          ),
        ],
      ],
    ),
  );
}

/// End of the scenario: zoomed character and the "Well done!" card.
class _WellDone extends StatelessWidget {
  const _WellDone({required this.scenario});
  final RoleplayScenario scenario;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ReferenceArt(
              RoleplayArt.closeUp(scenario.scene),
              width: size.width,
              height: size.width * 1.42,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: RoleplaySheetCard(
                title: 'Well done!',
                body: scenario.wellDone,
                onContinue: () => context.push('/journeys/roleplay/feedback'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feedback for a library scenario (refs Starting/17): takeaway, then each
/// prompt with the learner's reply and a coaching tip.
class RoleplayScenarioFeedback extends ConsumerStatefulWidget {
  const RoleplayScenarioFeedback({super.key});
  @override
  ConsumerState<RoleplayScenarioFeedback> createState() =>
      _ScenarioFeedbackState();
}

class _ScenarioFeedbackState extends ConsumerState<RoleplayScenarioFeedback> {
  final Map<int, bool> helpful = {};
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journeyControllerProvider(_kind));
    final vm = ref.read(journeyControllerProvider(_kind).notifier);
    final scenario = vm.scenario;
    final lines = vm.roleplayLines;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                children: [
                  const Text(
                    'Review your\nRoleplay feedback',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ReferenceColors.ink,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: LearningColors.green,
                        size: 28,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'WELL DONE!',
                        style: TextStyle(
                          color: LearningColors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: .6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    scenario.takeaway,
                    style: const TextStyle(
                      color: ReferenceColors.ink,
                      fontSize: 18,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Divider(
                    height: 2,
                    thickness: 2,
                    color: ReferenceColors.border,
                  ),
                  const SizedBox(height: 26),
                  for (var i = 0; i < state.replies.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ReferenceArt(
                          RoleplayArt.lilyAvatar,
                          width: 42,
                          height: 44,
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ReferenceColors.border,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              lines[i].prompt,
                              style: const TextStyle(
                                color: ReferenceColors.muted,
                                fontSize: 17,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: _ReplyCard(
                        index: i,
                        reply: state.replies[i],
                        tip: lines[i].tip,
                        helpful: helpful[i],
                        onRate: (v) => setState(() => helpful[i] = v),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: ReferenceColors.border, width: 2),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: ReferenceButton(
                label: 'CONTINUE',
                backgroundColor: LearningColors.blue,
                edgeColor: LearningColors.blueDark,
                onPressed: () => context.go('/roleplay/results'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.index,
    required this.reply,
    required this.tip,
    required this.helpful,
    required this.onRate,
  });
  final int index;
  final String reply, tip;
  final bool? helpful;
  final ValueChanged<bool> onRate;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ReferenceColors.border, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Great',
                    style: TextStyle(
                      color: LearningColors.greenDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.check_rounded,
                    color: LearningColors.greenDark,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                reply,
                style: const TextStyle(
                  color: ReferenceColors.ink,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        if (tip.isNotEmpty)
          Container(
            color: LearningColors.correct,
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip,
                  style: const TextStyle(
                    color: ReferenceColors.ink,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Unhelpful feedback ${index + 1}',
                      visualDensity: VisualDensity.compact,
                      color: helpful == false
                          ? LearningColors.red
                          : LearningColors.greenDark,
                      onPressed: () => onRate(false),
                      icon: const Icon(Icons.thumb_down_outlined),
                    ),
                    IconButton(
                      tooltip: 'Helpful feedback ${index + 1}',
                      visualDensity: VisualDensity.compact,
                      color: LearningColors.greenDark,
                      onPressed: () => onRate(true),
                      icon: Icon(
                        helpful == true
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
