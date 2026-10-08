import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../learning/application/learning_controller.dart';
import '../application/achievements_controller.dart';
import '../application/extended_controller.dart';
import '../application/streak_controller.dart';
import '../domain/achievement_models.dart';
import 'streak_screen.dart';

const _familyEmptyArt = ArtRegion(
  'profile-07',
  Rect.fromLTWH(485, 1020, 225, 249),
);
const _familyMemberArt = ArtRegion(
  'profile-08',
  Rect.fromLTWH(395, 1040, 390, 230),
);

class OwnProfileSections extends ConsumerWidget {
  const OwnProfileSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(extendedControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FriendStreakSection(),
        if (family.isFamily) ...[
          const SizedBox(height: 30),
          _FamilySection(state: family),
        ],
        const SizedBox(height: 30),
        const _MonthlyBadgesSection(),
        const SizedBox(height: 30),
        const _AchievementsSection(),
      ],
    );
  }
}

class _FriendStreakSection extends ConsumerWidget {
  const _FriendStreakSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(streakControllerProvider);
    final peopleById = {for (final person in streakPeople) person.id: person};
    final friends = state.friends.entries
        .where((entry) => peopleById.containsKey(entry.key))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLink(
          label: 'FRIEND STREAKS',
          semanticsLabel: 'Open Friend Streaks',
          showChevron: false,
          onTap: () {
            ref.read(streakControllerProvider.notifier).selectFriends(true);
            context.push('/streak');
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: math.max(constraints.maxWidth, 340),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in friends)
                    _FriendTile(
                      person: peopleById[entry.key]!,
                      status: entry.value,
                      onTap: () => context.push('/streak'),
                    ),
                  for (var index = friends.length; index < 5; index++)
                    _InviteFriendTile(
                      onTap: () => context.push('/streak/invite'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.person,
    required this.status,
    required this.onTap,
  });

  final StreakPerson person;
  final FriendStreakStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pending = status == FriendStreakStatus.pending;
    final label = pending
        ? '${person.name}, Friend Streak pending'
        : '${person.name}, 0 day Friend Streak';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: 52,
          child: Column(
            children: [
              StreakAvatar(name: person.name, size: 48),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    pending
                        ? Icons.schedule_rounded
                        : Icons.local_fire_department,
                    size: 17,
                    color: pending
                        ? ReferenceColors.disabled
                        : const Color(0xFFFF9600),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    pending ? '…' : '0',
                    style: const TextStyle(
                      color: ReferenceColors.disabled,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteFriendTile extends StatelessWidget {
  const _InviteFriendTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Invite a friend to a Friend Streak',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: const SizedBox(
        width: 52,
        height: 70,
        child: Align(
          alignment: Alignment.topCenter,
          child: CustomPaint(
            painter: _DashedCirclePainter(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.add_rounded,
                color: ReferenceColors.disabled,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ReferenceColors.disabled
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final radius = math.min(size.width, size.height) / 2 - paint.strokeWidth;
    const dashRadians = .23;
    const gapRadians = .18;
    for (
      double start = 0;
      start < math.pi * 2;
      start += dashRadians + gapRadians
    ) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
        start,
        dashRadians,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => false;
}

class _FamilySection extends StatelessWidget {
  const _FamilySection({required this.state});

  final ExtendedState state;

  @override
  Widget build(BuildContext context) {
    final max = state.plan == 'max-family';
    final title = max ? 'MAX FAMILY' : 'SUPER FAMILY';
    final invited = state.invited.toList(growable: false)..sort();
    final description = invited.isEmpty
        ? '${max ? 'Max' : 'Super'} Family, no invited members'
        : '${max ? 'Max' : 'Super'} Family, ${invited.length} invited ${invited.length == 1 ? 'member' : 'members'}: ${invited.join(', ')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: _sectionHeadingStyle)),
            Semantics(
              button: true,
              label: 'Manage ${max ? 'Max' : 'Super'} Family',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => context.push('/subscription/family'),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Text(
                        'MANAGE',
                        style: TextStyle(
                          color: Color(0xFF1CB0F6),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          image: true,
          label: description,
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(top: 2),
            child: ReferenceArt(
              invited.isEmpty ? _familyEmptyArt : _familyMemberArt,
              width: invited.isEmpty ? 75 : 129,
              height: invited.isEmpty ? 83 : 76,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyBadgesSection extends ConsumerWidget {
  const _MonthlyBadgesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBadges = ref.watch(monthlyBadgesProvider);
    final latestYear = allBadges.map((badge) => badge.year).reduce(math.max);
    final badges = allBadges
        .where((badge) => badge.year == latestYear)
        .toList(growable: false)
        .reversed
        .take(4)
        .toList(growable: false);
    final chronologicalBadges = badges.reversed.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLink(
          label: 'MONTHLY BADGES',
          semanticsLabel: 'Open Monthly Badges',
          onTap: () => context.push('/badges'),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var index = 0;
                index < chronologicalBadges.length;
                index++
              ) ...[
                _BadgePreview(badge: chronologicalBadges[index]),
                if (index < chronologicalBadges.length - 1)
                  const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgePreview extends StatelessWidget {
  const _BadgePreview({required this.badge});

  final MonthlyBadge badge;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        '${badge.month} ${badge.year}, ${badge.earned ? 'earned' : 'locked'}',
    excludeSemantics: true,
    child: SizedBox(
      key: ValueKey('monthly-${badge.month.toLowerCase()}'),
      width: 72,
      height: 76,
      child: badge.earned
          ? ReferenceArt(badge.art, width: 72, height: 72)
          : Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFD7D7D7), offset: Offset(0, 4)),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 27,
                  color: ReferenceColors.disabled,
                ),
              ),
            ),
    ),
  );
}

class _AchievementsSection extends ConsumerWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref
        .watch(achievementsControllerProvider)
        .achievements
        .take(4)
        .toList(growable: false);
    final currentXp = ref.watch(
      learningStateProvider.select((state) => state.xp),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLink(
          label: 'ACHIEVEMENTS',
          semanticsLabel: 'Open Achievements',
          onTap: () => context.push('/achievements'),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < achievements.length; index++) ...[
                _AchievementPreview(
                  achievement: achievements[index],
                  currentXp: currentXp,
                ),
                if (index < achievements.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AchievementPreview extends StatelessWidget {
  const _AchievementPreview({
    required this.achievement,
    required this.currentXp,
  });

  final AchievementDefinition achievement;
  final int currentXp;

  @override
  Widget build(BuildContext context) {
    final earned = achievement.isEarned(currentXp);
    return Semantics(
      button: true,
      label: '${achievement.title}, ${earned ? 'earned' : 'locked'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push('/achievements/${achievement.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Opacity(
            opacity: earned ? 1 : .16,
            child: ReferenceArt(achievement.art, width: 72, height: 76),
          ),
        ),
      ),
    );
  }
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.showChevron = true,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: _sectionHeadingStyle)),
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                color: ReferenceColors.disabled,
                size: 31,
              ),
          ],
        ),
      ),
    ),
  );
}

const _sectionHeadingStyle = TextStyle(
  color: ReferenceColors.disabled,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.1,
);
