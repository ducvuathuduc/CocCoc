import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/character_motion.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/learning_controller.dart';
import '../../progress/application/preview_controller.dart';
import '../domain/learning_models.dart';
import 'learning_visuals.dart';
import '../data/english_explanations.dart';
import 'spoken_exercise.dart';

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key});
  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen>
    with WidgetsBindingObserver {
  bool _exitOpen = false;
  final _text = TextEditingController();
  String? _exerciseId;
  bool _backgroundPaused = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final vm = ref.read(lessonControllerProvider.notifier);
    if (lifecycle == AppLifecycleState.resumed) {
      if (_backgroundPaused) vm.resume();
      _backgroundPaused = false;
    } else {
      vm.pause();
      _backgroundPaused =
          ref.read(lessonControllerProvider).stage == LessonStage.paused;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    final state = ref.read(lessonControllerProvider);
    if (_exitOpen || state.busy) return;
    _exitOpen = true;
    final action = await learningSheet<String>(
      context,
      title: 'Wait, don’t go!',
      illustration: const ReferenceArt(
        LearningArt.pathDuo,
        width: 115,
        height: 120,
      ),
      child: Column(
        children: [
          const Text(
            'You can pause this lesson and pick up where you left off.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 22),
          ReferenceButton(
            label: 'KEEP LEARNING',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 14),
          ReferenceButton(
            label: 'PAUSE LESSON',
            outlined: true,
            onPressed: () => Navigator.pop(context, 'pause'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context, 'quit'),
            child: const Text(
              'END SESSION',
              style: TextStyle(
                color: LearningColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    _exitOpen = false;
    if (!mounted || action == null) return;
    final controller = ref.read(lessonControllerProvider.notifier);
    if (action == 'pause') {
      controller.pause();
    } else {
      controller.abandon();
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lessonControllerProvider);
    final controller = ref.read(lessonControllerProvider.notifier);
    ref.listen(lessonControllerProvider, (previous, next) {
      if (next.stage == LessonStage.completed &&
          previous?.stage != LessonStage.completed) {
        context.replace('/results/${next.receipt!.id}');
      }
    });
    final exercise = state.current;
    final editorIdentity = exercise == null
        ? null
        : '${exercise.id}:${state.retryPass}';
    if (_exerciseId != editorIdentity) {
      _exerciseId = editorIdentity;
      _text.value = TextEditingValue(
        text: state.text,
        selection: TextSelection.collapsed(offset: state.text.length),
      );
    }
    final feedback = state.stage == LessonStage.feedback;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 15, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Exit lesson',
                      onPressed: state.busy ? null : _exit,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 32,
                        color: ReferenceColors.disabled,
                      ),
                    ),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: state.isRetry ? 1 : state.progress + .02,
                        ),
                        duration: motionDuration(context, 300),
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value.clamp(0, 1),
                          minHeight: 16,
                          borderRadius: BorderRadius.circular(16),
                          backgroundColor: ReferenceColors.border,
                          color: state.correctStreak >= 5
                              ? LearningColors.orange
                              : LearningColors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const ReferenceArt(
                      LearningArt.heart,
                      width: 26,
                      height: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(5 - (state.attempted - state.originalCorrect)).clamp(0, 5)}',
                      style: const TextStyle(
                        color: LearningColors.red,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (exercise == null)
                Expanded(
                  child: Center(
                    child: state.busy
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(state.error ?? 'Choose a lesson to start.'),
                              TextButton(
                                onPressed: () => controller.start(),
                                child: const Text('TRY AGAIN'),
                              ),
                            ],
                          ),
                  ),
                )
              else
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 26,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.correctStreak >= 5)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '${state.correctStreak} IN A ROW',
                                  style: const TextStyle(
                                    color: LearningColors.orange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (state.isRetry)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'LET’S CORRECT YOUR MISTAKES',
                                  style: TextStyle(
                                    color: LearningColors.orange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (exercise.kind == ExerciseKind.imageChoice)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 15),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: LearningColors.purple,
                                      size: 23,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'NEW WORD',
                                      style: TextStyle(
                                        color: LearningColors.purple,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              exercise.title,
                              style: headingStyle.copyWith(fontSize: 23),
                            ),
                            const SizedBox(height: 19),
                            _renderer(
                              exercise,
                              state,
                              controller,
                              constraints.maxHeight,
                            ),
                            if (state.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: Text(
                                  state.error!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: LearningColors.red,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              _LessonFooterTransition(
                child: feedback
                    ? _feedback(exercise!, state, controller)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 15),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (exercise?.hint != null)
                                  TextButton(
                                    onPressed: state.busy
                                        ? null
                                        : () {
                                            controller.revealHint();
                                            showLearningNotice(
                                              context,
                                              'A little help',
                                              exercise!.hint!,
                                            );
                                          },
                                    child: const Text(
                                      'HINT',
                                      style: TextStyle(
                                        color: ReferenceColors.disabled,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (exercise != null &&
                                    {
                                      ExerciseKind.listenChoice,
                                      ExerciseKind.dictation,
                                    }.contains(exercise.kind))
                                  Flexible(
                                    child: TextButton(
                                      onPressed: state.busy
                                          ? null
                                          : controller.substituteMedia,
                                      child: Text(
                                        'CAN’T LISTEN NOW',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: ReferenceColors.disabled,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (exercise != null &&
                                !state.textAlternative &&
                                {
                                  ExerciseKind.dialogueTurn,
                                  ExerciseKind.speakRepeat,
                                }.contains(exercise.kind))
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : controller.substituteMedia,
                                  child: const Text(
                                    "CAN'T SPEAK NOW",
                                    style: TextStyle(
                                      color: ReferenceColors.disabled,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ReferenceButton(
                                label: state.busy ? 'CHECKING…' : 'CHECK',
                                backgroundColor: LearningColors.green,
                                onPressed: state.canCheck
                                    ? () {
                                        FocusScope.of(context).unfocus();
                                        controller.check();
                                      }
                                    : null,
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderer(
    Exercise exercise,
    LessonState state,
    LessonController controller,
    double availableHeight,
  ) {
    final editable = state.stage == LessonStage.answering && !state.busy;
    switch (exercise.kind) {
      case ExerciseKind.imageChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _audio(exercise.prompt),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    exercise.prompt,
                    style: const TextStyle(
                      color: LearningColors.purple,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 20,
                runSpacing: 16,
                children: exercise.choices.map((option) {
                  final width = (c.maxWidth - 20) / 2;
                  final artHeight = (availableHeight * .22).clamp(82.0, 145.0);
                  final art = LearningArt.character(option.art);
                  final factor = ((width - 30) / art.source.width).clamp(
                    0.0,
                    artHeight / art.source.height,
                  );
                  return SizedBox(
                    width: width,
                    child: LearningCard(
                      selected: state.selectedId == option.id,
                      correct: state.stage == LessonStage.feedback
                          ? state.correct
                          : null,
                      onTap: editable
                          ? () => controller.select(option.id)
                          : null,
                      padding: const EdgeInsets.fromLTRB(12, 17, 12, 13),
                      child: Column(
                        children: [
                          SizedBox(
                            height: artHeight,
                            child: Center(
                              child: ReferenceArt(
                                art,
                                width: art.source.width * factor,
                                height: art.source.height * factor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Text(
                            option.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              color: state.selectedId == option.id
                                  ? state.correct == true
                                        ? LearningColors.greenDark
                                        : LearningColors.blue
                                  : ReferenceColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      case ExerciseKind.choice:
      case ExerciseKind.listenChoice:
        return Column(
          children: [
            _prompt(
              exercise,
              audio: exercise.kind == ExerciseKind.listenChoice,
            ),
            const SizedBox(height: 55),
            for (final option in exercise.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LearningCard(
                  selected: state.selectedId == option.id,
                  correct: state.stage == LessonStage.feedback
                      ? state.correct
                      : null,
                  onTap: editable ? () => controller.select(option.id) : null,
                  child: Center(
                    child: Text(
                      option.text,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
          ],
        );
      case ExerciseKind.wordBank:
      case ExerciseKind.sentenceOrder:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _prompt(exercise),
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 115),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: ReferenceColors.border, width: 2),
                  bottom: BorderSide(color: ReferenceColors.border, width: 2),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Wrap(
                spacing: 7,
                runSpacing: 9,
                children: state.tokenIds
                    .map(
                      (id) => _token(
                        exercise.tokens.firstWhere((t) => t.id == id),
                        () => controller.toggleToken(id),
                        editable,
                        true,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 45),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 7,
                runSpacing: 12,
                children: exercise.tokens
                    .map(
                      (token) => AnimatedOpacity(
                        duration: motionDuration(context, 120),
                        opacity: state.tokenIds.contains(token.id) ? .2 : 1,
                        child: _token(
                          token,
                          () => controller.toggleToken(token.id),
                          editable && !state.tokenIds.contains(token.id),
                          false,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      case ExerciseKind.matchPairs:
        return Column(
          children: [
            const SizedBox(height: 55),
            for (final pair in exercise.pairs.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedOpacity(
                        duration: motionDuration(context),
                        opacity: state.matchedPairs.containsKey(pair.key)
                            ? .3
                            : 1,
                        child: LearningCard(
                          selected: state.selectedPairLeft == pair.key,
                          onTap:
                              editable &&
                                  !state.matchedPairs.containsKey(pair.key)
                              ? () => controller.selectPairLeft(pair.key)
                              : null,
                          child: Center(
                            child: Text(
                              pair.key,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: AnimatedOpacity(
                        duration: motionDuration(context),
                        opacity: state.matchedPairs.containsValue(pair.value)
                            ? .3
                            : 1,
                        child: LearningCard(
                          onTap:
                              editable &&
                                  !state.matchedPairs.containsValue(pair.value)
                              ? () => controller.selectPairRight(pair.value)
                              : null,
                          child: Center(
                            child: Text(
                              pair.value,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case ExerciseKind.speakRepeat:
        return SpeakingWordsExercise(
          prompt: exercise.prompt,
          availableHeight: availableHeight,
          onSpeak: editable
              ? () => showLearningNotice(
                  context,
                  'Speaking unavailable',
                  'You can continue this exercise by typing your answer. Tap “CAN\'T SPEAK NOW” to continue.',
                )
              : null,
        );
      case ExerciseKind.dialogueTurn:
        return LilyDialogueExercise(
          exercise: exercise,
          state: state,
          textController: _text,
          availableHeight: availableHeight,
          onChanged: controller.updateText,
          onListen: editable
              ? () => showLearningNotice(
                  context,
                  'Audio unavailable',
                  'Read Lily’s message and reply in English. You can use “CAN\'T SPEAK NOW” to type your answer.',
                )
              : null,
        );
      case ExerciseKind.textTranslation:
      case ExerciseKind.fillBlank:
      case ExerciseKind.dictation:
      case ExerciseKind.storyQuestion:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _prompt(exercise, audio: exercise.kind == ExerciseKind.dictation),
            const SizedBox(height: 25),
            TextField(
              controller: _text,
              readOnly: !editable,
              onChanged: controller.updateText,
              maxLength: 512,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                hintText: exercise.kind == ExerciseKind.fillBlank
                    ? 'Type the missing word'
                    : 'Type in English',
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: ReferenceColors.border,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: ReferenceColors.border,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _audio(String prompt) => SizedBox(
    width: 42,
    height: 42,
    child: IconButton.filled(
      tooltip: 'Listen',
      style: IconButton.styleFrom(
        backgroundColor: LearningColors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: () => showLearningNotice(
        context,
        'Listening alternative',
        'Audio is unavailable. Read the prompt: $prompt',
      ),
      icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
    ),
  );

  Widget _prompt(Exercise exercise, {bool audio = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (audio) ...[
        _audio(exercise.prompt),
        const SizedBox(width: 14),
      ] else ...[
        CharacterMotion(
          character: LessonCharacter.falstaff,
          epoch: exercise.id,
          reaction:
              ref.watch(lessonControllerProvider).stage != LessonStage.feedback
              ? CharacterReaction.reset
              : ref.watch(lessonControllerProvider).correct == true
              ? CharacterReaction.correct
              : CharacterReaction.incorrect,
          width: 99,
          height: 149,
          fallback: const ReferenceArt(
            LearningArt.bear,
            width: 99,
            height: 149,
          ),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: SpeechBubble(
          child: Text(exercise.prompt, style: const TextStyle(fontSize: 20)),
        ),
      ),
    ],
  );

  Widget _token(
    ExerciseChoice token,
    VoidCallback onTap,
    bool enabled,
    bool selected,
  ) => LearningCard(
    onTap: enabled ? onTap : null,
    selected: selected,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Text(token.text, style: const TextStyle(fontSize: 18)),
  );

  String _answer(Exercise exercise) => exerciseAnswer(exercise);

  Widget _feedback(
    Exercise exercise,
    LessonState state,
    LessonController controller,
  ) {
    final correct = state.correct == true;
    final color = correct ? LearningColors.greenDark : LearningColors.redDark;
    return Container(
      width: double.infinity,
      color: correct ? LearningColors.correct : LearningColors.incorrect,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
                size: 27,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  correct ? 'Excellent!' : 'Incorrect',
                  style: headingStyle.copyWith(color: color),
                ),
              ),
              IconButton(
                tooltip: 'Report exercise',
                onPressed: _report,
                icon: Icon(Icons.outlined_flag_rounded, color: color),
              ),
            ],
          ),
          if (!correct) ...[
            Text(
              'Correct Answer:',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _answer(exercise),
              style: TextStyle(color: color, fontSize: 20),
            ),
            const SizedBox(height: 14),
          ],
          if (correct && exercise.meaning != null) ...[
            Text(
              'Meaning:',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              exercise.meaning!,
              style: TextStyle(color: color, fontSize: 20),
            ),
            const SizedBox(height: 14),
          ],
          ReferenceButton(
            label: 'EXPLAIN MY ANSWER',
            outlined: true,
            foregroundColor: const Color(0xFF20AFAF),
            onPressed: () => context.push('/explanation'),
          ),
          const SizedBox(height: 12),
          if (state.error != null)
            Text(state.error!, style: TextStyle(color: color, fontSize: 16)),
          ReferenceButton(
            label: correct ? 'CONTINUE' : 'GOT IT',
            backgroundColor: correct
                ? LearningColors.green
                : LearningColors.red,
            edgeColor: color,
            onPressed: state.busy ? null : controller.next,
          ),
        ],
      ),
    );
  }

  Future<void> _report() async {
    final category = await learningSheet<String>(
      context,
      title: 'Report this exercise',
      child: Column(
        children: [
          for (final value in [
            'My answer should be accepted',
            'The translation is wrong',
            'Something else',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LearningCard(
                onTap: () => Navigator.pop(context, value),
                child: Text(value, style: const TextStyle(fontSize: 17)),
              ),
            ),
        ],
      ),
    );
    if (category != null && mounted) {
      ref.read(previewControllerProvider.notifier).report(category);
      await showLearningNotice(
        context,
        'Report queued',
        'Thanks for helping us improve this exercise.',
      );
    }
  }
}

class _LessonFooterTransition extends StatelessWidget {
  const _LessonFooterTransition({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final duration = motionDuration(context, 220);
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      alignment: Alignment.bottomCenter,
      child: child,
    );
  }
}
