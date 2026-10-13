import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/client/idempotency.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../../ads/application/ads_controller.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/hearts_controller.dart';
import 'hearts_visuals.dart';

class HeartEarnedScreen extends ConsumerStatefulWidget {
  const HeartEarnedScreen({super.key});
  @override
  ConsumerState<HeartEarnedScreen> createState() => _HeartEarnedScreenState();
}

class _HeartEarnedScreenState extends ConsumerState<HeartEarnedScreen> {
  bool watching = false;
  bool rewarded = false;
  @override
  Widget build(BuildContext context) {
    final content = ref.watch(heartsContentProvider);
    final hearts = ref.watch(heartsControllerProvider);
    final eligible =
        ref.watch(adsEligibleProvider) &&
        !rewarded &&
        hearts.balance < hearts.capacity;
    return Scaffold(
      backgroundColor: HeartsColors.page,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const ReferenceArt(LearningArt.heart, width: 26, height: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${hearts.balance}',
                    style: const TextStyle(
                      color: LearningColors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
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
                            child: const ReferenceArt(
                              HeartsArt.heart,
                              width: 178,
                              height: 145,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            eligible
                                ? content.earnedAdTitle
                                : content.earnedTitle,
                            textAlign: TextAlign.center,
                            style: headingStyle.copyWith(
                              fontSize: 22,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: ReferenceButton(
                label: eligible ? content.earnAction : content.continueAction,
                leading: eligible
                    ? const Icon(Icons.play_arrow_rounded, size: 30)
                    : null,
                backgroundColor: LearningColors.blue,
                edgeColor: LearningColors.blueDark,
                minHeight: 44,
                onPressed: watching
                    ? null
                    : () async {
                        if (!eligible) {
                          context.go('/home');
                          return;
                        }
                        setState(() => watching = true);
                        final receipt = UuidV4Generator().next();
                        final result = await context.push<bool>('/ad?trial=1');
                        if (!context.mounted) return;
                        if (result == true) {
                          ref
                              .read(heartsControllerProvider.notifier)
                              .earnFromAd(receipt);
                        }
                        setState(() {
                          watching = false;
                          rewarded = result == true;
                        });
                      },
              ),
            ),
            if (eligible)
              TextButton(
                onPressed: () => context.go('/home'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  content.decline,
                  style: const TextStyle(
                    color: LearningColors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
