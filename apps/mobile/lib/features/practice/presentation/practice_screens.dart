import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/data/learning_repository.dart';
import '../../learning/domain/learning_models.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/practice_controller.dart';
import '../domain/practice_models.dart';
import 'words_screen.dart';

const _callLily = ArtRegion('call-04', Rect.fromLTWH(0, 300, 1180, 1800));

void _closeToPractice(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/practice');
  }
}

Future<void> _startTextSubstitute(
  BuildContext context,
  WidgetRef ref,
  List<Exercise> exercises,
) async {
  final controller = ref.read(lessonControllerProvider.notifier);
  await controller.start(
    nodeId: 'practice-preview',
    guest: true,
    exercises: exercises,
  );
  controller.substituteMedia();
  if (context.mounted) context.push('/lesson/practice');
}

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ReferenceColors.surface,
    body: SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 375),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8558E8), Color(0xFF5D35B5)],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Video Call',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _MaxLogo(),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Center(
                        child: ClipOval(
                          child: ReferenceArt(
                            LearningArt.lily,
                            width: 145,
                            height: 137,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Center(child: _LilyNamePill()),
                      const SizedBox(height: 18),
                      ReferenceButton(
                        label: 'CALL LILY',
                        backgroundColor: Colors.white,
                        edgeColor: const Color(0xFF45248F),
                        foregroundColor: const Color(0xFF5D35B5),
                        onPressed: () => context.push('/speaking/call'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Skill practice',
                        style: TextStyle(
                          color: ReferenceColors.ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PracticeRow(
                        title: 'Roleplay',
                        art: LearningArt.roleplay,
                        onTap: () => context.push('/journeys/roleplay'),
                      ),
                      _PracticeRow(
                        title: 'Mistakes',
                        art: LearningArt.mistakes,
                        onTap: () => context.push('/practice/mistakes'),
                      ),
                      _PracticeRow(
                        title: 'Words',
                        art: LearningArt.words,
                        onTap: () => context.push('/practice/words'),
                      ),
                      _PracticeRow(
                        title: 'Listen',
                        art: LearningArt.listen,
                        onTap: () => context.push('/practice/listen'),
                      ),
                      _PracticeRow(
                        title: 'Speak',
                        art: LearningArt.speak,
                        onTap: () => context.push('/practice/speak'),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'English stories and radio',
                        style: headingStyle,
                      ),
                      const SizedBox(height: 16),
                      _PracticeRow(
                        title: 'Stories',
                        art: LearningArt.words,
                        onTap: () => context.push('/stories'),
                      ),
                      _PracticeRow(
                        title: 'Radio',
                        art: LearningArt.listen,
                        onTap: () => context.push('/journeys/radio'),
                      ),
                      _PracticeRow(
                        title: 'Rapid Review',
                        art: LearningArt.speak,
                        onTap: () => context.push('/challenges/rapid'),
                      ),
                      _PracticeRow(
                        title: 'Legendary',
                        art: LearningArt.league,
                        onTap: () => context.push('/challenges/legendary'),
                      ),
                      _PracticeRow(
                        title: 'Adventures',
                        art: LearningArt.roleplay,
                        onTap: () => context.push('/adventures/passport'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MaxLogo extends StatelessWidget {
  const _MaxLogo();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF201431),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'MAX',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
      ),
    ),
  );
}

class _LilyNamePill extends StatelessWidget {
  const _LilyNamePill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF432780),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Text(
      'Lily',
      style: TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({
    required this.title,
    required this.art,
    required this.onTap,
  });

  final String title;
  final ArtRegion art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LearningCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 1, 8, 1),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: headingStyle.copyWith(fontSize: 23)),
          ),
          ReferenceArt(art, width: 66, height: 62),
        ],
      ),
    ),
  );
}

class PracticeDetailScreen extends ConsumerWidget {
  const PracticeDetailScreen({required this.kind, super.key});

  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kind == 'words') return const WordsScreen();
    final title = switch (kind) {
      'mistakes' => 'Mistakes',
      'listen' => 'Listening practice',
      'speak' => 'Speaking practice',
      _ => 'Words',
    };
    return Scaffold(
      backgroundColor: ReferenceColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            LearningHeader(
              title: title,
              onClose: () => _closeToPractice(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: switch (kind) {
                      'mistakes' => _MistakesPractice(ref: ref),
                      'listen' => _MediaPractice(kind: kind, ref: ref),
                      'speak' => _MediaPractice(kind: kind, ref: ref),
                      _ => const _WordPractice(),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordPractice extends ConsumerWidget {
  const _WordPractice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceControllerProvider);
    final controller = ref.read(practiceControllerProvider.notifier);
    final word = state.current;
    if (word == null) return const Text('No saved words yet.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${state.recalledIds.length} recalled',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ReferenceColors.blue,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        LearningCard(
          child: Semantics(
            liveRegion: true,
            child: SizedBox(
              height: 210,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(word.term, style: headingStyle.copyWith(fontSize: 32)),
                    if (state.revealed) ...[
                      const SizedBox(height: 18),
                      Text(
                        word.meaning,
                        style: const TextStyle(
                          color: ReferenceColors.muted,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Assisted reveal',
                        style: TextStyle(color: ReferenceColors.disabled),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (!state.revealed)
          ReferenceButton(
            label: 'REVEAL ANSWER',
            backgroundColor: LearningColors.blue,
            edgeColor: LearningColors.blueDark,
            onPressed: controller.reveal,
          )
        else ...[
          ReferenceButton(
            label: 'I REMEMBER THIS',
            onPressed: controller.remember,
          ),
          const SizedBox(height: 12),
          ReferenceButton(
            label: 'PRACTICE AGAIN',
            outlined: true,
            foregroundColor: ReferenceColors.blue,
            onPressed: controller.practiceAgain,
          ),
        ],
      ],
    );
  }
}

class _MistakesPractice extends StatelessWidget {
  const _MistakesPractice({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final mistakes = ref.watch(lessonControllerProvider).pendingMistakes;
    if (mistakes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ReferenceArt(LearningArt.mistakes, width: 132, height: 132),
          const SizedBox(height: 18),
          const Text(
            'No mistakes to review',
            textAlign: TextAlign.center,
            style: headingStyle,
          ),
          const SizedBox(height: 8),
          const Text(
            'Missed lesson questions will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ReferenceColors.muted, fontSize: 17),
          ),
          const SizedBox(height: 24),
          ReferenceButton(
            label: 'PRACTICE WORDS',
            outlined: true,
            foregroundColor: ReferenceColors.blue,
            onPressed: () => context.go('/practice/words'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${mistakes.length} question${mistakes.length == 1 ? '' : 's'} ready',
          style: headingStyle,
        ),
        const SizedBox(height: 14),
        for (final mistake in mistakes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LearningCard(
              child: Text(mistake.prompt, style: const TextStyle(fontSize: 17)),
            ),
          ),
        const SizedBox(height: 12),
        ReferenceButton(
          label: 'REVIEW MISTAKES',
          onPressed: () async {
            await ref
                .read(lessonControllerProvider.notifier)
                .start(
                  nodeId: 'mistake-practice',
                  guest: true,
                  exercises: mistakes,
                );
            if (context.mounted) context.push('/lesson/practice');
          },
        ),
      ],
    );
  }
}

class _MediaPractice extends StatelessWidget {
  const _MediaPractice({required this.kind, required this.ref});

  final String kind;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final speaking = kind == 'speak';
    final exercises = mockPracticeExercises
        .where(
          (exercise) => speaking
              ? exercise.kind == ExerciseKind.speakRepeat
              : exercise.kind == ExerciseKind.dictation,
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReferenceArt(
          speaking ? LearningArt.speak : LearningArt.listen,
          width: 150,
          height: 142,
        ),
        const SizedBox(height: 20),
        Text(
          speaking ? 'Speech capture is simulated' : 'Audio is unavailable',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 10),
        Text(
          speaking
              ? 'This preview does not access your microphone or score pronunciation.'
              : 'This preview has no audible media. Continue with the same prompt as typed text.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ReferenceColors.muted,
            fontSize: 17,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 26),
        ReferenceButton(
          label: 'USE TEXT SUBSTITUTE',
          backgroundColor: LearningColors.blue,
          edgeColor: LearningColors.blueDark,
          onPressed: () => _startTextSubstitute(context, ref, exercises),
        ),
        if (speaking) ...[
          const SizedBox(height: 12),
          ReferenceButton(
            label: 'OPEN SPEAKING PREVIEW',
            outlined: true,
            foregroundColor: ReferenceColors.blue,
            onPressed: () => context.push('/speaking/record'),
          ),
        ],
      ],
    );
  }
}

class SpeakingRecordScreen extends ConsumerStatefulWidget {
  const SpeakingRecordScreen({super.key});

  @override
  ConsumerState<SpeakingRecordScreen> createState() =>
      _SpeakingRecordScreenState();
}

class _SpeakingRecordScreenState extends ConsumerState<SpeakingRecordScreen>
    with WidgetsBindingObserver {
  late final SpeakingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(speakingControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.resumeRecordingAfterLifecycle();
      return;
    }
    if ({
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    }.contains(state)) {
      _controller.pauseRecordingForLifecycle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.cancelPending();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(speakingControllerProvider);
    final controller = ref.read(speakingControllerProvider.notifier);
    return Scaffold(
      backgroundColor: ReferenceColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            LearningHeader(
              title: 'Speaking preview',
              onClose: () => _closeToPractice(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ReferenceArt(
                          LearningArt.lily,
                          width: 168,
                          height: 158,
                        ),
                        const SizedBox(height: 18),
                        _CapabilityPanel(capability: state.capability),
                        const SizedBox(height: 22),
                        if (state.capability == SpeechCapability.ready)
                          ReferenceButton(
                            label: 'START MOCK RECORDING',
                            backgroundColor: LearningColors.blue,
                            edgeColor: LearningColors.blueDark,
                            onPressed: controller.startMockRecording,
                          ),
                        if (state.capability == SpeechCapability.capturing)
                          ReferenceButton(label: 'CAPTURING…'),
                        if (state.capability == SpeechCapability.unscored)
                          ReferenceButton(
                            label: 'CONTINUE TO CALL',
                            onPressed: () => context.push('/speaking/call'),
                          ),
                        if ({
                          SpeechCapability.permissionDenied,
                          SpeechCapability.unsupported,
                        }.contains(state.capability)) ...[
                          ReferenceButton(
                            label: 'USE TYPED PRACTICE',
                            backgroundColor: LearningColors.blue,
                            edgeColor: LearningColors.blueDark,
                            onPressed: () => _startTextSubstitute(
                              context,
                              ref,
                              mockPracticeExercises,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ReferenceButton(
                            label: 'RESET PREVIEW',
                            outlined: true,
                            onPressed: controller.resetCapability,
                          ),
                        ],
                        const SizedBox(height: 26),
                        const Text(
                          'CAPABILITY SIMULATION',
                          style: sectionStyle,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('SIMULATE DENIED'),
                              onPressed: controller.showPermissionDenied,
                            ),
                            ActionChip(
                              label: const Text('SIMULATE UNSUPPORTED'),
                              onPressed: controller.showUnsupported,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityPanel extends StatelessWidget {
  const _CapabilityPanel({required this.capability});

  final SpeechCapability capability;

  @override
  Widget build(BuildContext context) {
    final (title, detail, icon) = switch (capability) {
      SpeechCapability.permissionDenied => (
        'Microphone permission denied',
        'No microphone was accessed. Use typed practice or reset this simulation.',
        Icons.mic_off_rounded,
      ),
      SpeechCapability.unsupported => (
        'Speech capture unsupported',
        'This preview can continue with typed input.',
        Icons.portable_wifi_off_rounded,
      ),
      SpeechCapability.capturing => (
        'Capturing mock speech…',
        'No audio is being recorded or uploaded.',
        Icons.graphic_eq_rounded,
      ),
      SpeechCapability.unscored => (
        'Mock capture complete',
        'Pronunciation is unscored because no recorded media exists.',
        Icons.check_circle_outline_rounded,
      ),
      SpeechCapability.ready => (
        'Try a speaking prompt',
        'Deterministic preview only. It does not request microphone permission.',
        Icons.mic_none_rounded,
      ),
    };
    return LearningCard(
      child: Column(
        children: [
          Icon(icon, size: 42, color: ReferenceColors.blue),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: headingStyle),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReferenceColors.muted,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class SpeakingCallScreen extends ConsumerStatefulWidget {
  const SpeakingCallScreen({super.key});

  @override
  ConsumerState<SpeakingCallScreen> createState() => _SpeakingCallScreenState();
}

class _SpeakingCallScreenState extends ConsumerState<SpeakingCallScreen>
    with WidgetsBindingObserver {
  final _replyController = TextEditingController();
  late final SpeakingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(speakingControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.resumeCallAfterLifecycle();
      return;
    }
    if ({
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    }.contains(state)) {
      _controller.pauseCallForLifecycle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _replyController.dispose();
    _controller.cancelPending();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(speakingControllerProvider);
    final controller = ref.read(speakingControllerProvider.notifier);
    final active = state.callStage == CallStage.responding;
    return Scaffold(
      backgroundColor: const Color(0xFF11191F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => _closeToPractice(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Call with Lily',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    child: ReferenceArt(_callLily, width: 520, height: 310),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Static reference illustration · no lip-sync',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFB8C4CC), fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  if (state.callStage == CallStage.idle)
                    ReferenceButton(
                      label: 'START MOCK CALL',
                      backgroundColor: LearningColors.blue,
                      edgeColor: LearningColors.blueDark,
                      onPressed: controller.startCall,
                    )
                  else ...[
                    Text(
                      switch (state.callStage) {
                        CallStage.connecting => 'Connecting…',
                        CallStage.reconnecting => 'Reconnecting…',
                        CallStage.ended => 'Call ended',
                        _ => 'Lily is waiting for your typed reply',
                      },
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final line in state.transcript)
                      _TranscriptBubble(line: line),
                    if (active) ...[
                      TextField(
                        controller: _replyController,
                        enabled: active,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Type your reply',
                          labelStyle: TextStyle(color: Color(0xFFB8C4CC)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF49616B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: LearningColors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ReferenceButton(
                        label: 'SEND TYPED REPLY',
                        backgroundColor: LearningColors.blue,
                        edgeColor: LearningColors.blueDark,
                        onPressed: () {
                          controller.sendTypedReply(_replyController.text);
                          _replyController.clear();
                        },
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: controller.reconnect,
                        child: const Text('SIMULATE RECONNECT'),
                      ),
                    ],
                    if (state.callStage != CallStage.ended) ...[
                      const SizedBox(height: 10),
                      ReferenceButton(
                        label: 'END CALL',
                        backgroundColor: LearningColors.red,
                        edgeColor: LearningColors.redDark,
                        onPressed: () {
                          controller.endCall();
                          context.go('/speaking/result/demo');
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({required this.line});

  final ConversationLine line;

  @override
  Widget build(BuildContext context) {
    final lily = line.speaker == 'Lily';
    return Align(
      alignment: lily ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: lily ? const Color(0xFF203E47) : const Color(0xFF176C7A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '${line.speaker}: ${line.text}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

class SpeakingResultScreen extends ConsumerWidget {
  const SpeakingResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcript = ref.watch(speakingControllerProvider).transcript;
    return Scaffold(
      backgroundColor: const Color(0xFF11191F),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF39D9E8),
                    size: 58,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Conversation complete',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unscored mock session · no recorded media',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFB8C4CC), fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'TRANSCRIPT',
                    style: TextStyle(
                      color: Color(0xFFB8C4CC),
                      fontWeight: FontWeight.w700,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (transcript.isEmpty)
                    const Text(
                      'No typed conversation was saved.',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    )
                  else
                    for (final line in transcript)
                      _TranscriptBubble(line: line),
                  const SizedBox(height: 24),
                  ReferenceButton(
                    label: 'DONE',
                    backgroundColor: LearningColors.blue,
                    edgeColor: LearningColors.blueDark,
                    onPressed: () => context.go('/practice'),
                  ),
                  const SizedBox(height: 12),
                  ReferenceButton(
                    label: 'TRY AGAIN',
                    outlined: true,
                    foregroundColor: const Color(0xFF39D9E8),
                    onPressed: () {
                      ref
                          .read(speakingControllerProvider.notifier)
                          .resetCapability();
                      context.go('/speaking/record');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
