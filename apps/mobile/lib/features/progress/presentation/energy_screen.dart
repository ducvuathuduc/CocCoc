import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../application/energy_controller.dart';
import '../application/preview_controller.dart';
import '../domain/energy_offer.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/extended_controller.dart';
import 'hub_screens.dart';

class EnergyScreen extends ConsumerWidget {
  const EnergyScreen({super.key});

  Future<void> _refill(
    BuildContext context,
    WidgetRef ref,
    EnergyOffer offer, {
    bool adRewarded = false,
  }) async {
    final controller = ref.read(energyControllerProvider.notifier);
    await controller.refill(offer, adRewarded: adRewarded);
    if (!context.mounted || controller.error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(controller.error!),
        action: SnackBarAction(
          label: ref.read(energyRepositoryProvider).retryLabel,
          onPressed: () => _refill(context, ref, offer, adRewarded: adRewarded),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(extendedControllerProvider);
    ref.watch(energyControllerProvider);
    final repository = ref.watch(energyRepositoryProvider);
    final offers = ref.watch(energyOffersProvider);
    final wallet = ref.watch(previewWalletProvider);
    final color = state.unlimited
        ? const Color(0xFFBD4CF5)
        : const Color(0xFFFF80CE);
    return PreviewPage(
      title: 'Energy',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ReferenceArt(LearningArt.gem, width: 22, height: 26),
          const SizedBox(width: 6),
          Text(
            '$wallet',
            style: const TextStyle(
              color: LearningColors.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 25,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      left: 6,
                      right: 6,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        state.unlimited
                            ? '∞'
                            : '${state.energy} / ${repository.capacity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            ReferenceArt(
              const ArtRegion('energy-02', Rect.fromLTWH(977, 350, 160, 110)),
              width: 45,
              height: 31,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: ReferenceColors.border, width: 2),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFB634F6),
                      Color(0xFF4674FF),
                      Color(0xFF20C797),
                    ],
                  ),
                ),
                child: const Text(
                  'SUPER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const ReferenceArt(
                      ArtRegion('energy-02', Rect.fromLTWH(90, 660, 185, 128)),
                      width: 52,
                      height: 36,
                    ),
                    const Text('Unlimited', style: headingStyle),
                    TextButton(
                      onPressed: () => context.push(
                        state.unlimited ? '/subscription' : '/super',
                      ),
                      child: Text(
                        state.unlimited ? 'MANAGE' : 'FREE TRIAL',
                        style: const TextStyle(
                          color: Color(0xFFDA19DF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final item in offers) ...[
          GestureDetector(
            onTap: ref.read(energyControllerProvider.notifier).available(item)
                ? () async {
                    var rewarded = false;
                    if (item.kind == EnergyRefillKind.ad) {
                      final controller = ref.read(
                        energyControllerProvider.notifier,
                      );
                      if (!controller.beginAd(item)) return;
                      try {
                        rewarded =
                            await context.push<bool>(
                              '/ad?placement=REWARDED_ENERGY_REFILL',
                            ) ==
                            true;
                      } finally {
                        controller.endAd();
                      }
                      if (!context.mounted) return;
                    }
                    await _refill(context, ref, item, adRewarded: rewarded);
                  }
                : null,
            child: Semantics(
              button: true,
              enabled: ref
                  .read(energyControllerProvider.notifier)
                  .available(item),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: ReferenceColors.border, width: 2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              ref
                                  .read(energyControllerProvider.notifier)
                                  .available(item)
                              ? LearningColors.blue
                              : ReferenceColors.disabled,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${item.amount}',
                            style: headingStyle.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.title,
                          style: headingStyle.copyWith(
                            fontSize: 19,
                            color:
                                ref
                                    .read(energyControllerProvider.notifier)
                                    .available(item)
                                ? LearningColors.blue
                                : ReferenceColors.disabled,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          item.action,
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                ref
                                    .read(energyControllerProvider.notifier)
                                    .available(item)
                                ? LearningColors.blue
                                : ReferenceColors.disabled,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          state.energy >= repository.capacity || state.unlimited
              ? repository.fullMessage
              : repository.partialMessage,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: ReferenceColors.muted),
        ),
      ],
    );
  }
}
