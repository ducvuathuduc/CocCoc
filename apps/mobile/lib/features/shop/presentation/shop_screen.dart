import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/config/app_config.dart';
import 'shop_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/extended_controller.dart';
import '../../progress/application/preview_controller.dart';
import '../../progress/presentation/timer_boost_screen.dart';
import '../../promo/presentation/promo_code_screen.dart';
import '../application/shop_controller.dart';
import '../../xp_boost/application/boost_controller.dart';
import '../../../core/design/reference_widgets.dart';
import '../../progress/domain/preview_state.dart';

import 'shop_visuals.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  bool _promoRoutePending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(shopControllerProvider).hasValue) return;
      ref.read(shopControllerProvider.notifier).refresh();
    });
  }

  void _close() => context.canPop() ? context.pop() : context.go('/home');

  Future<void> _openPromo() async {
    if (_promoRoutePending) return;
    setState(() => _promoRoutePending = true);
    try {
      await context.push<void>(PromoCodeScreen.route);
    } finally {
      if (mounted) setState(() => _promoRoutePending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(shopControllerProvider);
    final state = stateAsync.value;
    if (state == null) {
      return Scaffold(
        backgroundColor: ShopColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _ShopHeader(
                title: 'Shop',
                onClose: _close,
                trailing: const SizedBox(width: 48),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: stateAsync.isLoading
                              ? Semantics(
                                  liveRegion: true,
                                  label: 'Loading Shop',
                                  child: const CircularProgressIndicator(),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Shop unavailable',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: ShopColors.ink,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Check your connection and try again.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: ReferenceColors.muted,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: 200,
                                      child: ReferenceButton(
                                        key: const ValueKey('shop-retry'),
                                        label: 'RETRY',
                                        onPressed: () => ref
                                            .read(
                                              shopControllerProvider.notifier,
                                            )
                                            .refresh(),
                                        backgroundColor: ShopColors.blue,
                                        edgeColor: LearningColors.blueDark,
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
      );
    }
    final max = ref.watch(extendedControllerProvider).isMax;
    final apiMode = ref.watch(appConfigProvider).isApi;
    final wallet = apiMode ? state.wallet : ref.watch(previewWalletProvider);
    final owned = apiMode ? null : ref.watch(previewControllerProvider);
    final freezes = apiMode ? state.freezes : owned!.freezes;
    final timerBoosts = apiMode ? state.timerBoosts : owned!.timerBoosts;

    return Scaffold(
      backgroundColor: ShopColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _ShopHeader(
              title: 'Shop',
              onClose: _close,
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
                  if (max) ...[
                    _buildMaxBanner(context, max),
                    const SizedBox(height: 44),
                  ],
                  _buildSectionTitle('My Items'),
                  const SizedBox(height: 18),
                  _buildMyItems(
                    context,
                    ref,
                    freezes: freezes,
                    timerBoosts: timerBoosts,
                    apiMode: apiMode,
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
                  _buildTimerBoost(context, ref, state, wallet, apiMode),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Streak Freeze'),
                  const SizedBox(height: 18),
                  _buildStreakFreeze(
                    context,
                    ref,
                    wallet,
                    freezes,
                    state.freezeOffer,
                    apiMode,
                  ),
                  const SizedBox(height: 64),
                  _buildSectionTitle('Promo Code'),
                  const SizedBox(height: 18),
                  _buildPromoCode(context),
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

  Widget _buildPromoCode(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        constraints: const BoxConstraints(minHeight: 131),
        padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const ReferenceArt(
              ArtRegion('android-promo-shop', Rect.fromLTWH(34, 631, 78, 78)),
              width: 78,
              height: 78,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Redeem a promo code',
                    style: TextStyle(
                      color: ShopColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter a promo code to earn rewards',
                    style: TextStyle(
                      color: ReferenceColors.muted,
                      fontSize: 15,
                      height: 1.25,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('shop-promo-redeem'),
                    onPressed: _promoRoutePending ? null : _openPromo,
                    style: TextButton.styleFrom(
                      foregroundColor: ShopColors.blue,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 48),
                      alignment: Alignment.centerLeft,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'REDEEM',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    required bool apiMode,
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
                  onTap: apiMode
                      ? null
                      : () => showTimerBoostOffer(context, ref),
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
        ],
      ),
    );
  }

  Widget _buildSpecialOffers(
    BuildContext context,
    WidgetRef ref,
    ShopState state,
    PreviewState? owned,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: state.specialOffers.map((offer) {
          final claimed =
              owned?.claims.contains(
                '${PreviewController.shopClaimPrefix}${offer.id}',
              ) ??
              false;
          final claimable =
              offer.available && offer.actionLabel == 'CLAIM' && !claimed;
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

  Future<void> _claimOffer(
    BuildContext context,
    WidgetRef ref,
    ShopOffer offer,
  ) async {
    final gems = offer.rewardGems!;
    final ok = ref
        .read(previewControllerProvider.notifier)
        .claimShopReward(offer.id, gems);
    if (!ok) return;
    final art = _getArtForOffer(offer.id);
    await learningSheet<void>(
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
    final boost = offer.xpBoost;
    if (boost == null || !context.mounted) return;
    // Friends Chest: gems sheet -> XP Boost activated (sc_269d6ffb).
    final activated = await ref
        .read(boostControllerProvider.notifier)
        .activate(boost);
    if (!context.mounted) return;
    if (activated) {
      context.push('/xp-boost/activated');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(boostCopyProvider).failureMessage)),
      );
    }
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
    bool apiMode,
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
              priceDisabled: !offer.available,
              onAction: !offer.available
                  ? null
                  : () async {
                      final cost = offer.price ?? 0;
                      if (apiMode) {
                        final bought = await ref
                            .read(shopControllerProvider.notifier)
                            .buyItem(offer.id, cost);
                        if (!bought && context.mounted) {
                          showLearningNotice(
                            context,
                            wallet < cost
                                ? 'Not enough gems'
                                : 'Purchase unavailable',
                            wallet < cost
                                ? 'You need $cost gems. Earn gems by finishing lessons and quests.'
                                : 'Please try again.',
                          );
                        }
                        return;
                      }
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
    ShopOffer freezeOffer,
    bool apiMode,
  ) {
    final maxed = freezes >= PreviewController.maxFreezes;
    final cost = apiMode ? freezeOffer.price ?? 0 : 425;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _buildListItem(
        art: ShopArt.streakFreezeItem,
        title: '1-day',
        price: cost,
        priceDisabled: maxed || !freezeOffer.available,
        priceSemantics: maxed
            ? 'Streak Freeze, $freezes of ${PreviewController.maxFreezes} '
                  'equipped. Maximum reached'
            : null,
        onAction: !freezeOffer.available
            ? null
            : () async {
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
                if (wallet >= cost) {
                  if (apiMode) {
                    final bought = await ref
                        .read(shopControllerProvider.notifier)
                        .buyItem(freezeOffer.id, cost);
                    if (!context.mounted) return;
                    if (!bought) {
                      showLearningNotice(
                        context,
                        'Purchase unavailable',
                        'Please try again.',
                      );
                      return;
                    }
                    showLearningNotice(
                      context,
                      'Streak Freeze equipped!',
                      'Your streak freeze is ready.',
                    );
                    return;
                  }
                  final bought = ref
                      .read(previewControllerProvider.notifier)
                      .buyFreeze(
                        'freeze-${DateTime.now().microsecondsSinceEpoch}',
                      );
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

  static const double _actionMaxWidth = 120;

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
                // Duolingo keeps the action hugging the right edge and gives the
                // title the rest of the row (docs/design/references/shop 04-05).
                if (actionLabel != null && title != 'Max Family Plan')
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _actionMaxWidth,
                    ),
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
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _actionMaxWidth,
                    ),
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
