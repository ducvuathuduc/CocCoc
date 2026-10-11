import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../gift/presentation/gift_screens.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import 'shop_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/extended_controller.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/presentation/timer_boost_screen.dart';
import '../application/shop_controller.dart';
import '../../../core/design/reference_widgets.dart';
import '../../progress/domain/preview_state.dart';

import 'shop_visuals.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(shopControllerProvider);
    final state = stateAsync.value;
    if (state == null) return const Scaffold();
    final max = ref.watch(extendedControllerProvider).isMax;
    // Balance and owned items come from the app economy (same wallet the
    // Home stats bar shows); the shop repository only supplies the catalog.
    final wallet = ref.watch(previewWalletProvider);
    final owned = ref.watch(previewControllerProvider);

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
                  _buildMyItems(
                    context,
                    ref,
                    freezes: owned.freezes,
                    timerBoosts: owned.timerBoosts,
                  ),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Subscriptions'),
                  const SizedBox(height: 18),
                  _buildSubscriptions(context),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Special Offers'),
                  const SizedBox(height: 18),
                  _buildSpecialOffers(context, ref, state, owned),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Timer Boost'),
                  const SizedBox(height: 18),
                  _buildTimerBoost(context, ref, state, wallet),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Streak Freeze'),
                  const SizedBox(height: 18),
                  _buildStreakFreeze(context, ref, wallet, owned.freezes),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF14DAEB),
                            width: 2.2,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'MAX',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            height: 1.1,
                          ),
                        ),
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

  Widget _buildMyItems(
    BuildContext context,
    WidgetRef ref, {
    required int freezes,
    required int timerBoosts,
  }) {
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
              'x$freezes',
              ShopColors.blue,
            ),
            const SizedBox(width: 10.9),
            // Tapping the owned Timer Boost card opens the pack picker, as the
            // GET entry on the earlier shop did.
            Tooltip(
              message: 'Get Timer Boosts',
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                label: 'Timer Boost, x$timerBoosts. Get more',
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('shop-my-timer-boost'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showTimerBoostOffer(context, ref),
                  child: _buildMyItemCard(
                    ShopArt.timerBoostMyItem,
                    'Timer Boost',
                    'x$timerBoosts',
                    ShopColors.blue,
                  ),
                ),
              ),
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
              fontWeight: FontWeight.w800,
              fontSize: 19,
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
                  Icon(
                    Icons.access_time_filled,
                    size: 18,
                    color: subtitleColor,
                  ),
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

  Widget _buildSubscriptions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          _buildListItem(
            art: ShopArt.maxFamilyPlan,
            title: 'Max Family Plan',
            actionLabel: 'UPGRADE',
            actionColor: ShopColors.blue,
            // Upgrade goes to the existing Family plan picker.
            onAction: () => context.push('/subscription/family'),
          ),
          const SizedBox(height: 18),
          _buildListItem(
            art: GiftArt.duoGift,
            title: 'Gift Super',
            actionLabel: 'GIFT',
            actionColor: ShopColors.blue,
            onAction: () => context.push(GiftRoutes.hub),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialOffers(
    BuildContext context,
    WidgetRef ref,
    ShopState state,
    PreviewState owned,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: state.specialOffers.map((offer) {
          final claimed = owned.claims.contains(
            '${PreviewController.shopClaimPrefix}${offer.id}',
          );
          final claimable = offer.actionLabel == 'CLAIM' && !claimed;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildListItem(
              art: _getArtForOffer(offer.id),
              title: offer.title,
              actionLabel: claimed ? 'CLAIMED' : offer.actionLabel,
              actionColor: claimable ? ShopColors.blue : ReferenceColors.muted,
              onAction: !claimable
                  ? null
                  : offer.id == 'widget-reward'
                  // The widget reward is claimed by adding the streak widget.
                  ? () => context.push('/streak/widgets')
                  : offer.rewardGems == null
                  ? null
                  : () => _claimOffer(context, ref, offer),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _claimOffer(BuildContext context, WidgetRef ref, ShopOffer offer) {
    final gems = offer.rewardGems!;
    final ok = ref
        .read(previewControllerProvider.notifier)
        .claimShopReward(offer.id, gems);
    if (!ok) return;
    final art = _getArtForOffer(offer.id);
    learningSheet<void>(
      context,
      title: 'You earned $gems gems!',
      illustration: ShopRewardReveal(
        art: ReferenceArt(
          art,
          width: art.source.width / ShopArt.referenceScale * 1.6,
          height: art.source.height / ShopArt.referenceScale * 1.6,
        ),
        gem: const ReferenceArt(LearningArt.gem, width: 26, height: 30),
        gems: gems,
      ),
      child: Builder(
        builder: (sheet) => ReferenceButton(
          label: 'CONTINUE',
          backgroundColor: LearningColors.blue,
          edgeColor: LearningColors.blueDark,
          onPressed: () => Navigator.pop(sheet),
        ),
      ),
    );
  }

  ArtRegion _getArtForOffer(String id) {
    switch (id) {
      case 'friends-chest':
        return ShopArt.friendsChest;
      case 'widget-reward':
        return ShopArt.widgetReward;
      case 'genshin-reward':
        return ShopArt.genshinReward;
      case 'early-bird':
        return ShopArt.earlyBirdChest;
      case 'night-owl':
        return ShopArt.nightOwlChest;
      case 'timer-single':
        return ShopArt.timerBoostSingle;
      case 'timer-5':
        return ShopArt.timerBoost5Pack;
      case 'timer-15':
        return ShopArt.timerBoost15Pack;
      default:
        return ShopArt.friendsChest;
    }
  }

  Widget _buildTimerBoost(
    BuildContext context,
    WidgetRef ref,
    ShopState state,
    int wallet,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: state.timerBoostOffers.map((offer) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildListItem(
              art: _getArtForOffer(offer.id),
              title: offer.title,
              price: offer.price,
              popular: offer.popular,
              onAction: () {
                final cost = offer.price ?? 0;
                final pack = _timerBoostPack(offer.id);
                if (wallet >= cost && pack != null) {
                  ref
                      .read(previewControllerProvider.notifier)
                      .buyTimerBoost(
                        'shop-${offer.id}-${DateTime.now().microsecondsSinceEpoch}',
                        pack,
                      );
                } else {
                  showLearningNotice(
                    context,
                    'Not enough gems',
                    'You need $cost gems. Earn gems by finishing lessons and quests.',
                  );
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  static int? _timerBoostPack(String id) => switch (id) {
    'timer-single' => 1,
    'timer-5' => 5,
    'timer-15' => 15,
    _ => null,
  };

  Widget _buildStreakFreeze(
    BuildContext context,
    WidgetRef ref,
    int wallet,
    int freezes,
  ) {
    final maxed = freezes >= PreviewController.maxFreezes;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _buildListItem(
        art: ShopArt.streakFreezeItem,
        title: '1-day',
        price: 425,
        priceDisabled: maxed,
        priceSemantics: maxed
            ? 'Streak Freeze, $freezes of ${PreviewController.maxFreezes} '
                  'equipped. Maximum reached'
            : null,
        onAction: () {
          if (maxed) {
            // Duolingo: no purchase once both freeze slots are full.
            showLearningNotice(
              context,
              'Streak Freeze maxed out',
              'You already have ${PreviewController.maxFreezes} of '
                  '${PreviewController.maxFreezes} Streak Freezes equipped. '
                  'Use one before buying another.',
            );
            return;
          }
          final cost = 425;
          if (wallet >= cost) {
            final bought = ref
                .read(previewControllerProvider.notifier)
                .buyFreeze('freeze-${DateTime.now().microsecondsSinceEpoch}');
            if (!bought) return;
            showLearningNotice(
              context,
              'Streak Freeze equipped!',
              'Your streak freeze is ready.',
            );
          } else {
            showLearningNotice(
              context,
              'Not enough gems',
              'You need $cost gems. Earn gems by finishing lessons and quests.',
            );
          }
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
    bool priceDisabled = false,
    String? priceSemantics,
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
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
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
                      child: Semantics(
                        button: true,
                        enabled: !priceDisabled,
                        label: priceSemantics,
                        child: Opacity(
                          opacity: priceDisabled ? .45 : 1,
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
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: priceDisabled
                                          ? ReferenceColors.disabled
                                          : ShopColors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
