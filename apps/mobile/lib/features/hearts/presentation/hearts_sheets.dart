import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/preview_controller.dart';
import '../application/hearts_controller.dart';
import '../domain/hearts.dart';
import 'hearts_visuals.dart';

Future<void> showNeedHeartsSheet(
  BuildContext context, {
  VoidCallback? onPractice,
}) => _show(context, lesson: false, onPractice: onPractice);
Future<void> showHeartsOfferSheet(
  BuildContext context, {
  required VoidCallback onEnd,
  int? gems,
  int? refillCost,
}) => _show(
  context,
  lesson: true,
  onEnd: onEnd,
  gems: gems,
  refillCost: refillCost,
);

Future<void> _show(
  BuildContext context, {
  required bool lesson,
  VoidCallback? onEnd,
  VoidCallback? onPractice,
  int? gems,
  int? refillCost,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  isDismissible: !lesson,
  enableDrag: !lesson,
  backgroundColor: ReferenceColors.surface,
  shape: const RoundedRectangleBorder(),
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(
          duration: Duration(milliseconds: 300),
          reverseDuration: Duration(milliseconds: 200),
        ),
  builder: (sheet) => _HeartOptions(
    lesson: lesson,
    onEnd: onEnd,
    onPractice: onPractice,
    gems: gems,
    refillCost: refillCost,
  ),
);

class _HeartOptions extends ConsumerStatefulWidget {
  const _HeartOptions({
    required this.lesson,
    this.onEnd,
    this.onPractice,
    this.gems,
    this.refillCost,
  });
  final bool lesson;
  final VoidCallback? onEnd, onPractice;
  final int? gems, refillCost;
  @override
  ConsumerState<_HeartOptions> createState() => _HeartOptionsState();
}

class _HeartOptionsState extends ConsumerState<_HeartOptions> {
  late HeartOption selected = widget.lesson
      ? HeartOption.superTrial
      : HeartOption.practice;
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final content = ref.watch(heartsContentProvider);
    final state = ref.watch(heartsControllerProvider);
    final int gems = widget.gems ?? ref.watch(previewWalletProvider);
    final int cost =
        widget.refillCost ??
        (widget.lesson ? content.lessonRefillCost : content.homeRefillCost);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            widget.lesson ? 16 : 8,
            widget.lesson ? 10 : 24,
            widget.lesson ? 16 : 8,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.lesson) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const ReferenceArt(LearningArt.gem, width: 20, height: 24),
                    const SizedBox(width: 6),
                    Text(
                      '$gems',
                      style: const TextStyle(
                        color: LearningColors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.lesson ? content.lessonTitle : content.homeTitle,
                  textAlign: TextAlign.center,
                  style: headingStyle.copyWith(fontSize: 22, height: 1.2),
                ),
              ),
              if (!widget.lesson) ...[
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 5,
                  children: [
                    Text(content.nextHeartLabel),
                    Text(
                      state.countdown,
                      style: const TextStyle(
                        color: LearningColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final option in [
                    HeartOption.superTrial,
                    if (!widget.lesson) HeartOption.practice,
                    HeartOption.refill,
                  ]) ...[
                    if (option != HeartOption.superTrial)
                      const SizedBox(width: 12),
                    Expanded(
                      child: _OptionCard(
                        option: option,
                        selected: selected == option,
                        enabled: option != HeartOption.refill || gems >= cost,
                        lesson: widget.lesson,
                        content: content,
                        cost: cost,
                        onTap: () => setState(() => selected = option),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error!, textAlign: TextAlign.center),
                ),
              ReferenceButton(
                label: switch (selected) {
                  HeartOption.superTrial => content.trialAction,
                  HeartOption.practice => content.practiceAction,
                  HeartOption.refill => content.refillAction,
                },
                backgroundColor: LearningColors.blue,
                edgeColor: LearningColors.blueDark,
                minHeight: 44,
                onPressed: busy
                    ? null
                    : () async {
                        if (selected == HeartOption.superTrial) {
                          Navigator.pop(context);
                          context.push('/super');
                          return;
                        }
                        if (selected == HeartOption.refill) {
                          if (ref
                              .read(heartsControllerProvider.notifier)
                              .refill(cost)) {
                            Navigator.pop(context);
                            widget.onEnd?.call();
                          }
                          return;
                        }
                        if (widget.onPractice != null) {
                          Navigator.pop(context);
                          widget.onPractice!();
                          return;
                        }
                        setState(() => busy = true);
                        final started = await ref
                            .read(heartsControllerProvider.notifier)
                            .startPractice();
                        if (!context.mounted) return;
                        if (started) {
                          Navigator.pop(context);
                          context.push('/lesson/practice');
                        } else {
                          setState(() {
                            busy = false;
                            error = content.practiceError;
                          });
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onEnd?.call();
                },
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  widget.lesson ? content.decline : content.later,
                  style: const TextStyle(
                    color: LearningColors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.lesson,
    required this.content,
    required this.cost,
    required this.onTap,
  });
  final HeartOption option;
  final bool selected, enabled, lesson;
  final HeartsContent content;
  final int cost;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final superTrial = option == HeartOption.superTrial;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final ink = enabled ? ReferenceColors.ink : ReferenceColors.border;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight:
                    (lesson
                        ? (superTrial ? 258 : 234)
                        : (superTrial ? 210 : 180)) *
                    scale,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: superTrial && selected
                    ? const LinearGradient(
                        colors: [
                          LearningColors.green,
                          LearningColors.blue,
                          LearningColors.purple,
                        ],
                      )
                    : null,
                color: superTrial && selected
                    ? null
                    : selected
                    ? LearningColors.blue
                    : ReferenceColors.border,
              ),
              padding: EdgeInsets.all(selected ? 3 : 2),
              child: Container(
                decoration: BoxDecoration(
                  color: ReferenceColors.surface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (superTrial)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              LearningColors.green,
                              LearningColors.blue,
                              LearningColors.purple,
                            ],
                          ),
                        ),
                        child: Text(
                          content.superLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: lesson ? 30 : 28),
                      child: HeartGraphic(
                        width: lesson ? 104 : 70,
                        superCount: superTrial
                            ? (lesson
                                  ? content.lessonTrialHearts
                                  : content.homeTrialHearts)
                            : null,
                        empty: option == HeartOption.refill,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        switch (option) {
                          HeartOption.superTrial => content.unlimitedLabel,
                          HeartOption.practice => content.practiceTitle,
                          HeartOption.refill => content.refillLabel,
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                      child: option == HeartOption.refill
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.diamond_rounded,
                                  size: 16,
                                  color: ink,
                                ),
                                Flexible(
                                  child: Text(
                                    '$cost',
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              superTrial
                                  ? content.trialLabel
                                  : content.practiceLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: superTrial
                                    ? LearningColors.purple
                                    : ReferenceColors.muted,
                                fontSize: 16,
                                fontWeight: superTrial
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: -10,
                right: -8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: LearningColors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 23,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
