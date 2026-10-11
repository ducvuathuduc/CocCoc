import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../../core/design/reward_motion.dart';
import '../application/results_providers.dart';
import '../domain/results_models.dart';
import 'results_theme.dart';
import 'results_widgets.dart';

void _defaultContinue(BuildContext context) => Navigator.of(context).maybePop();

/// results/04 — "+50 gems" chest reward.
class GemRewardScreen extends ConsumerWidget {
  const GemRewardScreen({this.onContinue, super.key});
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(gemRewardResultProvider);
    return ResultsFrame(
      footer: ResultsPrimaryButton(
        label: result.continueLabel,
        onPressed: onContinue ?? () => _defaultContinue(context),
      ),
      body: LessonCelebration(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 134),
              Semantics(
                label: '+${result.gems} ${result.unit}',
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('+', style: _gemsStyle),
                    RewardCount(value: result.gems, style: _gemsStyle),
                    Text(' ${result.unit}', style: _gemsStyle),
                  ],
                ),
              ),
              const SizedBox(height: 56),
              const BounceIn(
                delayMs: 120,
                child: ReferenceArt(
                  ResultsArt.gemChest,
                  width: 205,
                  height: 197,
                ),
              ),
              const SizedBox(height: 45),
              StaggerIn(
                index: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    result.message,
                    textAlign: TextAlign.center,
                    style: resultsHeadline,
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

const _gemsStyle = TextStyle(
  fontSize: 41,
  height: 1.2,
  fontWeight: FontWeight.w700,
  color: ResultsColors.blue,
);

/// results/11 — "+1 Quest Point!" with daily quest progress bars.
class QuestProgressResultScreen extends ConsumerWidget {
  const QuestProgressResultScreen({this.onContinue, super.key});
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(questProgressResultProvider);
    return ResultsFrame(
      footer: ResultsPrimaryButton(
        label: result.continueLabel,
        onPressed: onContinue ?? () => _defaultContinue(context),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
              child: Semantics(
                label: '${result.gemBalance} gems',
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const ReferenceArt(ResultsArt.gem, width: 23, height: 27),
                    const SizedBox(width: 8),
                    Text(
                      '${result.gemBalance}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                        color: ResultsColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 132),
            BounceIn(
              child: Text(
                result.headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 35.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: ResultsColors.quest,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: ResultsColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ResultsColors.border, width: 1.5),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < result.quests.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1.5,
                          thickness: 1.5,
                          color: ResultsColors.divider,
                        ),
                      QuestProgressTile(quest: result.quests[i], index: i + 1),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// results/12 — league standings with the promotion zone.
class LeagueRankResultScreen extends ConsumerStatefulWidget {
  const LeagueRankResultScreen({this.onContinue, super.key});
  final VoidCallback? onContinue;

  @override
  ConsumerState<LeagueRankResultScreen> createState() =>
      _LeagueRankResultScreenState();
}

class _LeagueRankResultScreenState
    extends ConsumerState<LeagueRankResultScreen> {
  // Peeks the last promoted row above the cut line, like the reference.
  final _scroll = ScrollController(initialScrollOffset: 45);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(leagueRankResultProvider);
    final above = result.rows
        .where((row) => row.rank <= result.promotionCutoff)
        .toList();
    final below = result.rows
        .where((row) => row.rank > result.promotionCutoff)
        .toList();
    var index = 0;
    return ResultsFrame(
      bottom: 63,
      footer: ResultsPrimaryButton(
        label: result.continueLabel,
        onPressed: widget.onContinue ?? () => _defaultContinue(context),
      ),
      body: Column(
        children: [
          const SizedBox(height: 22),
          const BounceIn(
            child: ReferenceArt(ResultsArt.trophy, width: 83, height: 114),
          ),
          const SizedBox(height: 13),
          StaggerIn(
            index: 1,
            child: Text(
              result.message,
              textAlign: TextAlign.center,
              style: resultsHeadline.copyWith(fontSize: 26.3, height: 1.33),
            ),
          ),
          const SizedBox(height: 27),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: ResultsColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ResultsColors.border, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.5),
                  child: ListView(
                    controller: _scroll,
                    // Room so the peek offset never exceeds the scroll extent.
                    padding: const EdgeInsets.only(bottom: 48),
                    children: [
                      for (final row in above)
                        LeagueRankTile(row: row, index: index++),
                      StaggerIn(
                        index: index++,
                        child: Semantics(
                          header: true,
                          child: SizedBox(
                            height: 61,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const ReferenceArt(
                                  ResultsArt.promotionArrow,
                                  width: 20,
                                  height: 19,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      result.promotionLabel,
                                      style: const TextStyle(
                                        fontSize: 21.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.1,
                                        color: ResultsColors.promotion,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const ReferenceArt(
                                  ResultsArt.promotionArrow,
                                  width: 20,
                                  height: 19,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (final row in below)
                        LeagueRankTile(row: row, index: index++),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

/// results/05 — streak extended takeover on orange.
class StreakExtendedScreen extends ConsumerWidget {
  const StreakExtendedScreen({this.onContinue, this.onShare, super.key});
  final VoidCallback? onContinue;
  final VoidCallback? onShare;

  void _share(BuildContext context, StreakExtendedResult result) {
    final text = 'I’m on a ${result.days} ${result.title} in CocEnglish!';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text('Copied: $text')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(streakExtendedResultProvider);
    return ResultsFrame(
      background: ResultsColors.streakBackground,
      bottom: 56,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReferenceButton(
            label: result.shareLabel,
            minHeight: 48,
            backgroundColor: ResultsColors.streakWhite,
            edgeColor: ResultsColors.streakShareEdge,
            foregroundColor: ResultsColors.streakCheck,
            textStyle: const TextStyle(fontSize: 18),
            leading: const ReferenceArt(
              ResultsArt.shareChest,
              width: 24,
              height: 23,
            ),
            onPressed: onShare ?? () => _share(context, result),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: TextButton(
              onPressed: onContinue ?? () => _defaultContinue(context),
              style: TextButton.styleFrom(
                foregroundColor: ResultsColors.streakWhite,
                textStyle: const TextStyle(
                  fontFamily: 'DuolingoSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
              child: Text(result.continueLabel),
            ),
          ),
        ],
      ),
      body: LessonCelebration(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 81),
              const BounceIn(
                child: ReferenceArt(
                  ResultsArt.flameDuo,
                  width: 174,
                  height: 197,
                ),
              ),
              const SizedBox(height: 13),
              Semantics(
                label: 'Streak, ${result.days} days',
                excludeSemantics: true,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ResultsColors.streakNumeralTop,
                      ResultsColors.streakDone,
                    ],
                  ).createShader(bounds),
                  child: RewardCount(
                    value: result.days,
                    style: const TextStyle(
                      fontSize: 146,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: ResultsColors.streakDone,
                    ),
                  ),
                ),
              ),
              Text(
                result.title,
                style: const TextStyle(
                  fontSize: 35.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: ResultsColors.streakWhite,
                ),
              ),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.only(left: 30, right: 31),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < result.week.length; i++)
                      StaggerIn(
                        index: i + 2,
                        offset: const Offset(0, 14),
                        child: _StreakDay(day: result.week[i]),
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

class _StreakDay extends StatelessWidget {
  const _StreakDay({required this.day});
  final ResultDay day;

  @override
  Widget build(BuildContext context) {
    final fill = switch (day.state) {
      ResultDayState.practiced => ResultsColors.streakDone,
      ResultDayState.today => ResultsColors.streakWhite,
      ResultDayState.missed => ResultsColors.streakMissed,
    };
    return Semantics(
      label:
          '${day.label}, ${day.state == ResultDayState.missed ? 'not practiced' : 'practiced'}',
      excludeSemantics: true,
      child: SizedBox(
        width: 42,
        child: Column(
          children: [
            Text(
              day.label,
              style: const TextStyle(
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w700,
                color: ResultsColors.streakNumeralTop,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: day.state == ResultDayState.missed
                  ? null
                  : const Icon(
                      Icons.check_rounded,
                      size: 27,
                      color: ResultsColors.streakCheck,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
