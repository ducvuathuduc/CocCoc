import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/character_motion.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../../core/design/lesson_motion.dart';
import '../../../core/audio/speech_recorder.dart';
import '../../../core/config/app_config.dart';
import '../application/learning_controller.dart';
import '../application/lesson_activity_coordinator.dart';
import '../data/speech_assessment.dart';
import '../../auth/application/auth_controller.dart';
import '../../progress/application/preview_controller.dart';
import '../../hearts/presentation/hearts_sheets.dart';
import '../../report/application/issue_report_provider.dart';
import '../../report/domain/issue_report.dart';
import '../../report/presentation/report_issue_menu.dart';
import '../domain/learning_models.dart';
import '../services/lesson_audio_service.dart';
import 'learning_visuals.dart';
import 'lesson_image_view.dart';
import '../data/english_explanations.dart';
import 'spoken_exercise.dart';
import 'exercises/match_pairs_exercise.dart';
import 'widgets/lesson_choice_tile.dart';
import 'widgets/lesson_sheets.dart';
import 'widgets/token_fly_in.dart';
import '../../vocabulary/presentation/notebook_screen.dart';

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key});
  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen>
    with WidgetsBindingObserver {
  bool _exitOpen = false;
  final _text = TextEditingController();

  /// Speaking exercise state: recording, assessing, and the latest scored
  /// attempt (per-word feedback) for the exercise id in [_spokenId].
  bool _recording = false;
  bool _assessing = false;
  String? _spokenId;
  SpeechVerdict? _verdict;
  String? _exerciseId;
  final _heartsKey = GlobalKey();
  String? _reportToast;
  Timer? _reportToastTimer;
  bool _backgroundPaused = false;
  final _bankKeys = <String, GlobalKey>{};

  /// The next speaker tap plays the slow (0.75x) clip: like the reference
  /// app, tapping the speaker again after hearing the prompt slows it down,
  /// and the following tap is back at normal speed.
  bool _slowNext = false;
  late final LessonAudioService _sound = ref.read(lessonAudioServiceProvider);

  /// Exercise kinds whose prompt plays as soon as the exercise appears.
  static const _autoplayKinds = {
    ExerciseKind.listenChoice,
    ExerciseKind.dictation,
    ExerciseKind.speakRepeat,
    ExerciseKind.dialogueTurn,
    ExerciseKind.imageChoice,
    ExerciseKind.choice,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sound.prefetch(ref.read(lessonControllerProvider).exercises);
        _syncLessonActivity();
      }
    });
  }

  void _syncLessonActivity([LessonState? next]) {
    ref
        .read(lessonActivityCoordinatorProvider)
        .update(
          lesson: next ?? ref.read(lessonControllerProvider),
          streak: ref.read(learningStateProvider).streak,
          userId: ref.read(authControllerProvider).user?.id,
        )
        .ignore();
  }

  void _autoplay(String identity) {
    if (!mounted || _exerciseId != identity) return;
    final state = ref.read(lessonControllerProvider);
    final exercise = state.current;
    if (exercise == null ||
        exercise.audio == null ||
        state.textAlternative ||
        state.stage != LessonStage.answering ||
        !_autoplayKinds.contains(exercise.kind)) {
      return;
    }
    _sound.play(exercise.audio);
    _slowNext = exercise.slowAudio != null;
  }

  /// Speaker button: normal speed, then slow on the next tap, alternating.
  void _replay(Exercise exercise) {
    final slow = _slowNext && exercise.slowAudio != null;
    _sound.play(slow ? exercise.slowAudio : exercise.audio);
    _slowNext = exercise.slowAudio != null && !slow;
  }

  /// Tap-to-hear for an English tile or option (no-op without a clip).
  void _speakWord(Exercise exercise, String text) =>
      _sound.playWord(exercise, text);

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
    _syncLessonActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sound.stop();
    _text.dispose();
    _reportToastTimer?.cancel();
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
      if (!await controller.abandon() || !mounted) return;
    }
    context.pop();
  }

  Future<void> _showHeartsIntro() async {
    final controller = ref.read(lessonControllerProvider.notifier);
    controller.acknowledgeHeartsIntro();
    await showHeartsIntroSheet(
      context,
      hearts: ref.read(lessonControllerProvider).hearts,
    );
  }

  void _gotIt(LessonState state, LessonController controller) {
    if (!state.outOfHearts) {
      controller.next();
      return;
    }
    // In-lesson out-of-hearts offer (Gummble sc_1ae5ddcf).
    showHeartsOfferSheet(
      context,
      heartsAnchor: _heartsKey,
      onEnd: () async {
        if (await controller.abandon() && mounted) context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.referencePalette;
    final state = ref.watch(lessonControllerProvider);
    final controller = ref.read(lessonControllerProvider.notifier);
    ref.listen(lessonControllerProvider, (previous, next) {
      _syncLessonActivity(next);
      if (next.stage == LessonStage.feedback &&
          previous?.stage == LessonStage.checking) {
        if (next.correct == true) {
          HapticFeedback.lightImpact();
          // Every 5th answer in a row plays the combo sparkle instead.
          final combo = next.correctStreak >= 5 && next.correctStreak % 5 == 0;
          _sound.effect(combo ? LessonSfx.combo : LessonSfx.correct);
        } else {
          HapticFeedback.mediumImpact();
          _sound.effect(LessonSfx.incorrect);
          if (previous != null && next.hearts < previous.hearts) {
            _sound.effectAfter(
              LessonSfx.heartLoss,
              const Duration(milliseconds: 180),
            );
          }
          if (next.showHeartsIntro) _showHeartsIntro();
        }
      }
      if (next.stage == LessonStage.completed &&
          previous?.stage != LessonStage.completed) {
        _sound.effect(LessonSfx.lessonComplete);
        context.replace(
          next.placement && ref.read(appConfigProvider).isApi
              ? '/placement/result'
              : '/results/${next.receipt!.id}',
        );
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
      _slowNext = false;
      if (editorIdentity != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _autoplay(editorIdentity),
        );
      }
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
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 15, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Exit lesson',
                          onPressed: state.busy ? null : _exit,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 32,
                            color: palette.disabled,
                          ),
                        ),
                        Expanded(
                          child: LessonProgressBar(
                            value: state.isRetry ? 1 : state.progress + .02,
                            color: state.correctStreak >= 5
                                ? LearningColors.orange
                                : LearningColors.green,
                            shineColor: state.correctStreak >= 5
                                ? LessonMotionTokens.orangeShine
                                : LessonMotionTokens.greenShine,
                            comboPulse: state.correctStreak >= 5
                                ? state.correctStreak
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        LessonHeartCounter(
                          key: _heartsKey,
                          hearts: state.hearts,
                          ghost: const ReferenceArt(
                            LearningArt.heart,
                            width: 26,
                            height: 24,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const ReferenceArt(
                                LearningArt.heart,
                                width: 26,
                                height: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${state.hearts}',
                                style: const TextStyle(
                                  color: LearningColors.red,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
                                  Text(
                                    state.error ?? 'Choose a lesson to start.',
                                  ),
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
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                16,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - 26,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (state.correctStreak >= 5)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: LessonPop(
                                          trigger: state.correctStreak,
                                          child: Text(
                                            '${state.correctStreak} IN A ROW',
                                            style: const TextStyle(
                                              color: LearningColors.orange,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
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
                                    if (exercise.kind ==
                                        ExerciseKind.imageChoice)
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
                                      style: headingStyle.copyWith(
                                        fontSize: 23,
                                      ),
                                    ),
                                    const SizedBox(height: 19),
                                    _renderer(
                                      exercise,
                                      state,
                                      controller,
                                      constraints.maxHeight,
                                      palette,
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
                  Visibility(
                    visible: !feedback,
                    maintainSize: true,
                    maintainState: true,
                    maintainAnimation: true,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 15),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: exercise?.audioPairs == true
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.spaceBetween,
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
                                    child: Text(
                                      'HINT',
                                      style: TextStyle(
                                        color: palette.disabled,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (exercise != null &&
                                    (exercise.audioPairs ||
                                        {
                                          ExerciseKind.listenChoice,
                                          ExerciseKind.dictation,
                                        }.contains(exercise.kind)))
                                  Flexible(
                                    child: TextButton(
                                      onPressed: state.busy
                                          ? null
                                          : exercise.audioPairs
                                          ? controller.skipListening
                                          : controller.substituteMedia,
                                      child: Text(
                                        'CAN’T LISTEN NOW',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: palette.disabled,
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
                                  child: Text(
                                    "CAN'T SPEAK NOW",
                                    style: TextStyle(
                                      color: palette.disabled,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ReferenceButton(
                                label: state.busy
                                    ? 'CHECKING…'
                                    : exercise?.audioPairs == true
                                    ? 'CONTINUE'
                                    : 'CHECK',
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
                  ),
                ],
              ),
              if (feedback)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // sc_2082f9ab: toast sits just above the feedback panel.
                      if (!state.skipped)
                        Material(
                          child: TextButton.icon(
                            icon: const Icon(Icons.bookmark_add_outlined),
                            label: const Text('SAVE TO MY VOCABULARY'),
                            onPressed: () => editVocabulary(
                              context,
                              term: exercise!.correctText,
                              meaning: exercise.meaning ?? '',
                              example: exercise.correctText,
                            ),
                          ),
                        ),
                      if (_reportToast case final message?)
                        IssueReportedToast(message: message),
                      LessonFeedbackEntrance(
                        key: ValueKey('${exercise!.id}:${state.retryPass}'),
                        child: state.skipped
                            ? SkipListeningPanel(
                                onContinue: state.busy ? null : controller.next,
                                onReport: _report,
                              )
                            : _feedback(exercise, state, controller),
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

  Widget _renderer(
    Exercise exercise,
    LessonState state,
    LessonController controller,
    double availableHeight,
    ReferencePalette palette,
  ) {
    final editable = state.stage == LessonStage.answering && !state.busy;
    switch (exercise.kind) {
      case ExerciseKind.imageChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _audio(exercise),
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
                  final image = option.image;
                  final art = LearningArt.character(option.art);
                  final factor = ((width - 30) / art.source.width).clamp(
                    0.0,
                    artHeight / art.source.height,
                  );
                  final picture = image != null
                      ? LessonImageView(
                          image,
                          size: math.min(width - 30, artHeight),
                        )
                      : ReferenceArt(
                          art,
                          width: art.source.width * factor,
                          height: art.source.height * factor,
                        );
                  return SizedBox(
                    width: width,
                    child: LessonChoiceTile(
                      selected: state.selectedId == option.id,
                      correct: state.stage == LessonStage.feedback
                          ? state.correct
                          : null,
                      onTap: editable
                          ? () {
                              _speakWord(exercise, option.text);
                              controller.select(option.id);
                            }
                          : null,
                      padding: const EdgeInsets.fromLTRB(12, 17, 12, 13),
                      child: Column(
                        children: [
                          SizedBox(
                            height: artHeight,
                            child: Center(child: picture),
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
                                  : palette.ink,
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
                child: LessonChoiceTile(
                  selected: state.selectedId == option.id,
                  correct: state.stage == LessonStage.feedback
                      ? state.correct
                      : null,
                  onTap: editable
                      ? () {
                          if (exercise.kind == ExerciseKind.choice) {
                            _speakWord(exercise, option.text);
                          }
                          controller.select(option.id);
                        }
                      : null,
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
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.border, width: 2),
                  bottom: BorderSide(color: palette.border, width: 2),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Wrap(
                spacing: 7,
                runSpacing: 9,
                children: state.tokenIds
                    .map(
                      (id) => TokenFlyIn(
                        key: ValueKey('answer-$id'),
                        originKey: _bankKeys[id],
                        child: _token(
                          exercise.tokens.firstWhere((t) => t.id == id),
                          () => controller.toggleToken(id),
                          editable,
                          true,
                        ),
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
                        key: _bankKeys.putIfAbsent(token.id, GlobalKey.new),
                        duration: motionDuration(context, 120),
                        opacity: state.tokenIds.contains(token.id) ? .2 : 1,
                        child: _token(
                          token,
                          () {
                            _speakWord(exercise, token.text);
                            controller.toggleToken(token.id);
                          },
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
        return MatchPairsExercise(
          key: ValueKey('${exercise.id}:${state.retryPass}'),
          exercise: exercise,
          matched: state.matchedPairs,
          selectedLeft: state.selectedPairLeft,
          editable: editable,
          onLeft: (key) {
            _speakWord(exercise, exercise.pairLabel(key));
            controller.selectPairLeft(key);
          },
          onRight: controller.selectPairRight,
        );
      case ExerciseKind.speakRepeat:
        final assessor = ref.read(speechAssessorProvider);
        return SpeakingWordsExercise(
          prompt: exercise.prompt,
          availableHeight: availableHeight,
          listening: _recording && _spokenId == exercise.id,
          words: _spokenId == exercise.id ? _verdict?.words : null,
          onSpeak: !editable || _assessing
              ? null
              : assessor == null
              ? () => showLearningNotice(
                  context,
                  'Speaking unavailable',
                  'You can continue this exercise by typing your answer. Tap “CAN\'T SPEAK NOW” to continue.',
                )
              : () => _speak(exercise, assessor, controller),
        );
      case ExerciseKind.dialogueTurn:
        return LilyDialogueExercise(
          exercise: exercise,
          state: state,
          textController: _text,
          availableHeight: availableHeight,
          onChanged: controller.updateText,
          onListen: editable
              ? exercise.audio != null
                    ? () => _replay(exercise)
                    : () => showLearningNotice(
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
                fillColor: palette.raisedSurface,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.border, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.border, width: 2),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _audio(Exercise exercise) => SizedBox(
    width: 42,
    height: 42,
    child: IconButton.filled(
      tooltip: 'Listen',
      style: IconButton.styleFrom(
        backgroundColor: LearningColors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: exercise.audio != null
          ? () => _replay(exercise)
          : () => showLearningNotice(
              context,
              'Listening alternative',
              'Audio is unavailable. Read the prompt: ${exercise.prompt}',
            ),
      icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
    ),
  );

  Widget _prompt(Exercise exercise, {bool audio = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (audio) ...[
        _audio(exercise),
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

  /// First tap records, second tap sends the attempt for pronunciation
  /// assessment; the result colors the prompt words and fills the answer
  /// (the reference when it passes, else what was heard) for CHECK.
  Future<void> _speak(
    Exercise exercise,
    SpeechAssessor assessor,
    LessonController controller,
  ) async {
    final recorder = ref.read(speechRecorderProvider);
    if (!_recording) {
      final started = await recorder.start();
      if (!mounted) return;
      if (!started) {
        showLearningNotice(
          context,
          'Microphone unavailable',
          'Allow microphone access to speak, or tap “CAN\'T SPEAK NOW” to type your answer.',
        );
        return;
      }
      setState(() {
        _recording = true;
        _spokenId = exercise.id;
        _verdict = null;
      });
      return;
    }
    setState(() {
      _recording = false;
      _assessing = true;
    });
    final wav = await recorder.stop();
    final reference = exercise.correctText.trim().isNotEmpty
        ? exercise.correctText
        : exercise.prompt;
    SpeechVerdict? verdict;
    try {
      if (wav != null) {
        verdict = await assessor.assess(
          wav,
          exerciseId: exercise.id,
          referenceText: reference,
        );
      }
    } catch (_) {
      verdict = null;
    }
    if (!mounted) return;
    setState(() {
      _assessing = false;
      _verdict = verdict;
    });
    if (verdict == null || verdict.transcript.trim().isEmpty) {
      showLearningNotice(
        context,
        'We couldn’t hear you',
        'Tap the button and say the sentence again, or tap “CAN\'T SPEAK NOW”.',
      );
      return;
    }
    final answer = verdict.passed ? reference : verdict.transcript;
    _text.text = answer;
    controller.updateText(answer);
  }

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
      padding: EdgeInsets.fromLTRB(
        16,
        13,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              LessonPop(
                trigger: '${exercise.id}:${state.retryPass}',
                child: Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                  size: 27,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  correct ? 'Excellent!' : 'Incorrect',
                  style: headingStyle.copyWith(color: color),
                ),
              ),
              Builder(
                builder: (flag) => IconButton(
                  tooltip: 'Report exercise',
                  onPressed: () => _report(flag),
                  icon: Icon(Icons.outlined_flag_rounded, color: color),
                ),
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
          if (!correct)
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
            onPressed: state.busy
                ? null
                : correct
                ? controller.next
                : () => _gotIt(state, controller),
          ),
        ],
      ),
    );
  }

  /// Report an issue (Gummble sc_f2f569c1 menu → sc_2082f9ab toast).
  Future<void> _report([BuildContext? flag]) async {
    final content = ref.read(issueReportContentProvider);
    final box = flag?.findRenderObject();
    final category = await showReportIssueMenu(
      context,
      content: content,
      anchor: box is RenderBox && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
    if (category == null || !mounted) return;
    final exerciseId = ref.read(lessonControllerProvider).current?.id ?? '';
    final sent = await ref
        .read(issueReportRepositoryProvider)
        .submit(IssueReport(exerciseId: exerciseId, category: category));
    if (!mounted) return;
    if (sent && !ref.read(appConfigProvider).isApi) {
      ref.read(previewControllerProvider.notifier).report(category);
    }
    _reportToastTimer?.cancel();
    setState(
      () => _reportToast = sent ? content.successToast : content.failureToast,
    );
    _reportToastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _reportToast = null);
    });
  }
}
