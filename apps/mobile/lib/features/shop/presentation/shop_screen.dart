import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import 'shop_widgets.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/extended_controller.dart';
import '../../progress/application/preview_controller.dart';
import 'shop_visuals.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(previewControllerProvider);
    final wallet = ref.watch(previewWalletProvider);
    final max = ref.watch(extendedControllerProvider).isMax;

    return Scaffold(
      backgroundColor: ShopColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _ShopHeader(
              title: 'Shop',
              onClose: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ReferenceArt(LearningArt.gem, width: 24, height: 28),
                  const SizedBox(width: 8),
                  Text(
                    '$wallet',
                    style: const TextStyle(
                      color: ShopColors.blue,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 14, bottom: 24),
                children: [
                  _buildMaxBanner(context, max),
                  const SizedBox(height: 44),
                  _buildSectionTitle('My Items'),
                  const SizedBox(height: 18),
                  _buildMyItems(context, p),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Subscriptions'),
                  const SizedBox(height: 18),
                  _buildSubscriptions(),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Special Offers'),
                  const SizedBox(height: 18),
                  _buildSpecialOffers(),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Timer Boost'),
                  const SizedBox(height: 18),
                  _buildTimerBoost(context, ref, wallet),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Streak Freeze'),
                  const SizedBox(height: 18),
                  _buildStreakFreeze(context, ref, p, wallet),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 27,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: ShopColors.ink,
        ),
      ),
    );
  }

  Widget _buildMaxBanner(BuildContext context, bool max) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ReferenceArt(
                        ShopArt.maxLogo,
                        width: 74.4,
                        height: 26.3,
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Thanks for being a\nDuolingo Max subscriber!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                ReferenceArt(
                  ShopArt.maxBanner,
                  width: ShopArt.maxBanner.source.width / 3,
                  height: ShopArt.maxBanner.source.height / 3,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ShopManageButton(
              onPressed: () => context.push(max ? '/max/tour' : '/max'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyItems(BuildContext context, dynamic p) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMyItemCard(
              ShopArt.xpBoost,
              'XP Boost',
              '10M LEFT',
              const Color(0xFFFF9600),
            ),
            const SizedBox(width: 10.9),
            _buildMyItemCard(
              ShopArt.streakFreeze,
              'Streak Freeze',
              'x${p.freezes}',
              ShopColors.blue,
            ),
            const SizedBox(width: 10.9),
            _buildMyItemCard(
              ShopArt.timerBoostMyItem,
              'Timer Boost',
              'x${p.timerBoosts}',
              ShopColors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyItemCard(
    ArtRegion art,
    String title,
    String subtitle,
    Color subtitleColor,
  ) {
    return Container(
      width: 163.4,
      constraints: const BoxConstraints(minHeight: 190.7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          top: BorderSide(color: ShopColors.border, width: 2.2),
          left: BorderSide(color: ShopColors.border, width: 2.2),
          right: BorderSide(color: ShopColors.border, width: 2.2),
          bottom: BorderSide(color: ShopColors.border, width: 4.4),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ReferenceArt(
            art,
            width: art.source.width / ShopArt.referenceScale,
            height: art.source.height / ShopArt.referenceScale,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: ShopColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (title == 'XP Boost') ...[
                  Icon(Icons.access_time_filled, size: 18, color: subtitleColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _buildListItem(
        art: ShopArt.maxFamilyPlan,
        title: 'Max Family Plan',
        actionLabel: 'UPGRADE',
        actionColor: ShopColors.blue,
        onAction: () {},
      ),
    );
  }

  Widget _buildSpecialOffers() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          _buildListItem(
            art: ShopArt.friendsChest,
            title: 'Friends Chest',
            actionLabel: 'CLAIM',
            actionColor: ShopColors.blue,
            onAction: () {},
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.widgetReward,
            title: 'Widget Reward',
            actionLabel: 'CLAIM',
            actionColor: ShopColors.blue,
            onAction: () {},
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.genshinReward,
            title: 'Genshin Impact\nReward',
            actionLabel: 'CLAIM',
            actionColor: ShopColors.blue,
            onAction: () {},
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.earlyBirdChest,
            title: 'Early Bird Chest',
            actionLabel: 'LOCKED',
            actionColor: ReferenceColors.muted,
            onAction: null,
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.nightOwlChest,
            title: 'Night Owl Chest',
            actionLabel: 'LOCKED',
            actionColor: ReferenceColors.muted,
            onAction: null,
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBoost(BuildContext context, WidgetRef ref, int wallet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          _buildListItem(
            art: ShopArt.timerBoostSingle,
            title: 'Single',
            price: 450,
            onAction: () => ref
                .read(previewControllerProvider.notifier)
                .buyTimerBoost(
                  'timer-single-${DateTime.now().millisecondsSinceEpoch}',
                  1,
                ),
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.timerBoost5Pack,
            title: '5 pack',
            price: 1800,
            popular: true,
            onAction: () => ref
                .read(previewControllerProvider.notifier)
                .buyTimerBoost(
                  'timer-5-${DateTime.now().millisecondsSinceEpoch}',
                  5,
                ),
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.timerBoost15Pack,
            title: '15 pack',
            price: 4500,
            onAction: () => ref
                .read(previewControllerProvider.notifier)
                .buyTimerBoost(
                  'timer-15-${DateTime.now().millisecondsSinceEpoch}',
                  15,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakFreeze(
    BuildContext context,
    WidgetRef ref,
    dynamic p,
    int wallet,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _buildListItem(
        art: ShopArt.streakFreezeItem,
        title: '1-day',
        price: 425,
        onAction: () {
          final bought = ref
              .read(previewControllerProvider.notifier)
              .buyFreeze('freeze-${DateTime.now().millisecondsSinceEpoch}');
          showLearningNotice(
            context,
            bought ? 'Streak Freeze equipped!' : 'Not enough gems',
            bought ? 'Your streak freeze is ready.' : 'You need 425 gems. Earn gems by finishing lessons and quests.',
          );
        },
      ),
    );
  }

  Widget _buildListItem({
    required ArtRegion art,
    required String title,
    String? actionLabel,
    Color? actionColor,
    int? price,
    bool popular = false,
    VoidCallback? onAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          top: BorderSide(color: ShopColors.border, width: 2.2),
          left: BorderSide(color: ShopColors.border, width: 2.2),
          right: BorderSide(color: ShopColors.border, width: 2.2),
          bottom: BorderSide(color: ShopColors.border, width: 4.4),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
            child: Row(
              children: [
                ReferenceArt(
                  art,
                  width: art.source.width / ShopArt.referenceScale,
                  height: art.source.height / ShopArt.referenceScale,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.ink,
                        ),
                      ),
                      if (title == 'Max Family Plan')
                        TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          child: Text(
                            actionLabel!,
                            style: const TextStyle(
                              color: ShopColors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (actionLabel != null && title != 'Max Family Plan')
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: onAction,
                        child: Text(
                          actionLabel,
                          style: TextStyle(
                            fontSize: 18,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: actionColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (price != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: InkWell(
                        onTap: onAction,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const ReferenceArt(
                                LearningArt.gem,
                                width: 20,
                                height: 24,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$price',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: ShopColors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (popular)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 3,
                ),
                decoration: const BoxDecoration(
                  color: ShopColors.blue,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.title,
    required this.onClose,
    required this.trailing,
  });
  final String title;
  final VoidCallback onClose;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ShopColors.border, width: .7)),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                size: 34,
                color: ReferenceColors.disabled,
              ),
            ),
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: ShopColors.ink,
          ),
        ),
        Align(alignment: Alignment.centerRight, child: trailing),
      ],
    ),
  );
}
