import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/extended_controller.dart';
import '../application/family_reaction_controller.dart';
import '../application/preview_controller.dart';
import 'streak_screen.dart';

abstract final class FamilyReactionArt {
  static const hero = ArtRegion(
    'family-subscription',
    Rect.fromLTWH(0, 370, 1179, 400),
  );
  static const sam = ArtRegion(
    'family-nudge',
    Rect.fromLTWH(961, 1678, 170, 170),
  );
  static const bubbleFire = ArtRegion(
    'family-nudge',
    Rect.fromLTWH(92, 1705, 110, 116),
  );
  static const icons = [
    ArtRegion('family-nudge', Rect.fromLTWH(91, 1948, 135, 158)),
    ArtRegion('family-nudge', Rect.fromLTWH(386, 1977, 137, 111)),
    ArtRegion('family-nudge', Rect.fromLTWH(657, 1964, 150, 160)),
    ArtRegion('family-nudge', Rect.fromLTWH(955, 1980, 133, 131)),
  ];
}

class FamilySubscriptionScreen extends ConsumerWidget {
  const FamilySubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(extendedControllerProvider),
        reaction = ref.watch(familyReactionControllerProvider);
    if (!s.isFamily) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              LearningHeader(
                title: 'Subscription',
                onClose: () => closeStreak(context),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Learn together with Family',
                          style: headingStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ReferenceButton(
                          label: 'EXPLORE FAMILY PLAN',
                          onPressed: () => context.push('/super'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    const purple = Color(0xFF5B24B9);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: s.isMax
                    ? const RadialGradient(
                        center: Alignment.bottomCenter,
                        radius: 1,
                        colors: [Color(0xFF321055), Colors.black],
                      )
                    : const RadialGradient(
                        colors: [Color(0xFF143FA4), Color(0xFF072645)],
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Close subscription',
                        onPressed: () => closeStreak(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Subscription',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 8),
                    child: Text(
                      s.isMax ? 'MAX FAMILY' : 'SUPER FAMILY',
                      style: const TextStyle(
                        color: Color(0xFFCD95FC),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (s.isMax)
                    Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) => ReferenceArt(
                          FamilyReactionArt.hero,
                          width: constraints.maxWidth,
                          height: constraints.maxWidth * 400 / 1179,
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: ReferenceArt(
                        LearningArt.superDuo,
                        width: 110,
                        height: 169,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'YOUR FAMILY',
                          style: TextStyle(
                            color: streakGray,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/subscription'),
                        child: const Text(
                          'MANAGE',
                          style: TextStyle(
                            color: streakBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const ReferenceArt(
                      FamilyReactionArt.sam,
                      width: 44,
                      height: 44,
                    ),
                    title: Text(
                      ref.watch(previewControllerProvider).name,
                      style: headingStyle.copyWith(fontSize: 22),
                    ),
                    subtitle: const Text(
                      'Manager',
                      style: TextStyle(fontSize: 16, color: streakGray),
                    ),
                  ),
                  for (final person in s.invited)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          StreakAvatar(name: person),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person,
                                  style: headingStyle.copyWith(fontSize: 22),
                                ),
                                const Text(
                                  'Invited',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: streakGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: ReferenceButton(
                              label: reaction.nudged.contains(person)
                                  ? 'NUDGED'
                                  : 'NUDGE',
                              backgroundColor: purple,
                              edgeColor: const Color(0xFF431492),
                              onPressed: reaction.nudged.contains(person)
                                  ? null
                                  : () => showFamilyReaction(
                                      context,
                                      ref,
                                      person,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (s.invited.length < 5)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.add_circle_outline,
                        color: streakGray,
                        size: 44,
                      ),
                      title: Text(
                        'Invite members',
                        style: headingStyle.copyWith(fontSize: 22),
                      ),
                      subtitle: Text(
                        '${5 - s.invited.length} slots left',
                        style: const TextStyle(fontSize: 17, color: streakGray),
                      ),
                      onTap: () => context.push('/subscription/family/invite'),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    s.isMax ? 'MAX FEATURES' : 'SUPER FEATURES',
                    style: const TextStyle(
                      fontSize: 17,
                      color: streakGray,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (s.isMax) ...[
                    _feature(
                      context,
                      'Video Call',
                      'START VIDEO CALL',
                      Icons.videocam,
                      '/practice/speaking',
                    ),
                    _feature(
                      context,
                      'Roleplay',
                      'START ROLEPLAY',
                      Icons.chat_bubble,
                      '/journeys/roleplay',
                    ),
                  ] else
                    _feature(
                      context,
                      'Unlimited energy',
                      'KEEP LEARNING',
                      Icons.bolt,
                      '/home',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(
    BuildContext context,
    String title,
    String action,
    IconData icon,
    String route,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      children: [
        Icon(icon, size: 48, color: ReferenceColors.purple),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: headingStyle.copyWith(fontSize: 22)),
              TextButton(
                onPressed: () => context.push(route),
                child: Text(
                  action,
                  style: const TextStyle(
                    color: Color(0xFF5B24B9),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void showFamilyReaction(BuildContext context, WidgetRef ref, String name) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => Consumer(
      builder: (sheet, ref, _) {
        final s = ref.watch(familyReactionControllerProvider),
            vm = ref.read(familyReactionControllerProvider.notifier);
        const headings = [
          'You’re on fire!',
          'You’ve got this!',
          'Great job!',
          'Keep it going!',
        ];
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StreakOutline(
                        color: const Color(0xFFF7F7F7),
                        child: Row(
                          children: [
                            ReferenceArt(
                              s.selected == 0
                                  ? FamilyReactionArt.bubbleFire
                                  : FamilyReactionArt.icons[s.selected],
                              width: 44,
                              height: 49,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    headings[s.selected],
                                    style: headingStyle.copyWith(fontSize: 20),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Keep up that streak!',
                                    style: TextStyle(fontSize: 17),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const ReferenceArt(
                      FamilyReactionArt.sam,
                      width: 55,
                      height: 55,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 3 ? 0 : 12),
                          child: Semantics(
                            label: headings[i],
                            button: true,
                            selected: i == s.selected,
                            child: ChoiceCard(
                              selected: i == s.selected,
                              onTap: () => vm.select(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Center(
                                  child: ReferenceArt(
                                    FamilyReactionArt.icons[i],
                                    width: 42,
                                    height: 48,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                ReferenceButton(
                  label: 'SEND CONGRATS TO ${name.toUpperCase()}!',
                  backgroundColor: const Color(0xFF4947FF),
                  edgeColor: const Color(0xFF3024DE),
                  onPressed: s.nudged.contains(name)
                      ? null
                      : () {
                          if (vm.send(name)) Navigator.pop(sheet);
                        },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
