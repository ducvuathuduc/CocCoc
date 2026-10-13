import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/presentation/streak_screen.dart'
    show StreakArt, streakBlue, streakGray, streakOrange;
import '../application/streak_repair_controller.dart';
import '../domain/streak_repair.dart';

/// Streak repair (audit row 13). No Gummble capture exists, so this is
/// derived from the app's streak screen: the streak flame (greyed while the
/// streak is lost), the streak-orange count, a blue gem CTA and NO THANKS.
class StreakRepairScreen extends ConsumerWidget {
  const StreakRepairScreen({super.key});
  static const route = '/streak/repair';

  // Luminance-weighted greyscale for the lost flame (no new colour).
  static const _grey = ColorFilter.matrix([
    .2126, .7152, .0722, 0, 0, //
    .2126, .7152, .0722, 0, 0, //
    .2126, .7152, .0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(streakRepairControllerProvider);
    final content = ref.watch(streakRepairContentProvider);
    final offer = state.offer;
    final repaired = state.repaired;
    final days = state.repairedDays ?? offer?.lostDays ?? 0;
    final controller = ref.read(streakRepairControllerProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: content.closeLabel,
                onPressed: () => _close(context),
                icon: const Icon(
                  Icons.close,
                  size: 30,
                  color: ReferenceColors.disabled,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          key: ValueKey(repaired),
                          tween: Tween(
                            begin: MediaQuery.disableAnimationsOf(context)
                                ? 1
                                : .7,
                            end: 1,
                          ),
                          duration: motionDuration(context, 300),
                          curve: Curves.easeOutBack,
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: repaired
                              ? const ReferenceArt(
                                  StreakArt.perfect,
                                  width: 112,
                                  height: 140,
                                )
                              : const ColorFiltered(
                                  colorFilter: _grey,
                                  child: ReferenceArt(
                                    StreakArt.perfect,
                                    width: 112,
                                    height: 140,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$days',
                          key: const ValueKey('streak-repair-days'),
                          style: TextStyle(
                            fontSize: 64,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: repaired ? streakOrange : streakGray,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          repaired
                              ? content.repairedTitle(days)
                              : content.lostTitle,
                          textAlign: TextAlign.center,
                          style: headingStyle.copyWith(
                            color: ReferenceColors.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          repaired
                              ? content.repairedBody
                              : content.lostBody(days),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: ReferenceColors.muted,
                          ),
                        ),
                        if (!repaired && offer != null) ...[
                          const SizedBox(height: 24),
                          LearningCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: streakOrange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    content.expiresLabel,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      color: ReferenceColors.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  content.countdown(offer.expiresIn),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: streakOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (offer.repairItems > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              '${content.itemsOwnedLabel}: ${offer.repairItems}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: ReferenceColors.muted,
                              ),
                            ),
                          ],
                        ],
                        if (state.error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            state.error!,
                            key: const ValueKey('streak-repair-error'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: LearningColors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: repaired || offer == null
                  ? ReferenceButton(
                      key: const ValueKey('streak-repair-continue'),
                      label: content.continueAction,
                      backgroundColor: streakBlue,
                      edgeColor: LearningColors.blueDark,
                      onPressed: () => _close(context),
                    )
                  : Column(
                      children: [
                        if (offer.repairItems > 0) ...[
                          ReferenceButton(
                            key: const ValueKey('streak-repair-item'),
                            label: content.itemAction,
                            backgroundColor: streakBlue,
                            edgeColor: LearningColors.blueDark,
                            onPressed: state.busy
                                ? null
                                : () => controller.repair(
                                    StreakRepairPayment.item,
                                  ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ReferenceButton(
                          key: const ValueKey('streak-repair-gems'),
                          label: '${content.gemsAction} ${offer.gemCost}',
                          leading: const ReferenceArt(
                            LearningArt.gem,
                            width: 20,
                            height: 24,
                          ),
                          outlined: offer.repairItems > 0,
                          foregroundColor: offer.repairItems > 0
                              ? streakBlue
                              : null,
                          backgroundColor: streakBlue,
                          edgeColor: LearningColors.blueDark,
                          onPressed: state.busy
                              ? null
                              : () =>
                                    controller.repair(StreakRepairPayment.gems),
                        ),
                        TextButton(
                          key: const ValueKey('streak-repair-decline'),
                          onPressed: () => _close(context),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text(
                            content.decline,
                            style: const TextStyle(
                              color: streakBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// Personal-streak banner shown only while a repair offer exists.
class StreakRepairBanner extends ConsumerWidget {
  const StreakRepairBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(streakRepairControllerProvider);
    final offer = state.offer;
    if (offer == null || state.repaired) return const SizedBox.shrink();
    final content = ref.watch(streakRepairContentProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: LearningCard(
        key: const ValueKey('streak-repair-banner'),
        onTap: () => context.push(StreakRepairScreen.route),
        child: Row(
          children: [
            const ColorFiltered(
              colorFilter: StreakRepairScreen._grey,
              child: ReferenceArt(StreakArt.perfect, width: 32, height: 40),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                content.bannerTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ReferenceColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              content.bannerAction,
              style: const TextStyle(
                color: streakBlue,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
