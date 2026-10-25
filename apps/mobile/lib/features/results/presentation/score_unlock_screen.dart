import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/presentation/score_information_screen.dart';

/// Android 6.90.3 capture: BestLanguageApp score-unlock.jpg (640×1360).
/// English flag/copy and score are explicit adaptations to the existing course.
/// This display never awards XP/gems or calculates proficiency.
class ScoreUnlockScreen extends ConsumerStatefulWidget {
  const ScoreUnlockScreen({
    required this.score,
    required this.onContinue,
    super.key,
  });
  final int score;
  final VoidCallback onContinue;
  @override
  ConsumerState<ScoreUnlockScreen> createState() => _ScoreUnlockScreenState();
}

class _ScoreUnlockScreenState extends ConsumerState<ScoreUnlockScreen> {
  bool _actionInFlight = false;

  bool _beginAction() {
    if (_actionInFlight) return false;
    setState(() => _actionInFlight = true);
    return true;
  }

  void _releaseAction() {
    if (mounted) setState(() => _actionInFlight = false);
  }

  void _continue() {
    if (!_beginAction()) return;
    widget.onContinue();
  }

  Future<void> _share() async {
    if (!_beginAction()) return;
    try {
      await showScoreShareDialog(context, ref, widget.score);
    } finally {
      _releaseAction();
    }
  }

  Future<void> _openScoreInformation() async {
    if (!_beginAction()) return;
    try {
      await context.push<void>('/score');
    } finally {
      _releaseAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.sizeOf(context).width / 640).clamp(.45, .75);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, viewport) {
          // Source samples at x=320: y=0 #165DC7, y=650 #338AEB,
          // y=1312 #76D1FD. Mapping the middle stop by source scale keeps
          // the native gradient continuous where the top art crop ends.
          final artTop = MediaQuery.paddingOf(context).top;
          final topStop = (artTop / viewport.maxHeight).clamp(0.0, 1.0);
          final joinStop = ((artTop + 650 * scale) / viewport.maxHeight).clamp(
            0.0,
            1.0,
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Color(0xFF165DC7),
                  Color(0xFF165DC7),
                  Color(0xFF338AEB),
                  Color(0xFF76D1FD),
                ],
                stops: [0, topStop, joinStop, 1],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 945 * scale,
                    child: ReferenceArt(
                      const ArtRegion(
                        'android-score-unlock',
                        Rect.fromLTWH(0, 945, 120, 175),
                      ),
                      width: 120 * scale,
                      height: 175 * scale,
                      blendMode: BlendMode.lighten,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 980 * scale,
                    child: ReferenceArt(
                      const ArtRegion(
                        'android-score-unlock',
                        Rect.fromLTWH(550, 980, 90, 140),
                      ),
                      width: 90 * scale,
                      height: 140 * scale,
                      blendMode: BlendMode.lighten,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (_, box) => SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: box.maxHeight,
                              ),
                              child: Padding(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    ExcludeSemantics(
                                      child: ReferenceArt(
                                        const ArtRegion(
                                          'android-score-unlock',
                                          Rect.fromLTWH(0, 0, 640, 650),
                                        ),
                                        width: 640 * scale,
                                        height: 650 * scale,
                                      ),
                                    ),
                                    SizedBox(height: 40 * scale),
                                    Semantics(
                                      label: 'English Score ${widget.score}',
                                      excludeSemantics: true,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 124 * scale,
                                            height: 102 * scale,
                                            padding: EdgeInsets.all(6 * scale),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    20 * scale,
                                                  ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    14 * scale,
                                                  ),
                                              child: ReferenceArt(
                                                LearningArt.english,
                                                width: 112 * scale,
                                                height: 90 * scale,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 34 * scale),
                                          Text(
                                            '${widget.score}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 124 * scale,
                                              height: 1,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 50 * scale),
                                    Text(
                                      'You unlocked your Duolingo\nEnglish Score!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 34 * scale,
                                        height: 1.4,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24 * scale,
                          12,
                          24 * scale,
                          30 * scale,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: (74 * scale).clamp(
                                    44,
                                    double.infinity,
                                  ),
                                  child: IconButton.filled(
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: LearningColors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    tooltip: 'Share English Score',
                                    onPressed: _actionInFlight ? null : _share,
                                    icon: const Icon(Icons.ios_share_outlined),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ReferenceButton(
                                    label: 'CONTINUE',
                                    onPressed: _actionInFlight
                                        ? null
                                        : _continue,
                                    minHeight: 44,
                                    backgroundColor: Colors.white,
                                    edgeColor: Colors.white70,
                                    foregroundColor: LearningColors.blue,
                                    textStyle: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: _actionInFlight
                                  ? null
                                  : _openScoreInformation,
                              child: const Text(
                                'MORE ABOUT SCORE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
