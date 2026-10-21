import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/data/learning_repository.dart';
import '../../learning/data/speech_assessment.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/pronunciation_controller.dart';

class SpeakingRecordScreen extends ConsumerStatefulWidget {
  const SpeakingRecordScreen({super.key});

  @override
  ConsumerState<SpeakingRecordScreen> createState() =>
      _SpeakingRecordScreenState();
}

class _SpeakingRecordScreenState extends ConsumerState<SpeakingRecordScreen>
    with WidgetsBindingObserver {
  late PronunciationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(pronunciationControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // The OS microphone permission prompt can itself make iOS inactive.
    final requesting =
        ref.read(pronunciationControllerProvider).stage ==
        PronunciationStage.requesting;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden ||
        (lifecycle == AppLifecycleState.inactive && !requesting)) {
      _controller.interrupt();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.interrupt();
    super.dispose();
  }

  Future<void> _typedPractice() async {
    await _controller.interrupt();
    if (!mounted) return;
    final lesson = ref.read(lessonControllerProvider.notifier);
    await lesson.start(
      nodeId: 'practice-preview',
      guest: true,
      exercises: mockPracticeExercises,
    );
    lesson.substituteMedia();
    if (mounted) context.push('/lesson/practice');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pronunciationControllerProvider);
    _controller = ref.read(pronunciationControllerProvider.notifier);
    final verdict = state.verdict;
    final title = switch (state.stage) {
      PronunciationStage.requesting => 'Waiting for microphone permission…',
      PronunciationStage.recording => 'Listening…',
      PronunciationStage.assessing => 'Checking pronunciation…',
      PronunciationStage.stopping => 'Stopping recording…',
      PronunciationStage.unavailable => 'Pronunciation assessment unavailable',
      PronunciationStage.error => state.message!,
      PronunciationStage.result =>
        verdict!.scored
            ? 'Pronunciation feedback'
            : 'Pronunciation not assessed',
      PronunciationStage.ready => 'Read the sentence aloud',
    };
    return PopScope(
      onPopInvokedWithResult: (_, _) => _controller.interrupt(),
      child: Scaffold(
        backgroundColor: ReferenceColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              LearningHeader(
                title: 'Speaking',
                onClose: () {
                  _controller.interrupt();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/practice');
                  }
                },
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
                          Text(
                            'Sentence ${state.index + 1} of ${PronunciationState.sentences.length}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            state.reference,
                            textAlign: TextAlign.center,
                            style: headingStyle,
                          ),
                          const SizedBox(height: 22),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (state.stage == PronunciationStage.unavailable)
                            const Text(
                              'Use typed practice for this demo, or sign in to a configured speech service.',
                              textAlign: TextAlign.center,
                            )
                          else ...[
                            const Text(
                              'Tap to record up to 15 seconds. Your recording is sent to the speech service when you stop or the time limit is reached.',
                              textAlign: TextAlign.center,
                            ),
                            if (state.message != null &&
                                state.stage != PronunciationStage.error) ...[
                              const SizedBox(height: 10),
                              Text(state.message!, textAlign: TextAlign.center),
                            ],
                          ],
                          if (verdict != null) ...[
                            const SizedBox(height: 20),
                            _PronunciationFeedback(verdict: verdict),
                          ],
                          const SizedBox(height: 24),
                          if (state.stage == PronunciationStage.recording)
                            ReferenceButton(
                              label: 'STOP AND CHECK',
                              onPressed: _controller.stop,
                            )
                          else if (state.busy)
                            ReferenceButton(label: 'PLEASE WAIT…')
                          else if (state.stage !=
                              PronunciationStage.unavailable)
                            ReferenceButton(
                              label: verdict == null
                                  ? 'TAP TO SPEAK'
                                  : 'TRY AGAIN',
                              onPressed: _controller.start,
                            ),
                          if (verdict != null) ...[
                            const SizedBox(height: 12),
                            ReferenceButton(
                              label: 'NEXT SENTENCE',
                              outlined: true,
                              onPressed: _controller.next,
                            ),
                          ],
                          const SizedBox(height: 12),
                          ReferenceButton(
                            label: 'USE TYPED PRACTICE',
                            outlined: true,
                            onPressed: state.busy ? null : _typedPractice,
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
      ),
    );
  }
}

class _PronunciationFeedback extends StatelessWidget {
  const _PronunciationFeedback({required this.verdict});
  final SpeechVerdict verdict;

  @override
  Widget build(BuildContext context) => LearningCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (verdict.transcript.trim().isNotEmpty)
          Text(
            'Heard: ${verdict.transcript}',
            style: const TextStyle(fontSize: 18),
          ),
        if (verdict.scored) ...[
          for (final metric in [
            ('Accuracy', verdict.accuracy),
            ('Fluency', verdict.fluency),
            ('Completeness', verdict.completeness),
            ('Prosody', verdict.prosody),
          ])
            if (metric.$2 != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('${metric.$1}: ${metric.$2!.round()}/100'),
              ),
          const SizedBox(height: 14),
          for (final word in verdict.words) _WordFeedback(word: word),
        ] else ...[
          const SizedBox(height: 10),
          Text(
            verdict.transcript.trim().isEmpty
                ? 'No reliable speech result. Try again or use typed practice.'
                : 'Words recognized only. No pronunciation score is available. Try again or use typed practice.',
          ),
        ],
      ],
    ),
  );
}

class _WordFeedback extends StatelessWidget {
  const _WordFeedback({required this.word});
  final SpokenWord word;

  @override
  Widget build(BuildContext context) {
    final status = word.errorType == 'Omission'
        ? 'Not heard'
        : word.ok
        ? 'Good'
        : 'Try again';
    final title = Text(
      '${word.word}: $status${word.accuracy == null ? '' : ' (${word.accuracy!.round()}/100)'}',
      style: TextStyle(
        color: word.ok ? LearningColors.greenDark : LearningColors.redDark,
      ),
    );
    if (word.phonemes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: title,
      );
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: title,
      children: [
        for (final phoneme in word.phonemes)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '/${phoneme.symbol}/: ${phoneme.accuracy == null ? 'Not assessed' : '${phoneme.accuracy!.round()}/100'}',
              ),
            ),
          ),
      ],
    );
  }
}
