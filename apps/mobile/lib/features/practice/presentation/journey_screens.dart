import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/design/character_motion.dart';

import '../../../core/design/duo_motion.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/journey_controller.dart';
import '../data/journey_repository.dart';
import '../domain/journey_models.dart';
import 'story_library.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/presentation/timer_boost_screen.dart';

const _mom = ArtRegion('story-portrait', Rect.fromLTWH(48, 410, 125, 156));
const _melissa = ArtRegion('story-portrait', Rect.fromLTWH(48, 652, 125, 166));
const _radioHost = ArtRegion('radio-host', Rect.fromLTWH(200, 670, 770, 824));
const _restaurant = ArtRegion(
  'roleplay-scene',
  Rect.fromLTWH(0, 1005, 1180, 1170),
);
const _storyDuo = ArtRegion(
  'story-complete',
  Rect.fromLTWH(348, 755, 520, 605),
);

void _close(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/practice');

class JourneyEntryScreen extends ConsumerWidget {
  const JourneyEntryScreen({required this.kind, super.key});
  final String kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journeyControllerProvider(kind));
    final title = switch (kind) {
      'story' => ref.read(journeyControllerProvider(kind).notifier).story.title,
      'radio' => 'Living in the Shadows',
      'roleplay' => 'Dine at a Restaurant',
      _ => 'A Big Family',
    };
    final resumed = state.started && !state.complete;
    final color = kind == 'roleplay'
        ? LearningColors.green
        : LearningColors.red;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LearningHeader(
              title: titleFor(kind),
              onClose: () => _close(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 26),
                    if (kind == 'radio')
                      const ReferenceArt(_radioHost, width: 255, height: 273)
                    else if (kind == 'roleplay')
                      const ReferenceArt(_restaurant, width: 320, height: 317)
                    else if (kind == 'story' && state.storyId != 'family')
                      ReferenceArt(
                        storyCovers[state.storyId]!,
                        width: 180,
                        height: 192,
                      )
                    else
                      const ReferenceArt(_storyDuo, width: 165, height: 192),
                    const SizedBox(height: 28),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: headingStyle.copyWith(fontSize: 27),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      switch (kind) {
                        'radio' => 'Listen and check your understanding.',
                        'roleplay' =>
                          'Practice ordering food and drinks with Lily.',
                        _ => 'Read a conversation and build your English vocabulary.',
                      },
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 19, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    LearningCard(
                      child: Text(
                        kind == 'roleplay'
                            ? 'Text conversation preview. Voice and AI are simulated.'
                            : 'English preview with Vietnamese support. Recorded audio is unavailable; use the transcript.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: ReferenceButton(
                label: resumed ? 'RESUME' : 'START',
                backgroundColor: color,
                edgeColor: kind == 'roleplay'
                    ? LearningColors.greenDark
                    : LearningColors.redDark,
                onPressed: () {
                  if (!resumed) {
                    ref.read(journeyControllerProvider(kind).notifier).start();
                  }
                  context.push('/journeys/$kind/session');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({
    required this.kind,
    this.clockEnabled = const bool.fromEnvironment(
      'ENABLE_PREVIEW_CLOCK',
      defaultValue: true,
    ),
    super.key,
  });
  final String kind;
  final bool clockEnabled;
  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool translation = false;
  bool foreground = true;
  int lastSecond = 0;
  late final Ticker clock;
  String get kind => widget.kind;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clock = createTicker((elapsed) {
      final seconds = elapsed.inSeconds;
      if (seconds > lastSecond) {
        final delta = seconds - lastSecond;
        lastSecond = seconds;
        ref.read(journeyControllerProvider(kind).notifier).tick(delta);
      }
    });
  }

  void syncClock() {
    final state = ref.read(journeyControllerProvider(kind));
    final active =
        widget.clockEnabled &&
        kind == 'rapid' &&
        state.started &&
        !state.complete &&
        !state.expired &&
        foreground &&
        TickerMode.valuesOf(context).enabled;
    if (active && !clock.isActive) {
      lastSecond = 0;
      clock.start();
    } else if (!active && clock.isActive) {
      clock.stop();
      lastSecond = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    syncClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clock.dispose();
    super.dispose();
  }

  Future<void> exit() async {
    final leave = await learningSheet<bool>(
      context,
      title: 'End this lesson?',
      child: Column(
        children: [
          ReferenceButton(
            label: 'KEEP LEARNING',
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('END LESSON'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) _close(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journeyControllerProvider(kind));
    final vm = ref.read(journeyControllerProvider(kind).notifier);
    ref.listen(journeyControllerProvider(kind), (_, _) => syncClock());
    syncClock();
    if (!state.started) return JourneyEntryScreen(kind: kind);
    if (state.complete) return _JourneyComplete(kind: kind, state: state);
    if (state.expired) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.timer_off_outlined,
                  size: 80,
                  color: LearningColors.purple,
                ),
                const SizedBox(height: 24),
                const Text('Time’s up!', style: headingStyle),
                const SizedBox(height: 24),
                ReferenceButton(
                  label: ref.watch(previewControllerProvider).timerBoosts > 0
                      ? 'USE TIMER BOOST +60s'
                      : 'GET TIMER BOOSTS',
                  backgroundColor: ReferenceColors.purple,
                  edgeColor: const Color(0xFF794ACD),
                  onPressed: () {
                    if (!ref.read(journeyControllerProvider(kind)).expired) {
                      return;
                    }
                    if (ref.read(previewControllerProvider).timerBoosts > 0) {
                      vm.useTimerBoost();
                    } else {
                      showTimerBoostOffer(context, ref, challenge: true);
                    }
                  },
                ),
                const SizedBox(height: 12),
                ReferenceButton(label: 'TRY AGAIN', onPressed: vm.start),
                TextButton(
                  onPressed: () => _close(context),
                  child: const Text('NOT NOW'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (kind == 'legendary' && state.step == 2 && !state.milestoneSeen) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Row(
                children: [
                  ReferenceArt(
                    ArtRegion(
                      'legendary-milestone',
                      Rect.fromLTWH(0, 1100, 530, 430),
                    ),
                    width: 170,
                    height: 138,
                  ),
                  Expanded(
                    child: SpeechBubble(
                      child: Text(
                        'Nice job! Here’s 20 XP for your hard work so far.',
                        style: TextStyle(fontSize: 21),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ReferenceButton(
                  label: 'CONTINUE',
                  backgroundColor: LearningColors.yellow,
                  edgeColor: LearningColors.orange,
                  foregroundColor: const Color(0xFF945000),
                  onPressed: vm.dismissMilestone,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final q = vm.question!;
    final roleplay = kind == 'roleplay';
    final color = roleplay
        ? const Color(0xFF2ACCB8)
        : kind == 'legendary'
        ? LearningColors.yellow
        : kind == 'rapid'
        ? LearningColors.purple
        : LearningColors.green;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Exit ${titleFor(kind).toLowerCase()}',
                    onPressed: exit,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: ReferenceColors.disabled,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      value:
                          (state.step + .25) /
                          (roleplay ? 3 : vm.questions.length),
                      color: color,
                      backgroundColor: ReferenceColors.border,
                      minHeight: 16,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    roleplay
                        ? 'MAX'
                        : kind == 'rapid'
                        ? '${state.remaining ~/ 60}:${(state.remaining % 60).toString().padLeft(2, '0')}'
                        : '25',
                    style: TextStyle(
                      color: roleplay
                          ? const Color(0xFF20BFAA)
                          : LearningColors.purple,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: roleplay ? _roleplay(state) : _question(q, state, vm),
              ),
            ),
            if (roleplay)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('reply-${state.step}'),
                        initialValue: state.draft,
                        onChanged: vm.edit,
                        onFieldSubmitted: (_) => _send(vm),
                        maxLength: 500,
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Respond in English…',
                          errorText: state.error,
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Send reply',
                      style: IconButton.styleFrom(
                        backgroundColor: LearningColors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(52, 52),
                      ),
                      onPressed: () => _send(vm),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              )
            else
              Container(
                color: state.feedback == null
                    ? null
                    : state.feedback!
                    ? LearningColors.correct
                    : LearningColors.incorrect,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.feedback != null) ...[
                      Text(
                        state.feedback! ? 'Excellent!' : 'Keep practicing!',
                        style: headingStyle.copyWith(
                          color: state.feedback!
                              ? LearningColors.greenDark
                              : LearningColors.redDark,
                        ),
                      ),
                      if (!state.feedback!)
                        Text(
                          q.kind == JourneyKind.pairs
                              ? 'Match an English word with its Vietnamese meaning.'
                              : 'Correct answer: ${q.answer.join(' ')}',
                          style: const TextStyle(fontSize: 17),
                        ),
                      const SizedBox(height: 12),
                    ],
                    ReferenceButton(
                      label: state.feedback != null
                          ? 'CONTINUE'
                          : q.kind == JourneyKind.reading
                          ? 'CONTINUE'
                          : 'CHECK',
                      backgroundColor: state.feedback == false
                          ? LearningColors.red
                          : kind == 'legendary'
                          ? LearningColors.yellow
                          : null,
                      edgeColor: state.feedback == false
                          ? LearningColors.redDark
                          : kind == 'legendary'
                          ? LearningColors.orange
                          : null,
                      foregroundColor: kind == 'legendary'
                          ? const Color(0xFF945000)
                          : null,
                      onPressed: state.feedback != null
                          ? vm.next
                          : q.kind == JourneyKind.reading
                          ? vm.continueReading
                          : vm.canCheck
                          ? vm.check
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _send(JourneyController vm) {
    vm.send();
    if (ref.read(journeyControllerProvider(kind)).error == null) {
      setState(() => translation = false);
    }
  }

  Widget _question(
    JourneyQuestion q,
    JourneyState state,
    JourneyController vm,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kind == 'radio')
          const Center(
            child: ReferenceArt(_radioHost, width: 235, height: 251),
          ),
        if (q.kind == JourneyKind.reading) ...[
          Text(
            q.prompt,
            textAlign: TextAlign.center,
            style: headingStyle.copyWith(fontSize: 27),
          ),
          const SizedBox(height: 25),
          for (final line in q.transcript.split('\n')) ...[
            _dialogue(line, mother: line.startsWith('Mom')),
            const SizedBox(height: 18),
          ],
          TextButton(
            onPressed: () => setState(() => translation = !translation),
            child: const Text('TRANSLATE'),
          ),
          if (translation)
            Text(
              q.translation,
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
        ] else ...[
          if ((kind == 'rapid' || kind == 'legendary') &&
              q.transcript.isNotEmpty) ...[
            Row(
              children: [
                CharacterMotion(
                  character: q.kind == JourneyKind.bank
                      ? LessonCharacter.junior
                      : LessonCharacter.oscar,
                  width: 135,
                  height: 180,
                  epoch: state.step.toString(),
                  reaction: state.feedback == null
                      ? CharacterReaction.reset
                      : state.feedback!
                      ? CharacterReaction.correct
                      : CharacterReaction.incorrect,
                  fallback: ReferenceArt(
                    ArtRegion(
                      q.kind == JourneyKind.bank
                          ? 'legendary-character'
                          : 'rapid-character',
                      q.kind == JourneyKind.bank
                          ? const Rect.fromLTWH(60, 500, 320, 440)
                          : const Rect.fromLTWH(60, 460, 380, 478),
                    ),
                    width: 110,
                    height: 149,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SpeechBubble(
                    child: Text(
                      q.transcript,
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
          ] else if (q.transcript.isNotEmpty) ...[
            _dialogue(q.transcript),
            const SizedBox(height: 28),
          ],
          Text(q.prompt, style: headingStyle),
          const SizedBox(height: 28),
          if (q.kind == JourneyKind.bank) ...[
            LearningCard(
              child: Text(
                state.selected.isEmpty
                    ? '________________'
                    : state.selected.join(' '),
                style: const TextStyle(fontSize: 21),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (q.kind == JourneyKind.pairs)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < 2; col++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: col == 0 ? 8 : 0,
                        left: col == 1 ? 8 : 0,
                      ),
                      child: Column(
                        children: [
                          for (final value in q.options.sublist(
                            col * 3,
                            col * 3 + 3,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _option(value, state, vm),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          else if (q.kind == JourneyKind.word ||
              q.kind == JourneyKind.bank ||
              q.kind == JourneyKind.multi)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 16,
              children: [
                for (final value in q.options) _option(value, state, vm),
              ],
            )
          else if (q.options.length == 2 && q.options.first == 'True')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                children: [
                  for (final value in q.options) ...[
                    if (value == 'False') const SizedBox(width: 20),
                    Expanded(
                      child: LearningCard(
                        selected: state.selected.contains(value),
                        correct: state.feedback,
                        onTap: state.feedback == null
                            ? () => vm.select(value)
                            : null,
                        child: Icon(
                          value == 'True'
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          size: 80,
                          color: LearningColors.blue,
                          semanticLabel: value,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            for (final value in q.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _option(value, state, vm),
              ),
        ],
      ],
    );
  }

  Widget _option(String value, JourneyState state, JourneyController vm) =>
      LearningCard(
        selected:
            state.selected.contains(value) || state.matched.contains(value),
        correct: state.matched.contains(value) ? true : state.feedback,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        onTap: state.feedback == null && !state.matched.contains(value)
            ? () => vm.select(value)
            : null,
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      );
  Widget _dialogue(String text, {bool mother = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (kind == 'story' &&
          ref.read(journeyControllerProvider(kind)).storyId == 'family') ...[
        ReferenceArt(mother ? _mom : _melissa, width: 42, height: 54),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: SpeechBubble(
          child: Text(text, style: const TextStyle(fontSize: 21, height: 1.5)),
        ),
      ),
    ],
  );
  Widget _roleplay(JourneyState state) => Column(
    children: [
      const SizedBox(height: 16),
      SpeechBubble(
        below: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              englishRoleplay[state.step].$1,
              style: const TextStyle(fontSize: 21, height: 1.5),
            ),
            TextButton(
              onPressed: () => setState(() => translation = !translation),
              child: const Text('TRANSLATE'),
            ),
            if (translation)
              Text(
                englishRoleplay[state.step].$2,
                style: const TextStyle(fontSize: 17),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const ReferenceArt(_restaurant, width: 335, height: 332),
      if (state.replies.isNotEmpty) ...[
        const SizedBox(height: 12),
        LearningCard(
          child: Text(state.replies.last, style: const TextStyle(fontSize: 18)),
        ),
      ],
    ],
  );
}

class _JourneyComplete extends StatelessWidget {
  const _JourneyComplete({required this.kind, required this.state});
  final String kind;
  final JourneyState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              child: Column(
                children: [
                  if (kind == 'rapid')
                    const ReferenceArt(
                      ArtRegion(
                        'rapid-complete',
                        Rect.fromLTWH(360, 650, 450, 800),
                      ),
                      width: 155,
                      height: 275,
                    )
                  else if (kind == 'legendary')
                    const ReferenceArt(
                      ArtRegion(
                        'legendary-complete',
                        Rect.fromLTWH(170, 600, 820, 585),
                      ),
                      width: 270,
                      height: 193,
                    )
                  else
                    DuoMotion(
                      pose: DuoPose.celebrate,
                      width: 180,
                      height: 185,
                      viewport: const Rect.fromLTWH(260, 542, 408, 415),
                      fallback: const ReferenceArt(
                        _storyDuo,
                        width: 180,
                        height: 185,
                      ),
                    ),
                  const SizedBox(height: 32),
                  Text(
                    kind == 'legendary'
                        ? 'High scorer!'
                        : '${titleFor(kind)} complete!',
                    textAlign: TextAlign.center,
                    style: headingStyle.copyWith(
                      fontSize: 30,
                      color: LearningColors.yellow,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (kind == 'rapid')
                    const Text(
                      'You earned 20 XP and another star! Can you keep going for the next one?',
                      textAlign: TextAlign.center,
                      style: headingStyle,
                    )
                  else if (kind == 'roleplay')
                    TextButton(
                      onPressed: () =>
                          context.push('/journeys/roleplay/feedback'),
                      child: const Text('REVIEW FEEDBACK'),
                    )
                  else
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ResultCard(
                          'TOTAL XP',
                          kind == 'legendary' ? '40' : '5',
                          LearningColors.yellow,
                        ),
                        _ResultCard(
                          'ACCURACY',
                          '${state.attempted == 0 ? 0 : (state.correct / state.attempted * 100).round()}%',
                          LearningColors.green,
                        ),
                        _ResultCard(
                          'WORDS',
                          kind == 'story' ? '5' : '3',
                          LearningColors.blue,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
            child: ReferenceButton(
              label: kind == 'roleplay' || kind == 'rapid'
                  ? 'CONTINUE'
                  : 'CLAIM XP',
              backgroundColor: LearningColors.blue,
              edgeColor: LearningColors.blueDark,
              onPressed: () =>
                  context.go(kind == 'story' ? '/stories' : '/practice'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 103,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.all(3),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(7),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class RoleplayFeedbackScreen extends ConsumerStatefulWidget {
  const RoleplayFeedbackScreen({super.key});
  @override
  ConsumerState<RoleplayFeedbackScreen> createState() => _FeedbackState();
}

class _FeedbackState extends ConsumerState<RoleplayFeedbackScreen> {
  final Map<int, bool> helpful = {};
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journeyControllerProvider('roleplay'));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LearningHeader(
              title: 'Roleplay feedback',
              onClose: () => _close(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Review your\nRoleplay feedback',
                    textAlign: TextAlign.center,
                    style: headingStyle.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'KEY TAKEAWAY',
                    style: TextStyle(
                      color: Color(0xFF29C6B4),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Use “please” to make an English request polite.',
                    style: TextStyle(fontSize: 21, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  const LearningCard(
                    child: Text(
                      'A drink, please.\nWater, please.',
                      style: TextStyle(fontSize: 21, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 26),
                  for (var i = 0; i < state.replies.length; i++) ...[
                    SpeechBubble(
                      child: Text(
                        englishRoleplay[i].$1,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LearningCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR REPLY',
                            style: TextStyle(
                              color: LearningColors.greenDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.replies[i],
                            style: const TextStyle(fontSize: 21),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Example: Yes, please. Thank you!',
                            style: TextStyle(fontSize: 17),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Helpful feedback ${i + 1}',
                                color: helpful[i] == true
                                    ? LearningColors.greenDark
                                    : null,
                                onPressed: () =>
                                    setState(() => helpful[i] = true),
                                icon: const Icon(Icons.thumb_up_outlined),
                              ),
                              IconButton(
                                tooltip: 'Unhelpful feedback ${i + 1}',
                                color: helpful[i] == false
                                    ? LearningColors.red
                                    : null,
                                onPressed: () =>
                                    setState(() => helpful[i] = false),
                                icon: const Icon(Icons.thumb_down_outlined),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: ReferenceButton(
                label: 'CONTINUE',
                backgroundColor: LearningColors.blue,
                edgeColor: LearningColors.blueDark,
                onPressed: () => context.go('/practice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
