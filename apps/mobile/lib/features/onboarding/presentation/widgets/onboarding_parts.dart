import 'package:flutter/material.dart';

import '../../../../core/design/duo_illustration.dart';
import '../../../../core/design/reference_art.dart';
import '../../../../core/design/reference_theme.dart';
import '../../../../core/design/reference_widgets.dart';
import '../../domain/onboarding_content.dart';
import 'onboarding_motion.dart';
import 'onboarding_palette.dart';

/// Renders mascot copy with its bold / accent runs.
TextSpan promptSpan(Prompt prompt) => TextSpan(
  children: [
    for (final s in prompt)
      TextSpan(
        text: s.text,
        style: switch (s.emphasis) {
          PromptEmphasis.none => null,
          PromptEmphasis.bold => const TextStyle(fontWeight: FontWeight.w700),
          PromptEmphasis.accent => const TextStyle(
            color: ReferenceColors.purple,
            fontWeight: FontWeight.w700,
          ),
        },
      ),
  ],
);

/// Option card with the Duolingo select bounce.
class OnboardingOption extends StatelessWidget {
  const OnboardingOption({
    required this.selected,
    required this.onTap,
    required this.child,
    this.recommended = false,
    this.minHeight = 31,
    super.key,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final bool recommended;
  final double minHeight;
  @override
  Widget build(BuildContext context) => SelectBounce(
    selected: selected,
    child: ChoiceCard(
      selected: selected,
      onTap: onTap,
      recommended: recommended,
      minHeight: minHeight,
      child: child,
    ),
  );
}

const optionTextStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w700);

class LevelBars extends StatelessWidget {
  const LevelBars({required this.level, required this.selected, super.key});
  final int level;
  final bool selected;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 40,
      height: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 7,
                height: 10.0 + i * 4,
                decoration: BoxDecoration(
                  color: i < level
                      ? OnboardingPalette.barFilled
                      : selected
                      ? OnboardingPalette.barEmptySelected
                      : OnboardingPalette.barEmpty,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class ReasonCheckbox extends StatelessWidget {
  const ReasonCheckbox({required this.checked, super.key});
  final bool checked;
  @override
  Widget build(BuildContext context) => Semantics(
    checked: checked,
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? OnboardingPalette.checkBlue : ReferenceColors.surface,
        border: Border.all(
          color: checked ? OnboardingPalette.checkBlue : ReferenceColors.border,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: checked
          ? const Icon(
              Icons.check_rounded,
              color: ReferenceColors.surface,
              size: 20,
            )
          : null,
    ),
  );
}

class DetailChoice extends StatelessWidget {
  const DetailChoice({
    required this.option,
    required this.language,
    required this.selected,
    required this.onTap,
    this.art,
    super.key,
  });
  final DetailOption option;
  final String language;
  final bool selected;
  final VoidCallback onTap;
  final ArtRegion? art;
  @override
  Widget build(BuildContext context) => OnboardingOption(
    selected: selected,
    onTap: onTap,
    recommended: option.recommended,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (art != null) ...[
            SizedBox(
              width: 74,
              child: Center(
                child: DuoIllustration(
                  art!,
                  width: art!.source.width * 390 / 1180,
                  height: art!.source.height * 390 / 1180,
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.title, style: optionTextStyle),
                const SizedBox(height: 7),
                Text(
                  option.subtitle.replaceAll('{language}', language),
                  style: const TextStyle(fontSize: 16.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class BenefitList extends StatelessWidget {
  const BenefitList({required this.items, super.key});
  final List<BenefitItem> items;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++)
          PopIn(
            delay: Duration(milliseconds: 80 * i),
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DuoIllustration(
                    ReferenceArtRegions.benefitIcons[i %
                        ReferenceArtRegions.benefitIcons.length],
                    width: 43,
                    height: 42,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].title, style: optionTextStyle),
                        const SizedBox(height: 5),
                        Text(
                          items[i].subtitle,
                          style: const TextStyle(
                            color: ReferenceColors.muted,
                            fontSize: 16.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class NotificationPreview extends StatelessWidget {
  const NotificationPreview({required this.copy, super.key});
  final NotificationPreviewCopy copy;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(47, 14, 47, 12),
      child: Column(
        children: [
          PopIn(
            child: Container(
              decoration: BoxDecoration(
                color: OnboardingPalette.sheet,
                border: Border.all(color: ReferenceColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 20, 14, 4),
                    child: Text(
                      copy.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: ReferenceColors.disabled,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                    child: Text(
                      copy.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ReferenceColors.disabled,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: ReferenceColors.border),
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                copy.deny,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: ReferenceColors.disabled,
                                  fontSize: 19,
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, color: ReferenceColors.border),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                copy.allow,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: OnboardingPalette.allow,
                                  fontSize: 19,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 44),
              child: PopIn(
                delay: Duration(milliseconds: 160),
                alignment: Alignment.bottomCenter,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: OnboardingPalette.arrow,
                  size: 48,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
