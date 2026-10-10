import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
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
      backgroundColor: ReferenceColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            LearningHeader(
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
                      color: ReferenceColors.blue,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                children: [
                  _buildMaxBanner(context, max),
                  const SizedBox(height: 32),
                  _buildSectionTitle('My Items'),
                  const SizedBox(height: 16),
                  _buildMyItems(context, p),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Subscriptions'),
                  const SizedBox(height: 16),
                  _buildSubscriptions(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Special Offers'),
                  const SizedBox(height: 16),
                  _buildSpecialOffers(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Timer Boost'),
                  const SizedBox(height: 16),
                  _buildTimerBoost(context, ref, wallet),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Streak Freeze'),
                  const SizedBox(height: 16),
                  _buildStreakFreeze(context, ref, p, wallet),
                  const SizedBox(height: 32),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: ReferenceColors.ink,
        ),
      ),
    );
  }

  Widget _buildMaxBanner(BuildContext context, bool max) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                           border: Border.all(color: const Color(0xFF14DAEB), width: 2),
                           borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('MAX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, height: 1.1)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Thanks for being a\nDuolingo Max subscriber!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ReferenceArt(ShopArt.maxBanner, width: ShopArt.maxBanner.source.width / 3, height: ShopArt.maxBanner.source.height / 3),
              ],
            ),
            const SizedBox(height: 20),
            ReferenceButton(
              label: 'MANAGE FEATURES',
              backgroundColor: const Color(0xFF14DAEB),
              edgeColor: const Color(0xFF119BD8),
              foregroundColor: const Color(0xFF000000),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMyItemCard(ShopArt.xpBoost, 'XP Boost', '10M LEFT', const Color(0xFFFF9600)),
            const SizedBox(width: 12),
            _buildMyItemCard(ShopArt.streakFreeze, 'Streak Freeze', 'x${p.freezes}', ReferenceColors.blue),
            const SizedBox(width: 12),
            _buildMyItemCard(ShopArt.timerBoostMyItem, 'Timer Boost', 'x${p.timerBoosts}', ReferenceColors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildMyItemCard(ArtRegion art, String title, String subtitle, Color subtitleColor) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ReferenceColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReferenceColors.border, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ReferenceArt(art, width: art.source.width / 3, height: art.source.height / 3),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: ReferenceColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: subtitleColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildListItem(
        art: ShopArt.maxFamilyPlan,
        title: 'Max Family Plan',
        actionLabel: 'UPGRADE',
        actionColor: ReferenceColors.blue,
        onAction: () {},
      ),
    );
  }

  Widget _buildSpecialOffers() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildListItem(
            art: ShopArt.friendsChest,
            title: 'Friends Chest',
            actionLabel: 'CLAIM',
            actionColor: ReferenceColors.blue,
            onAction: () {},
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.widgetReward,
            title: 'Widget Reward',
            actionLabel: 'CLAIM',
            actionColor: ReferenceColors.blue,
            onAction: () {},
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.genshinReward,
            title: 'Genshin Impact\nReward',
            actionLabel: 'CLAIM',
            actionColor: ReferenceColors.blue,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildListItem(
            art: ShopArt.timerBoostSingle,
            title: 'Single',
            price: 450,
            onAction: () => ref.read(previewControllerProvider.notifier).buyTimerBoost('timer-single-${DateTime.now().millisecondsSinceEpoch}', 1),
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.timerBoost5Pack,
            title: '5 pack',
            price: 1800,
            popular: true,
            onAction: () => ref.read(previewControllerProvider.notifier).buyTimerBoost('timer-5-${DateTime.now().millisecondsSinceEpoch}', 5),
          ),
          const SizedBox(height: 12),
          _buildListItem(
            art: ShopArt.timerBoost15Pack,
            title: '15 pack',
            price: 4500,
            onAction: () => ref.read(previewControllerProvider.notifier).buyTimerBoost('timer-15-${DateTime.now().millisecondsSinceEpoch}', 15),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakFreeze(BuildContext context, WidgetRef ref, dynamic p, int wallet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              bought
                  ? 'Streak Freeze equipped!'
                  : 'Not enough gems',
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
        color: ReferenceColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: popular ? ReferenceColors.blue : ReferenceColors.border, width: 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ReferenceArt(art, width: art.source.width / 3, height: art.source.height / 3),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ReferenceColors.ink,
                    ),
                  ),
                ),
                if (actionLabel != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: onAction,
                        child: Text(
                          actionLabel,
                          style: TextStyle(
                            fontSize: 16,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const ReferenceArt(LearningArt.gem, width: 20, height: 24),
                              const SizedBox(width: 6),
                              Text(
                                '$price',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: ReferenceColors.blue,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: ReferenceColors.blue,
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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
