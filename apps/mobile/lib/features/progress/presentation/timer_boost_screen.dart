import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/preview_controller.dart';
import '../application/timer_boost_controller.dart';

const timerBoostArt = ArtRegion(
  'timer-boost-packs',
  Rect.fromLTWH(108, 1218, 164, 160),
);
const _basket = ArtRegion(
  'timer-boost-packs',
  Rect.fromLTWH(100, 1518, 180, 175),
);
const _barrel = ArtRegion(
  'timer-boost-packs',
  Rect.fromLTWH(88, 1772, 205, 202),
);
const _success = ArtRegion(
  'timer-boost-success',
  Rect.fromLTWH(88, 585, 1010, 1010),
);
const _purple = Color(0xFF9069CD);
const _successStock = ArtRegion(
  'timer-boost-success',
  Rect.fromLTWH(972, 199, 84, 80),
);
const _edge = Color(0xFF7356A8);

Future<void> showTimerBoostOffer(
  BuildContext context,
  WidgetRef ref, {
  bool challenge = false,
}) async {
  ref.read(timerBoostControllerProvider.notifier).begin();
  final bought = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * .74,
      child: TimerBoostOffer(
        onPurchased: () => Navigator.pop(sheetContext, true),
      ),
    ),
  );
  if (bought == true && context.mounted) {
    context.push('/timer-boost/success${challenge ? '?return=challenge' : ''}');
  }
}

class TimerBoostOffer extends ConsumerWidget {
  const TimerBoostOffer({this.onPurchased, super.key});
  final VoidCallback? onPurchased;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timerBoostControllerProvider);
    final vm = ref.read(timerBoostControllerProvider.notifier);
    final balanceUsed = ref.watch(
      previewControllerProvider.select((p) => p.demoBalanceUsed),
    );
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 7),
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFAFAFAF),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const ReferenceArt(
                        LearningArt.gem,
                        width: 22,
                        height: 26,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${ref.watch(previewWalletProvider)}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: LearningColors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SizedBox(
                    width: 310,
                    child: Text(
                      'Get Timer Boosts for 1 extra minute during challenges!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  for (final pack in [1, 5, 15]) ...[
                    _PackChoice(
                      pack: pack,
                      selected: state.pack == pack,
                      onSelect: () => vm.select(pack),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          color: LearningColors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Earn gems through lessons and quests.',
                      textAlign: TextAlign.center,
                    ),
                    if (!balanceUsed)
                      TextButton(
                        onPressed: () => context.push('/shop'),
                        child: const Text('GET GEMS'),
                      ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: ReferenceButton(
              label: 'GET TIMER BOOSTS',
              backgroundColor: _purple,
              edgeColor: _edge,
              onPressed: state.added > 0
                  ? null
                  : () {
                      if (vm.purchase()) onPurchased?.call();
                    },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.maybePop(context, false),
            child: const Text(
              'NO THANKS',
              style: TextStyle(
                color: _purple,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PackChoice extends StatelessWidget {
  const _PackChoice({
    required this.pack,
    required this.selected,
    required this.onSelect,
  });
  final int pack;
  final bool selected;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    excludeSemantics: true,
    label:
        '${pack == 1 ? 'Single' : '$pack pack'}, ${timerBoostPrices[pack]} gems${pack == 5 ? ', popular' : ''}',
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected ? _purple : const Color(0xFFD4C3EC),
                  width: selected ? 3 : 2,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(18) > 25;
                  final price = Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      const ReferenceArt(
                        LearningArt.gem,
                        width: 20,
                        height: 24,
                      ),
                      Text(
                        '${timerBoostPrices[pack]}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: LearningColors.blue,
                        ),
                      ),
                      if (pack != 1)
                        Text(
                          pack == 5 ? '2250' : '6750',
                          style: const TextStyle(
                            fontSize: 15,
                            color: ReferenceColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  );
                  return Row(
                    children: [
                      ReferenceArt(
                        switch (pack) {
                          1 => timerBoostArt,
                          5 => _basket,
                          _ => _barrel,
                        },
                        width: 54,
                        height: 54,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: largeText
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pack == 1 ? 'Single' : '$pack pack',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  price,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      pack == 1 ? 'Single' : '$pack pack',
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  price,
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (pack == 5)
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? _purple : const Color(0xFFD4C3EC),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        if (selected)
          const Positioned(
            top: -8,
            right: -8,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFFEDDAFF),
              child: Icon(Icons.check_rounded, size: 19, color: _purple),
            ),
          ),
      ],
    ),
  );
}

class TimerBoostSuccessScreen extends ConsumerWidget {
  const TimerBoostSuccessScreen({this.challenge = false, super.key});
  final bool challenge;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: LearningColors.blue,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 22, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const ReferenceArt(_successStock, width: 27, height: 28),
                const SizedBox(width: 8),
                Text(
                  '${ref.watch(previewControllerProvider).timerBoosts}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const ReferenceArt(_success, width: 336, height: 336),
                    const SizedBox(height: 30),
                    Text(
                      'Timer Boost\n+${ref.watch(timerBoostControllerProvider).added}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ReferenceButton(
              label: challenge ? 'BACK TO CHALLENGE' : 'BACK TO SHOP',
              backgroundColor: Colors.white,
              edgeColor: const Color(0xFFBCE9FF),
              foregroundColor: LearningColors.blue,
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(challenge ? '/journeys/rapid/session' : '/shop'),
            ),
          ),
        ],
      ),
    ),
  );
}
