import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/character_motion.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/presentation/streak_screen.dart';
import '../application/clash_controller.dart';

abstract final class ClashArt {
  static const versusSam = ArtRegion(
    'clash-versus',
    Rect.fromLTWH(435, 1728, 500, 519),
  );
  static const versusJoshua = ArtRegion(
    'clash-versus',
    Rect.fromLTWH(293, 256, 405, 600),
  );
  static const sam = ArtRegion(
    'clash-intro',
    Rect.fromLTWH(97, 1235, 390, 396),
  );
  static const joshua = ArtRegion(
    'clash-intro',
    Rect.fromLTWH(738, 1190, 308, 442),
  );
  static const coach = ArtRegion(
    'clash-coach',
    Rect.fromLTWH(381, 1279, 398, 561),
  );
  static const finish = ArtRegion(
    'clash-finish',
    Rect.fromLTWH(391, 1220, 400, 581),
  );
  static const zari = ArtRegion(
    'clash-zari',
    Rect.fromLTWH(129, 663, 227, 512),
  );
  static const oscar = ArtRegion(
    'clash-oscar',
    Rect.fromLTWH(85, 709, 266, 481),
  );
}

class ClashScreen extends ConsumerStatefulWidget {
  const ClashScreen({
    this.clockEnabled = const bool.fromEnvironment(
      'ENABLE_PREVIEW_CLOCK',
      defaultValue: true,
    ),
    super.key,
  });
  final bool clockEnabled;
  @override
  ConsumerState<ClashScreen> createState() => _ClashScreenState();
}

class _ClashScreenState extends ConsumerState<ClashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker clock;
  bool foreground = true, modalOpen = false;
  int lastSecond = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clock = createTicker((elapsed) {
      final second = elapsed.inSeconds;
      if (second > lastSecond) {
        final delta = second - lastSecond;
        lastSecond = second;
        ref.read(clashControllerProvider.notifier).tick(delta);
      }
    });
  }

  void syncClock() {
    final active =
        widget.clockEnabled &&
        foreground &&
        !modalOpen &&
        ref.read(clashControllerProvider).stage == ClashStage.playing &&
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

  Future<void> close() async {
    final s = ref.read(clashControllerProvider);
    if (s.stage == ClashStage.intro || s.stage == ClashStage.waiting) {
      closeStreak(context);
      return;
    }
    modalOpen = true;
    syncClock();
    final quit = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Quit this clash?', style: headingStyle),
              const SizedBox(height: 16),
              ReferenceButton(
                label: 'KEEP PLAYING',
                onPressed: () => Navigator.pop(sheet, false),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(sheet, true),
                child: const Text(
                  'QUIT',
                  style: TextStyle(
                    color: LearningColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    modalOpen = false;
    if (quit == true) {
      ref.read(clashControllerProvider.notifier).quit();
      closeStreak(context);
    } else {
      syncClock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(clashControllerProvider),
        vm = ref.read(clashControllerProvider.notifier);
    ref.listen(clashControllerProvider, (_, next) => syncClock());
    if (s.stage == ClashStage.versus) return _versus(context, ref);
    final quiz = s.stage == ClashStage.playing;
    final right = s.checked && vm.isCorrect;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            if (s.stage == ClashStage.intro)
              LearningHeader(title: 'Friends Clash', onClose: close)
            else if (s.stage != ClashStage.waiting)
              _score(s)
            else
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Close clash',
                  onPressed: close,
                  icon: const Icon(Icons.close, color: streakGray),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, quiz ? 8 : 30, 16, 20),
                child: switch (s.stage) {
                  ClashStage.intro => Column(
                    children: [
                      const SizedBox(height: 90),
                      Text(
                        'New Friends Clash\nwith Joshua!',
                        textAlign: TextAlign.center,
                        style: headingStyle.copyWith(fontSize: 30),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '◷ 22 HOURS LEFT',
                        style: TextStyle(
                          fontSize: 19,
                          color: Color(0xFFFF9600),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 48),
                      const _Portraits(),
                    ],
                  ),
                  ClashStage.rules => _coach(
                    'Get the most answers correct in 1 min to win the clash!',
                    false,
                  ),
                  ClashStage.timeUp => _coach(
                    'Time’s up! You earned ${s.correct * 2} XP in this mock clash.',
                    true,
                  ),
                  ClashStage.waiting => Column(
                    children: [
                      const SizedBox(height: 25),
                      Text(
                        'It’s Joshua’s turn now!',
                        textAlign: TextAlign.center,
                        style: headingStyle.copyWith(fontSize: 30),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '◷ 2 DAYS LEFT',
                        style: TextStyle(
                          fontSize: 19,
                          color: Color(0xFFFF9600),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 36),
                      const _Portraits(),
                      const SizedBox(height: 20),
                      StreakOutline(
                        padding: 0,
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'You',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: streakGray,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Joshua',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: streakGray,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(
                              color: ReferenceColors.border,
                              height: 2,
                              thickness: 2,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${s.correct}',
                                      textAlign: TextAlign.center,
                                      style: headingStyle.copyWith(
                                        fontSize: 30,
                                        color: LearningColors.green,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '–',
                                      textAlign: TextAlign.center,
                                      style: headingStyle.copyWith(
                                        fontSize: 30,
                                        color: streakBlue,
                                      ),
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
                  ClashStage.playing => _question(context, s, vm),
                  ClashStage.versus => const SizedBox.shrink(),
                },
              ),
            ),
            if (quiz && s.checked)
              Container(
                width: double.infinity,
                color: right
                    ? LearningColors.correct
                    : LearningColors.incorrect,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  right
                      ? '✓ Nice job!'
                      : 'Correct answer: ${vm.question.answer.join(' ')}',
                  style: headingStyle.copyWith(
                    color: right
                        ? LearningColors.greenDark
                        : LearningColors.red,
                    fontSize: 25,
                  ),
                ),
              ),
            Container(
              color: quiz && s.checked
                  ? (right ? LearningColors.correct : LearningColors.incorrect)
                  : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: ReferenceButton(
                label: s.stage == ClashStage.intro
                    ? 'START FRIENDS CLASH'
                    : quiz && !s.checked
                    ? 'CHECK'
                    : 'CONTINUE',
                backgroundColor:
                    s.stage == ClashStage.intro || s.stage == ClashStage.waiting
                    ? streakBlue
                    : !s.checked || right || !quiz
                    ? LearningColors.green
                    : LearningColors.red,
                edgeColor:
                    s.stage == ClashStage.intro || s.stage == ClashStage.waiting
                    ? const Color(0xFF1899D6)
                    : !s.checked || right || !quiz
                    ? LearningColors.greenDark
                    : LearningColors.redDark,
                onPressed: quiz && s.answer.isEmpty
                    ? null
                    : () {
                        if (s.stage == ClashStage.waiting) {
                          closeStreak(context);
                        } else if (quiz && !s.checked) {
                          vm.check();
                        } else {
                          vm.advance();
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _score(ClashState s) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Close clash',
          onPressed: close,
          icon: const Icon(Icons.close, color: streakGray, size: 30),
        ),
        Expanded(
          child: StreakOutline(
            padding: 8,
            child: Row(
              children: [
                const ClipOval(
                  child: ReferenceArt(ClashArt.sam, width: 42, height: 42),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${s.correct}',
                    textAlign: TextAlign.center,
                    style: headingStyle.copyWith(
                      color: LearningColors.green,
                      fontSize: 27,
                    ),
                  ),
                ),
                SizedBox(
                  width: 51,
                  height: 51,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: s.remaining / 60,
                          strokeWidth: 2.5,
                          color: ReferenceColors.purple,
                          backgroundColor: ReferenceColors.border,
                        ),
                      ),
                      Text(
                        '${s.remaining ~/ 60}:${(s.remaining % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: s.remaining == 0
                              ? LearningColors.red
                              : ReferenceColors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Text(
                    '–',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: streakBlue, fontSize: 23),
                  ),
                ),
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFFFFB000),
                  child: Text(
                    'J',
                    style: TextStyle(
                      fontSize: 23,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Widget _coach(String message, bool done) => Column(
    children: [
      const SizedBox(height: 110),
      StreakOutline(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 23),
        ),
      ),
      const SizedBox(height: 32),
      CharacterMotion(
        character: LessonCharacter.eddy,
        reaction: done ? CharacterReaction.correct : CharacterReaction.reset,
        epoch: done ? 'clash-finished' : 'clash-rules',
        width: 140,
        height: done ? 203 : 197,
        fallback: ReferenceArt(
          done ? ClashArt.finish : ClashArt.coach,
          width: 140,
          height: done ? 203 : 197,
        ),
      ),
    ],
  );
  Widget _question(BuildContext context, ClashState s, ClashController vm) {
    final q = vm.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          q.wordBank
              ? 'Translate this sentence'
              : 'Select the correct translation',
          style: headingStyle.copyWith(fontSize: 25),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            CharacterMotion(
              character: q.wordBank
                  ? LessonCharacter.oscar
                  : LessonCharacter.zari,
              reaction: !s.checked
                  ? CharacterReaction.reset
                  : vm.isCorrect
                  ? CharacterReaction.correct
                  : CharacterReaction.incorrect,
              epoch: 'clash-${s.index}-${s.checked}',
              width: q.wordBank ? 92 : 80,
              height: q.wordBank ? 180 : 180,
              fallback: ReferenceArt(
                q.wordBank ? ClashArt.oscar : ClashArt.zari,
                width: q.wordBank ? 92 : 80,
                height: 180,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StreakOutline(
                child: Text(q.cue, style: const TextStyle(fontSize: 21)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: ReferenceColors.border, thickness: 2),
        if (q.wordBank) ...[
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final word in s.answer)
                LearningCard(
                  padding: const EdgeInsets.all(10),
                  onTap: s.checked ? null : () => vm.choose(word),
                  child: Text(word, style: const TextStyle(fontSize: 21)),
                ),
            ],
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final word in q.options)
                LearningCard(
                  selected: s.answer.contains(word),
                  padding: const EdgeInsets.all(10),
                  onTap: s.checked ? null : () => vm.choose(word),
                  child: Text(
                    word,
                    style: TextStyle(
                      fontSize: 21,
                      color: s.answer.contains(word)
                          ? streakGray
                          : ReferenceColors.ink,
                    ),
                  ),
                ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 25),
          for (final word in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LearningCard(
                selected: s.answer.contains(word),
                correct: s.checked
                    ? s.answer.contains(word)
                          ? vm.isCorrect
                          : null
                    : null,
                onTap: s.checked ? null : () => vm.choose(word),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    word,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 23),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _versus(BuildContext context, WidgetRef ref) {
    final name = ref.watch(previewControllerProvider).name;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF1AA7E9),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ReferenceArt(
                          ClashArt.versusJoshua,
                          width: 115,
                          height: 165,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Joshua',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          '0 wins',
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFF53C102),
              child: const Center(
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF53C102),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ReferenceArt(
                          ClashArt.versusSam,
                          width: 140,
                          height: 145,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          '0 wins',
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ReferenceButton(
                label: 'CONTINUE',
                onPressed: () =>
                    ref.read(clashControllerProvider.notifier).advance(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Portraits extends StatelessWidget {
  const _Portraits();
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      const Expanded(
        child: Center(
          child: ReferenceArt(ClashArt.sam, width: 128, height: 130),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Center(
          child: ReferenceArt(ClashArt.joshua, width: 110, height: 158),
        ),
      ),
    ],
  );
}
