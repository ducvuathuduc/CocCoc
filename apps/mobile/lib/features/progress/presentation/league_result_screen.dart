import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/league_result_controller.dart';
import '../domain/league_result.dart';

const _resultTrophies = ArtRegion(
  'league-result-source',
  Rect.fromLTWH(430, 230, 590, 475),
);
const _resultMedal = ArtRegion(
  'league-result-source',
  Rect.fromLTWH(75, 930, 105, 125),
);
const _silverPromotion = ArtRegion(
  'league-promotion-source',
  Rect.fromLTWH(0, 175, 1179, 1010),
);
const _diamondPromotion = ArtRegion(
  'league-05',
  Rect.fromLTWH(370, 360, 360, 400),
);
const _rewardChest = ArtRegion(
  'league-reward-source',
  Rect.fromLTWH(300, 670, 580, 650),
);

class LeagueResultScreen extends ConsumerStatefulWidget {
  const LeagueResultScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  ConsumerState<LeagueResultScreen> createState() => _LeagueResultScreenState();
}

class _LeagueResultScreenState extends ConsumerState<LeagueResultScreen> {
  bool _finishDelivered = false;

  void _finish() {
    if (_finishDelivered) return;
    _finishDelivered = true;
    widget.onFinished();
  }

  void _advance() {
    final completed = ref
        .read(leagueResultControllerProvider.notifier)
        .advance();
    if (completed) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leagueResultControllerProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: motionDuration(context, 220),
                  child: _stage(state),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: _finish,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: ReferenceColors.disabled,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage(LeagueResultState state) => switch (state.stage) {
    LeagueResultStage.result => _ResultStep(
      key: const ValueKey('league-result'),
      fixture: state.fixture!,
      onContinue: _advance,
    ),
    LeagueResultStage.promotion => _PromotionStep(
      key: const ValueKey('league-promotion'),
      fixture: state.fixture!,
      onContinue: _advance,
    ),
    LeagueResultStage.reward => _RewardStep(
      key: const ValueKey('league-reward'),
      gems: state.fixture!.rewardGems,
      onContinue: _advance,
    ),
    LeagueResultStage.complete => const SizedBox(
      key: ValueKey('league-complete'),
    ),
  };
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({
    required this.storageKey,
    required this.children,
    required this.onContinue,
  });

  final PageStorageKey<String> storageKey;
  final List<Widget> children;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: storageKey,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 84),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...children, const Spacer()],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ReferenceButton(
            label: 'CONTINUE',
            backgroundColor: LearningColors.blue,
            edgeColor: LearningColors.blueDark,
            onPressed: onContinue,
          ),
        ),
      ],
    ),
  );
}

class _ResultStep extends StatelessWidget {
  const _ResultStep({
    required this.fixture,
    required this.onContinue,
    super.key,
  });

  final LeagueResultFixture fixture;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final learner = fixture.learner;
    final diamond = fixture.currentTier == LeagueTier.diamond;
    final roomy =
        MediaQuery.sizeOf(context).height >= 760 &&
        MediaQuery.textScalerOf(context).scale(16) <= 21;
    return _StepScroll(
      storageKey: const PageStorageKey('league-result-history'),
      onContinue: onContinue,
      children: [
        const SizedBox(height: 12),
        Center(
          child: ReferenceArt(
            diamond ? _diamondPromotion : _resultTrophies,
            width: diamond ? 205 : 220,
            height: diamond ? 205 : 177,
          ),
        ),
        if (fixture.eventLabel case final event?) ...[
          const SizedBox(height: 12),
          Text(
            event,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReferenceColors.purple,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 22),
        Text(
          'You finished #${learner.rank} last week!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ReferenceColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          key: const ValueKey('league-result-card'),
          constraints: BoxConstraints(minHeight: roomy ? 370 : 164),
          decoration: BoxDecoration(
            border: Border.all(color: ReferenceColors.border, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final entry in fixture.entries) _ResultRow(entry: entry),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.entry});

  final LeagueResultEntry entry;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(19) > 28;
    final name = Text(
      entry.name,
      style: const TextStyle(
        color: Color(0xFFE6A400),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
    final xp = Text(
      '${entry.xp} XP',
      style: const TextStyle(color: Color(0xFFE6A400), fontSize: 19),
    );
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Rank ${entry.rank}, ${entry.name}, ${entry.xp} XP',
      child: Container(
        color: entry.isLearner ? const Color(0xFFFFF3A6) : Colors.white,
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (entry.rank == 1)
              const ReferenceArt(_resultMedal, width: 34, height: 40)
            else
              SizedBox(
                width: 34,
                child: Text(
                  '${entry.rank}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ReferenceColors.green,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [name, xp],
                    )
                  : name,
            ),
            if (!stacked) const SizedBox(width: 10),
            if (!stacked) xp,
          ],
        ),
      ),
    );
  }
}

class _PromotionStep extends StatelessWidget {
  const _PromotionStep({
    required this.fixture,
    required this.onContinue,
    super.key,
  });

  final LeagueResultFixture fixture;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final diamond = fixture.currentTier == LeagueTier.diamond;
    return _StepScroll(
      storageKey: const PageStorageKey('league-result-promotion'),
      onContinue: onContinue,
      children: [
        Center(
          child: ReferenceArt(
            diamond ? _diamondPromotion : _silverPromotion,
            width: diamond ? 250 : 360,
            height: diamond ? 278 : 360 * 1010 / 1179,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Congratulations! You were promoted to this week's "
          '${fixture.currentTier.label} League.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ReferenceColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _RewardStep extends StatelessWidget {
  const _RewardStep({required this.gems, required this.onContinue, super.key});

  final int gems;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => _StepScroll(
    storageKey: const PageStorageKey('league-result-reward'),
    onContinue: onContinue,
    children: [
      const SizedBox(height: 70),
      Text(
        '+$gems gems',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: LearningColors.blue,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 34),
      const Center(child: ReferenceArt(_rewardChest, width: 250, height: 280)),
      const SizedBox(height: 30),
      Text(
        'You earned $gems gems! Keep finishing in the top 3 to win rewards.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: ReferenceColors.ink,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    ],
  );
}
