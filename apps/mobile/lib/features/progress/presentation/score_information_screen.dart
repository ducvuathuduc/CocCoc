import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/score_information_controller.dart';
import '../domain/score_information.dart';

const _portraits = [
  ArtRegion('score-information', Rect.fromLTWH(52, 1314, 121, 128)),
  ArtRegion('score-information', Rect.fromLTWH(49, 1645, 127, 127)),
  ArtRegion('score-information', Rect.fromLTWH(60, 1980, 110, 143)),
];
const _scoreLock = ArtRegion(
  'score-unavailable',
  Rect.fromLTWH(105, 867, 105, 145),
);

class ScoreInformationScreen extends ConsumerStatefulWidget {
  const ScoreInformationScreen({super.key});
  @override
  ConsumerState<ScoreInformationScreen> createState() =>
      _ScoreInformationScreenState();
}

class _ScoreInformationScreenState extends ConsumerState<ScoreInformationScreen>
    with WidgetsBindingObserver {
  late final ScoreInformationController _controller;
  final _bandsController = ScrollController();
  @override
  void initState() {
    super.initState();
    _controller = ref.read(scoreInformationProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final score = ref.read(learningStateProvider).score;
      ref
          .read(scoreInformationProvider.notifier)
          .selectRange(scoreBandIndex(score));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_bandsController.hasClients) return;
        final position = _bandsController.position;
        _bandsController.jumpTo(
          (scoreBandIndex(score) * 82 - position.viewportDimension * .35).clamp(
            0.0,
            position.maxScrollExtent,
          ),
        );
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ref.read(scoreInformationProvider.notifier).pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Future<void>.microtask(_controller.pause);
    _bandsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = ref.watch(learningStateProvider).score;
    final state = ref.watch(scoreInformationProvider);
    final band = state.band;
    final currentBand =
        state.selectedRange == scoreBandIndex(score) && !band.locked;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 49,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Close score information',
                    onPressed: () {
                      _controller.pause();
                      context.canPop() ? context.pop() : context.go('/home');
                    },
                    icon: const Icon(Icons.close, size: 32),
                  ),
                  IconButton(
                    tooltip: 'Share English Score',
                    onPressed: () => _share(context, score),
                    icon: const Icon(Icons.ios_share_outlined, size: 30),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              label: 'English Score',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ReferenceArt(
                    LearningArt.english,
                    width: 52,
                    height: 40,
                  ),
                  const SizedBox(width: 18),
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 56,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 49,
              child: ListView.builder(
                controller: _bandsController,
                scrollDirection: Axis.horizontal,
                itemCount: scoreBands.length,
                itemBuilder: (context, index) => Semantics(
                  button: true,
                  selected: index == state.selectedRange,
                  label: 'Score ${scoreBands[index].label}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => ref
                        .read(scoreInformationProvider.notifier)
                        .selectRange(index),
                    child: Container(
                      key: ValueKey('score-band-$index'),
                      width: index == 8 ? 100 : 82,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: index == state.selectedRange
                                ? LearningColors.blue
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        scoreBands[index].label,
                        style: TextStyle(
                          color: index == state.selectedRange
                              ? LearningColors.blue
                              : ReferenceColors.disabled,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(
              height: 2,
              thickness: 2,
              color: ReferenceColors.border,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (band.locked)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          ReferenceArt(_scoreLock, width: 35, height: 48),
                          SizedBox(width: 18),
                          Expanded(
                            child: Text(
                              'Course content at this Score range is not yet available.',
                              style: TextStyle(
                                fontSize: 18,
                                color: ReferenceColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 18,
                        color: ReferenceColors.muted,
                        height: 1.45,
                      ),
                      children: [
                        TextSpan(
                          text: currentBand
                              ? 'You are currently learning content aligned with the '
                              : 'Content between ${band.label} ${band.locked ? 'will align' : 'aligns'} with the ',
                        ),
                        TextSpan(
                          text: band.cefr,
                          style: const TextStyle(
                            color: ReferenceColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: band.locked
                              ? ' levels of CEFR.'
                              : ' level of CEFR.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'In real life this means ${band.description.toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: ReferenceColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (var i = 0; i < band.examples.length; i++)
                    _ExampleBubble(
                      index: i,
                      example: band.examples[i],
                      playing: state.playingExample == i,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, int score) {
    _controller.resetCopyFeedback();
    return showDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(scoreInformationProvider);
          return AlertDialog(
            scrollable: true,
            actionsOverflowDirection: VerticalDirection.down,
            title: const Text('Share English Score'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ReferenceArt(LearningArt.english, width: 52, height: 40),
                const SizedBox(height: 12),
                Text('My English Score is $score.'),
                if (state.copyError)
                  const Text(
                    'Couldn’t copy. Try again.',
                    style: TextStyle(color: Colors.red),
                  ),
                if (state.copied)
                  const Text(
                    'Copied',
                    style: TextStyle(color: LearningColors.green),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: state.copyBusy
                    ? null
                    : () => ref
                          .read(scoreInformationProvider.notifier)
                          .copyScore(score),
                child: const Text('COPY'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExampleBubble extends ConsumerWidget {
  const _ExampleBubble({
    required this.index,
    required this.example,
    required this.playing,
  });
  final int index;
  final ScoreExample example;
  final bool playing;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReferenceArt(
          _portraits[index % _portraits.length],
          width: 42,
          height:
              42 *
              _portraits[index % _portraits.length].source.height /
              _portraits[index % _portraits.length].source.width,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomPaint(
            painter: const _ScoreBubblePainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: playing ? 'Stop example' : 'Play example',
                    onPressed: () =>
                        ref.read(scoreInformationProvider.notifier).play(index),
                    icon: Icon(
                      playing ? Icons.stop_circle : Icons.volume_up_rounded,
                      color: LearningColors.blue,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          example.english,
                          style: const TextStyle(
                            fontSize: 18,
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dashed,
                            decorationColor: ReferenceColors.disabled,
                            decorationThickness: 1.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          example.vietnamese,
                          style: const TextStyle(
                            fontSize: 17,
                            color: ReferenceColors.disabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScoreBubblePainter extends CustomPainter {
  const _ScoreBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const left = 12.0;
    const radius = 12.0;
    final right = size.width - 1;
    final bottom = size.height - 1;
    final outline = Path()
      ..moveTo(left + radius, 1)
      ..lineTo(right - radius, 1)
      ..quadraticBezierTo(right, 1, right, radius + 1)
      ..lineTo(right, bottom - radius)
      ..quadraticBezierTo(right, bottom, right - radius, bottom)
      ..lineTo(left + radius, bottom)
      ..quadraticBezierTo(left, bottom, left, bottom - radius)
      ..lineTo(left, 39)
      ..lineTo(2, 39)
      ..quadraticBezierTo(0, 39, 2, 36)
      ..lineTo(left, 22)
      ..lineTo(left, radius + 1)
      ..quadraticBezierTo(left, 1, left + radius, 1)
      ..close();
    canvas.drawPath(outline, Paint()..color = Colors.white);
    canvas.drawPath(
      outline,
      Paint()
        ..color = ReferenceColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreBubblePainter oldDelegate) => false;
}
