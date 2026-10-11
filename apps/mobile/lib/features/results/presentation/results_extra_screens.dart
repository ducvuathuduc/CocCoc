import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reward_motion.dart';
import '../application/results_providers.dart';
import '../domain/results_models.dart';
import 'results_theme.dart';
import 'results_widgets.dart';

/// Reference px (1180 wide) to logical px at the 430 design width.
const _refScale = 430 / 1180;

void _defaultContinue(BuildContext context) => Navigator.of(context).maybePop();

const _orangeTitle = TextStyle(
  fontSize: 39.5,
  height: 1.12,
  fontWeight: FontWeight.w700,
  color: ResultsColors.orange,
);

/// results/07 — streak goal challenge with Duo and the 7-day calendar.
class StreakGoalScreen extends ConsumerWidget {
  const StreakGoalScreen({this.onContinue, super.key});
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(streakGoalResultProvider);
    if (result == null) return const SizedBox.shrink();
    return ResultsFrame(
      footer: ResultsPrimaryButton(
        label: result.continueLabel,
        onPressed: onContinue ?? () => _defaultContinue(context),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 174),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 51),
                child: StaggerIn(
                  index: 0,
                  child: SizedBox(
                    width: 329,
                    child: Semantics(
                      label: result.message.replaceAll('\n', ' '),
                      excludeSemantics: true,
                      child: ResultsSpeechBubble(text: result.message),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 17),
            Semantics(
              label: '${result.goalDays} day streak goal',
              image: true,
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 86),
                  child: BounceIn(
                    delayMs: 160,
                    child: ReferenceArt(
                      ResultsArt.streakGoal,
                      width: 285.7,
                      height: 269,
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

/// results/08 — widget artwork unlocked by the streak.
class WidgetUnlockScreen extends ConsumerWidget {
  const WidgetUnlockScreen({this.onContinue, super.key});
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(widgetUnlockResultProvider);
    if (result == null) return const SizedBox.shrink();
    Widget card(StreakWidgetCard card, int index) {
      final art = ResultsArt.widgetCards[card.state]!;
      final child = ReferenceArt(
        art,
        width: art.source.width * _refScale,
        height: art.source.height * _refScale,
      );
      return Semantics(
        label:
            '${card.days} day widget${card.state == WidgetCardState.current ? ', unlocked' : ''}',
        excludeSemantics: true,
        child: card.state == WidgetCardState.current
            ? BounceIn(delayMs: 120, child: child)
            : StaggerIn(
                index: index + 2,
                offset: Offset(index == 0 ? -30 : 30, 0),
                child: child,
              ),
      );
    }

    final cards = {for (final c in result.cards) c.state: c};
    return ResultsFrame(
      footer: ResultsPrimaryButton(
        label: result.continueLabel,
        onPressed: onContinue ?? () => _defaultContinue(context),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 193),
            StaggerIn(
              index: 0,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: result.lead),
                    TextSpan(
                      text: result.highlight,
                      style: const TextStyle(color: ResultsColors.blue),
                    ),
                    TextSpan(text: result.tail),
                  ],
                ),
                textAlign: TextAlign.center,
                style: resultsHeadline.copyWith(fontSize: 26.6, height: 1.32),
              ),
            ),
            const SizedBox(height: 92),
            SizedBox(
              height: 192,
              width: 430,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (cards[WidgetCardState.previous] case final c?)
                    Positioned(left: 0, top: 15.7, child: card(c, 0)),
                  if (cards[WidgetCardState.current] case final c?)
                    Positioned(left: 119.5, top: 0, child: card(c, 1)),
                  if (cards[WidgetCardState.next] case final c?)
                    Positioned(right: 0, top: 16, child: card(c, 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// results/09 — friend streak kept with a friend.
class FriendStreakResultScreen extends ConsumerWidget {
  const FriendStreakResultScreen({this.onContinue, super.key});
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(friendStreakResultProvider);
    if (result == null) return const SizedBox.shrink();
    return ResultsFrame(
      footer: ResultsPrimaryButton(
        label: result.continueLabel,
        onPressed: onContinue ?? () => _defaultContinue(context),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 176),
            StaggerIn(
              index: 0,
              child: Text(
                result.title,
                textAlign: TextAlign.center,
                style: _orangeTitle,
              ),
            ),
            const SizedBox(height: 101),
            Semantics(
              label: 'You and ${result.friendName}',
              image: true,
              child: const BounceIn(
                delayMs: 120,
                child: ReferenceArt(
                  ResultsArt.friendAvatars,
                  width: 213.6,
                  height: 126.5,
                ),
              ),
            ),
            const SizedBox(height: 25),
            StaggerIn(
              index: 3,
              child: Semantics(
                label: '${result.days} day friend streak',
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ReferenceArt(
                      ResultsArt.friendFlame,
                      width: 37.2,
                      height: 29.9,
                    ),
                    const SizedBox(width: 11),
                    RewardCount(
                      value: result.days,
                      style: const TextStyle(
                        fontSize: 33,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: ResultsColors.orange,
                      ),
                    ),
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

/// results/10 — Friends Quest progress with the XP boost offer.
class FriendsQuestResultScreen extends ConsumerWidget {
  const FriendsQuestResultScreen({this.onContinue, this.onBoost, super.key});
  final VoidCallback? onContinue;

  /// Sending a boost spends gems; the server confirms it. Defaults to continue.
  final VoidCallback? onBoost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(friendsQuestResultProvider);
    if (result == null) return const SizedBox.shrink();
    final next = onContinue ?? () => _defaultContinue(context);
    return ResultsFrame(
      bottom: 58,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: '${result.boostLabel}, ${result.boostCost} gems',
            excludeSemantics: true,
            child: ResultsPrimaryButton(
              label: result.boostLabel,
              onPressed: onBoost ?? next,
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(result.boostLabel),
                  const SizedBox(width: 13),
                  const ReferenceArt(
                    ResultsArt.boostGem,
                    width: 18.2,
                    height: 21.9,
                  ),
                  const SizedBox(width: 8),
                  Text('${result.boostCost}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ResultsLinkButton(label: result.laterLabel, onPressed: next),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 19, 0),
              child: Semantics(
                label: '${result.gemBalance} gems',
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const ReferenceArt(
                      ResultsArt.friendsQuestGem,
                      width: 19.7,
                      height: 29.2,
                    ),
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
            const SizedBox(height: 44),
            BounceIn(
              child: SizedBox(
                width: 321.4,
                height: 432.6,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ReferenceArt(
                        ResultsArt.friendsQuest,
                        width: 321.4,
                        height: 432.6,
                      ),
                    ),
                    Positioned(
                      left: 23.7,
                      top: 386.3,
                      width: 274.4,
                      height: 27,
                      child: FriendsQuestBar(
                        fraction: result.fraction,
                        label: '${result.current} / ${result.target}',
                        delayMs: 300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 21),
            StaggerIn(
              index: 3,
              child: Text(
                result.message,
                textAlign: TextAlign.center,
                style: resultsHeadline.copyWith(fontSize: 26.8, height: 1.31),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// results/13 — the path the learner lands on after the result chain.
class PathReturnScreen extends ConsumerWidget {
  const PathReturnScreen({this.onOpenPath, super.key});
  final VoidCallback? onOpenPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(pathReturnResultProvider);
    const statStyle = TextStyle(
      fontSize: 17,
      height: 1,
      fontWeight: FontWeight.w700,
      letterSpacing: .4,
    );
    Widget stat(double left, ArtRegion art, double width, Widget? label) =>
        Positioned(
          left: left,
          top: 0,
          height: 27,
          child: Row(
            children: [
              ReferenceArt(art, width: width, height: 27),
              if (label != null) ...[const SizedBox(width: 8), label],
            ],
          ),
        );
    return Scaffold(
      backgroundColor: ResultsColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 19),
            StaggerIn(
              index: 0,
              offset: const Offset(0, -12),
              child: SizedBox(
                height: 27,
                width: 430,
                child: Stack(
                  children: [
                    stat(
                      27.7,
                      ResultsArt.statFlag,
                      33.5,
                      Text(
                        '${result.courseLevel}',
                        style: statStyle.copyWith(color: ResultsColors.ink),
                      ),
                    ),
                    stat(
                      138.1,
                      ResultsArt.statFlame,
                      22.6,
                      Text(
                        '${result.streak}',
                        style: statStyle.copyWith(color: ResultsColors.orange),
                      ),
                    ),
                    stat(
                      226.3,
                      ResultsArt.statGem,
                      21.9,
                      RewardCount(
                        value: result.gems,
                        style: statStyle.copyWith(color: ResultsColors.blue),
                      ),
                    ),
                    stat(333.1, ResultsArt.statEnergy, 59, null),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            StaggerIn(
              index: 1,
              child: GestureDetector(
                onTap: onOpenPath,
                child: Container(
                  width: 377.6,
                  constraints: const BoxConstraints(minHeight: 110),
                  decoration: BoxDecoration(
                    color: ResultsColors.blue,
                    borderRadius: BorderRadius.circular(14),
                    border: const Border(
                      bottom: BorderSide(
                        color: ResultsColors.bannerEdge,
                        width: 4,
                      ),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(15, 13, 8, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.sectionLabel,
                                  style: const TextStyle(
                                    fontSize: 15.2,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .9,
                                    color: ResultsColors.questBarText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  result.unitTitle,
                                  style: const TextStyle(
                                    fontSize: 20.5,
                                    height: 1.27,
                                    fontWeight: FontWeight.w700,
                                    color: ResultsColors.questBarText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 2, color: ResultsColors.bannerDivider),
                        const ReferenceArt(
                          ResultsArt.bannerGuide,
                          width: 51,
                          height: 91,
                        ),
                        const SizedBox(width: 7),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10.6),
            Expanded(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: StaggerIn(
                  index: 2,
                  child: Semantics(
                    label: 'Learning path',
                    image: true,
                    child: const ReferenceArt(
                      ResultsArt.path,
                      width: 430,
                      height: 585.3,
                    ),
                  ),
                ),
              ),
            ),
            Container(height: 2, color: ResultsColors.navDivider),
            const SizedBox(height: 8.7),
            const ReferenceArt(ResultsArt.nav, width: 430, height: 65.6),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
