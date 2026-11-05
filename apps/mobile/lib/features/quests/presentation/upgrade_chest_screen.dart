import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../domain/upgrade_chest.dart';

Future<void> showUpgradeChest(
  BuildContext context,
  UpgradeChestReward reward,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 160),
  pageBuilder: (_, _, _) => UpgradeChestScreen(reward: reward),
  transitionBuilder: (_, a, _, child) =>
      FadeTransition(opacity: a, child: child),
);

/// Common geometry/art: archived Android loot-chest.jpg. Rare/Epic art and
/// color are explicitly cross-platform adaptations from the linked 60fps clip.
/// The receipt is immutable; taps reveal its results and never mint currency.
class UpgradeChestScreen extends StatefulWidget {
  const UpgradeChestScreen({super.key, required this.reward});
  final UpgradeChestReward reward;
  @override
  State<UpgradeChestScreen> createState() => _UpgradeChestScreenState();
}

class _UpgradeChestScreenState extends State<UpgradeChestScreen>
    with TickerProviderStateMixin {
  late final progress = UpgradeChestProgress(widget.reward);
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool busy = false;
  bool rewardVisible = false;
  late final reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  Future<void> tap() async {
    if (busy || progress.revealed) return;
    setState(() {
      busy = true;
      progress.tap();
    });
    final animated =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animated) {
      await motion.forward(from: 0).orCancel.catchError((Object _) {});
    }
    if (!mounted) return;
    if (progress.revealed) {
      setState(() => rewardVisible = true);
      if (animated) {
        await reveal.forward().orCancel.catchError((Object _) {});
      } else {
        reveal.value = 1;
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    motion.dispose();
    reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rarity = progress.rarity;
    final background = rarity == ChestRarity.mega && !rewardVisible
        ? const Color(0xFFF19B36)
        : rewardVisible || rarity == ChestRarity.common
        ? Colors.white
        : rarity == ChestRarity.rare
        ? const Color(0xFF42B8FF)
        : const Color(0xFF935EEF);
    final ink = rarity == ChestRarity.common
        ? const Color(0xFFCF7D00)
        : Colors.white;
    final art = switch (rarity) {
      ChestRarity.common => const ArtRegion(
        'android-chest-common',
        Rect.fromLTWH(40, 380, 540, 350),
      ),
      ChestRarity.rare => const ArtRegion(
        'chest-rare-source',
        Rect.fromLTWH(760, 820, 680, 460),
      ),
      ChestRarity.mega => const ArtRegion(
        'chest-mega-source',
        Rect.fromLTWH(70, 680, 740, 490),
      ),
      ChestRarity.epic => const ArtRegion(
        'chest-epic-source',
        Rect.fromLTWH(760, 820, 680, 460),
      ),
    };
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        key: const ValueKey('upgrade-chest-screen'),
        backgroundColor: background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                  constraints.maxHeight < 620;
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        height: math.max(
                          compact ? 540 : constraints.maxHeight - 90,
                          540,
                        ),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([motion, reveal]),
                          builder: (_, _) {
                            final t = motion.value;
                            return Column(
                              children: [
                                SizedBox(
                                  height: compact
                                      ? 28
                                      : constraints.maxHeight * .19,
                                ),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    rewardVisible
                                        ? '+${widget.reward.gems} gems'
                                        : rarity.name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 25,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color: rewardVisible
                                          ? const Color(0xFF1CB0F6)
                                          : ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 35),
                                Expanded(
                                  child: Center(
                                    child: Semantics(
                                      button: !rewardVisible,
                                      label: progress.attempts == 3
                                          ? 'Open chest'
                                          : 'Upgrade chest, ${3 - progress.attempts} chances left',
                                      child: GestureDetector(
                                        key: const ValueKey(
                                          'upgrade-chest-tap',
                                        ),
                                        behavior: HitTestBehavior.opaque,
                                        onTap: busy ? null : tap,
                                        child: SizedBox(
                                          width: 315,
                                          height: 240,
                                          child: Transform.rotate(
                                            angle: busy
                                                ? math.sin(t * math.pi * 6) *
                                                      .06 *
                                                      (1 - t)
                                                : 0,
                                            child: Transform.scale(
                                              scale: busy
                                                  ? 1 +
                                                        math.sin(t * math.pi) *
                                                            .08
                                                  : 1,
                                              child: rewardVisible
                                                  ? FadeTransition(
                                                      opacity: reveal,
                                                      child: SlideTransition(
                                                        position:
                                                            Tween<Offset>(
                                                              begin:
                                                                  const Offset(
                                                                    0,
                                                                    .25,
                                                                  ),
                                                              end: Offset.zero,
                                                            ).animate(
                                                              CurvedAnimation(
                                                                parent: reveal,
                                                                curve: Curves
                                                                    .easeOutBack,
                                                              ),
                                                            ),
                                                        child:
                                                            const ReferenceArt(
                                                              ArtRegion(
                                                                'chest-reward-source',
                                                                Rect.fromLTWH(
                                                                  880,
                                                                  790,
                                                                  420,
                                                                  410,
                                                                ),
                                                              ),
                                                              width: 200,
                                                              height: 195,
                                                            ),
                                                      ),
                                                    )
                                                  : ReferenceArt(
                                                      art,
                                                      width: 304,
                                                      height: 200,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!rewardVisible &&
                                    progress.attempts < 3) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          child: Opacity(
                                            opacity: i == progress.attempts
                                                ? 1
                                                : i < progress.attempts
                                                ? .3
                                                : .33,
                                            child: CircleAvatar(
                                              radius: 16,
                                              backgroundColor:
                                                  rarity == ChestRarity.common
                                                  ? const Color(0xFFCF7D00)
                                                  : Colors.white.withValues(
                                                      alpha: .4,
                                                    ),
                                              child: Icon(
                                                Icons.arrow_upward_rounded,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                ],
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    rewardVisible
                                        ? 'Keep learning to complete more quests!'
                                        : progress.attempts == 3
                                        ? 'Tap to open!'
                                        : progress.attempts == 0
                                        ? 'Tap for a chance to upgrade!'
                                        : progress.attempts == 2
                                        ? '1 chance left!'
                                        : 'Tap! Tap!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          rarity == ChestRarity.common ||
                                              rewardVisible
                                          ? const Color(0xFF4B4B4B)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (rewardVisible)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: ReferenceButton(
                        label: 'CONTINUE',
                        backgroundColor: const Color(0xFF1CB0F6),
                        edgeColor: const Color(0xFF1899D6),
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
