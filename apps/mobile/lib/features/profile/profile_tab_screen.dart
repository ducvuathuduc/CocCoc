// Profile tab: header, stats, achievements, friends, share link.
//
// Ground truth: docs/design/references/profile/04-08.png.
// Tokens/widgets reused from lib/core/design/* (not edited).
// Pure mock presentation: no HTTP, no cloud, no XP awarding.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/reference_theme.dart';
import '../../core/design/reference_widgets.dart';
import 'profile_mock.dart';

/// Standalone profile tab screen for the `profile` slice.
class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({
    required this.profile,
    this.onSettings,
    this.onAddFriends,
    this.onOpenCourses,
    this.onOpenFollowing,
    this.onOpenFollowers,
    this.onCompleteProfile,
    this.onOpenBadges,
    this.onOpenAchievements,
    this.onManageFamily,
    this.showFamily = false,
    super.key,
  });

  final ProfileMock profile;
  final VoidCallback? onSettings;
  final VoidCallback? onAddFriends;
  final VoidCallback? onOpenCourses;
  final VoidCallback? onOpenFollowing;
  final VoidCallback? onOpenFollowers;
  final VoidCallback? onCompleteProfile;
  final VoidCallback? onOpenBadges;
  final VoidCallback? onOpenAchievements;
  final VoidCallback? onManageFamily;
  final bool showFamily;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          key: const PageStorageKey('profile-tab'),
          slivers: [
            SliverToBoxAdapter(child: _Hero(profile: p, onSettings: onSettings)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.identity,
                      style: const TextStyle(
                        color: ReferenceColors.disabled,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Counters(
                      profile: p,
                      onOpenCourses: onOpenCourses,
                      onOpenFollowing: onOpenFollowing,
                      onOpenFollowers: onOpenFollowers,
                    ),
                    const SizedBox(height: 12),
                    _FriendActions(
                      onAddFriends: onAddFriends,
                      displayName: p.displayName,
                    ),
                    const SizedBox(height: 28),
                    if (p.showFinishCard) ...[
                      _FinishProfileCard(onPressed: onCompleteProfile),
                      const SizedBox(height: 34),
                    ],
                    const _SectionCaption(label: 'OVERVIEW'),
                    const SizedBox(height: 16),
                    _Overview(profile: p),
                    const SizedBox(height: 30),
                    _FriendStreaks(friends: p.friendStreaks),
                    if (p.showFamily || showFamily) ...[
                      const SizedBox(height: 30),
                      _FamilyRow(
                        members: p.familyMembers,
                        onManage: onManageFamily,
                      ),
                    ],
                    const SizedBox(height: 30),
                    _BadgeStrip(
                      title: 'MONTHLY BADGES',
                      semanticsLabel: 'Open Monthly Badges',
                      onOpen: onOpenBadges,
                      children: [
                        for (final badge in p.monthlyBadges)
                          _MonthlyBadgeCell(badge: badge),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _BadgeStrip(
                      title: 'ACHIEVEMENTS',
                      semanticsLabel: 'Open Achievements',
                      onOpen: onOpenAchievements,
                      children: [
                        for (final achievement in p.achievements)
                          _AchievementCell(achievement: achievement),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.profile, required this.onSettings});

  final ProfileMock profile;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final headerHeight = MediaQuery.textScalerOf(
      context,
    ).scale(28 * 1.25).clamp(49.0, 120.0).toDouble();
    return ColoredBox(
      color: profile.heroColor,
      child: Padding(
        padding: EdgeInsets.only(top: topInset, left: 24, right: 24),
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ReferenceColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed:
                        onSettings ?? () => _showMessage(context, 'Settings'),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: ReferenceColors.ink,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            if (profile.showMaxBadge)
              const Align(
                alignment: Alignment.centerRight,
                child: _MaxBadge(),
              ),
            SizedBox(
              height: 147,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: profile.hasAvatar
                    ? _AvatarFace(
                        initial: profile.avatarInitial,
                        color: profile.avatarColor,
                        size: 120,
                      )
                    : const _EmptyAvatarPlaceholder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaxBadge extends StatelessWidget {
  const _MaxBadge();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Super Max member',
    image: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Text(
        'MAX',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );
}

class _EmptyAvatarPlaceholder extends StatelessWidget {
  const _EmptyAvatarPlaceholder();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Create avatar',
    button: true,
    child: CustomPaint(
      painter: _DashedOutlinePainter(),
      child: const SizedBox(
        width: 110,
        height: 130,
        child: Center(
          child: Icon(Icons.add_rounded, color: Colors.white, size: 40),
        ),
      ),
    ),
  );
}

class _DashedOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFF7CC4F2);
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(size.width / 2, 52), radius: 44))
      ..addRect(Rect.fromLTWH(size.width / 2 - 30, 80, 60, 50));
    canvas.drawPath(path, fill);
    final dashed = Paint()
      ..color = const Color(0xFF1CB0F6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, 52);
    for (var a = 0.0; a < math.pi * 2; a += 0.42) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 50),
        a,
        0.26,
        false,
        dashed,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AvatarFace extends StatelessWidget {
  const _AvatarFace({
    required this.initial,
    required this.color,
    required this.size,
  });

  final String initial;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 48,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Counters extends StatelessWidget {
  const _Counters({
    required this.profile,
    required this.onOpenCourses,
    required this.onOpenFollowing,
    required this.onOpenFollowers,
  });

  final ProfileMock profile;
  final VoidCallback? onOpenCourses;
  final VoidCallback? onOpenFollowing;
  final VoidCallback? onOpenFollowers;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _Counter(
          key: const ValueKey('profile-courses'),
          label: 'Courses',
          value: Row(
            children: [
              const _FrenchFlag(),
              if (profile.extraCourses > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: ReferenceColors.border, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${profile.extraCourses}',
                    style: const TextStyle(
                      color: ReferenceColors.disabled,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          onPressed: onOpenCourses ?? () => _showMessage(context, 'Courses'),
        ),
      ),
      Expanded(
        child: _Counter(
          key: const ValueKey('profile-following'),
          label: 'Following',
          value: Text(
            '${profile.following}',
            style: const TextStyle(
              color: ReferenceColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed:
              onOpenFollowing ?? () => _showMessage(context, 'Following'),
        ),
      ),
      Expanded(
        child: _Counter(
          key: const ValueKey('profile-followers'),
          label: 'Followers',
          value: Text(
            '${profile.followers}',
            style: const TextStyle(
              color: ReferenceColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed:
              onOpenFollowers ?? () => _showMessage(context, 'Followers'),
        ),
      ),
    ],
  );
}

class _FrenchFlag extends StatelessWidget {
  const _FrenchFlag();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'French course',
    image: true,
    child: Container(
      width: 40,
      height: 31,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ReferenceColors.border, width: 1),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: Color(0xFF1CB0F6))),
          Expanded(child: ColoredBox(color: Colors.white)),
          Expanded(child: ColoredBox(color: Color(0xFFFF4B4B))),
        ],
      ),
    ),
  );
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Widget value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: MediaQuery.textScalerOf(
              context,
            ).scale(25).clamp(25, 50).toDouble(),
            child: Align(alignment: Alignment.centerLeft, child: value),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ReferenceColors.disabled,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FriendActions extends StatelessWidget {
  const _FriendActions({required this.onAddFriends, required this.displayName});

  final VoidCallback? onAddFriends;
  final String displayName;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ReferenceButton(
          label: 'ADD FRIENDS',
          outlined: true,
          foregroundColor: ReferenceColors.ink,
          leading: const Icon(Icons.person_add_alt_1, size: 25),
          onPressed: onAddFriends ?? () => _showMessage(context, 'Add friends'),
        ),
      ),
      const SizedBox(width: 13),
      Tooltip(
        message: 'Profile link',
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: ReferenceColors.border, width: 2),
          ),
          child: InkWell(
            onTap: () => showProfileShareSheet(
              context,
              userId: 'me',
              displayName: displayName,
            ),
            borderRadius: BorderRadius.circular(14),
            child: const SizedBox(
              width: 51,
              height: 51,
              child: Icon(
                Icons.qr_code_rounded,
                color: ReferenceColors.ink,
                size: 27,
                semanticLabel: 'Open profile link',
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _FinishProfileCard extends StatelessWidget {
  const _FinishProfileCard({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFE1F4FF),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finish your profile!',
                    style: TextStyle(
                      color: ReferenceColors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '1 STEP LEFT',
                    style: TextStyle(
                      color: ReferenceColors.disabled,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.badge_rounded, color: Color(0xFF58CC02), size: 64),
          ],
        ),
        const SizedBox(height: 10),
        ReferenceButton(
          label: 'COMPLETE PROFILE',
          backgroundColor: const Color(0xFF1CB0F6),
          edgeColor: const Color(0xFF1899D6),
          onPressed:
              onPressed ?? () => showAvatarCreateSheet(context),
        ),
      ],
    ),
  );
}

class _SectionCaption extends StatelessWidget {
  const _SectionCaption({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: ReferenceColors.disabled,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.profile});

  final ProfileMock profile;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _OverviewItem(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFFF9600),
              value: profile.streakLabel,
              active: true,
            ),
          ),
          Expanded(
            child: _OverviewItem(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFFFC800),
              value: profile.xpLabel,
              active: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _OverviewItem(
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFF1CB0F6),
              value: profile.leagueLabel,
              active: profile.leagueActive,
            ),
          ),
          Expanded(
            child: _OverviewItem(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFFFC800),
              value: profile.topFinishesLabel,
              active: profile.topFinishesActive,
            ),
          ),
        ],
      ),
    ],
  );
}

class _OverviewItem extends StatelessWidget {
  const _OverviewItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.active,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        color: active ? iconColor : ReferenceColors.disabled,
        size: 29,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? ReferenceColors.ink : ReferenceColors.disabled,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _FriendStreaks extends StatelessWidget {
  const _FriendStreaks({required this.friends});

  final List<FriendStreakMock> friends;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionCaption(label: 'FRIEND STREAKS'),
      const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final friend in friends) ...[
              _FriendCell(friend: friend),
              const SizedBox(width: 16),
            ],
            for (var i = friends.length; i < 5; i++) ...[
              const _InviteCell(),
              if (i < 4) const SizedBox(width: 16),
            ],
          ],
        ),
      ),
    ],
  );
}

class _FriendCell extends StatelessWidget {
  const _FriendCell({required this.friend});

  final FriendStreakMock friend;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${friend.name}, ${friend.days} day Friend Streak',
    child: SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: friend.color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              friend.name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 17,
                color: friend.active
                    ? const Color(0xFFFF9600)
                    : ReferenceColors.disabled,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  '${friend.days}',
                  style: TextStyle(
                    color: friend.active
                        ? const Color(0xFFFF9600)
                        : ReferenceColors.disabled,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _InviteCell extends StatelessWidget {
  const _InviteCell();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Invite a friend to a Friend Streak',
    child: CustomPaint(
      painter: _InviteCirclePainter(),
      child: const SizedBox(
        width: 52,
        height: 70,
        child: Align(
          alignment: Alignment.topCenter,
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
  );
}

class _InviteCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ReferenceColors.disabled
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const center = Offset(26, 24);
    for (var start = 0.0; start < math.pi * 2; start += 0.41) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 21),
        start,
        0.23,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FamilyRow extends StatelessWidget {
  const _FamilyRow({required this.members, required this.onManage});

  final List<FamilyMemberMock> members;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(child: _SectionCaption(label: 'MAX FAMILY')),
          InkWell(
            onTap: onManage ?? () => _showMessage(context, 'Manage family'),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
        ],
      ),
      const SizedBox(height: 10),
      Container(
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final member in members)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FamilyMemberAvatar(member: member),
                ),
              const _FamilyInviteAvatar(),
            ],
          ),
        ),
      ),
    ],
  );
}

class _FamilyMemberAvatar extends StatelessWidget {
  const _FamilyMemberAvatar({required this.member});

  final FamilyMemberMock member;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Family member ${member.name}',
    image: true,
    excludeSemantics: true,
    child: Container(
      width: 56,
      height: 72,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: member.color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          member.name.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _FamilyInviteAvatar extends StatelessWidget {
  const _FamilyInviteAvatar();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Invite a family member',
    image: true,
    child: SizedBox(
      width: 56,
      height: 72,
      child: Icon(
        Icons.person_rounded,
        color: ReferenceColors.disabled,
        size: 56,
        semanticLabel: 'Max Family, invite a member',
      ),
    ),
  );
}

class _BadgeStrip extends StatelessWidget {
  const _BadgeStrip({
    required this.title,
    required this.semanticsLabel,
    required this.children,
    required this.onOpen,
  });

  final String title;
  final String semanticsLabel;
  final List<Widget> children;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        button: true,
        label: semanticsLabel,
        child: InkWell(
          onTap: onOpen ?? () => _showMessage(context, title),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: _SectionCaption(label: title)),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ReferenceColors.disabled,
                  size: 31,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    ],
  );
}

class _MonthlyBadgeCell extends StatelessWidget {
  const _MonthlyBadgeCell({required this.badge});

  final MonthlyBadgeMock badge;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: badge.label,
    child: SizedBox(
      width: 72,
      height: 76,
      child: badge.earned
          ? Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: badge.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFD7D7D7), offset: Offset(0, 4)),
                ],
              ),
              child: Icon(badge.icon, color: Colors.white, size: 32),
            )
          : Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE5E5E5),
                  width: 2,
                ),
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
  );
}

class _AchievementCell extends StatelessWidget {
  const _AchievementCell({required this.achievement});

  final AchievementMock achievement;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${achievement.title}, ${achievement.earned ? 'earned' : 'locked'}',
    child: SizedBox(
      width: 76,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: achievement.earned ? 1 : .16,
                child: Container(
                  width: 72,
                  height: 76,
                  decoration: BoxDecoration(
                    color: achievement.color.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: achievement.color,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    achievement.icon,
                    color: achievement.color,
                    size: 34,
                  ),
                ),
              ),
              if (achievement.isNew)
                Positioned(
                  top: -10,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4B4B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NEW',
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
          const SizedBox(height: 4),
          Text(
            '${achievement.count}',
            style: TextStyle(
              color: achievement.earned
                  ? achievement.color
                  : ReferenceColors.disabled,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

void _showMessage(BuildContext context, String label) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label (mock)')));
}

/// Share-link sheet: QR placeholder + copy action (refs 21_PROFILE_ACTIONS).
Future<void> showProfileShareSheet(
  BuildContext context, {
  required String userId,
  required String displayName,
}) => showModalBottomSheet<void>(
  context: context,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (sheet) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ReferenceColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ReferenceColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: ReferenceColors.border, width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              size: 140,
              color: ReferenceColors.ink,
              semanticLabel: 'Profile QR code',
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            profileShareUrl(userId),
            style: const TextStyle(
              fontSize: 16,
              color: ReferenceColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ReferenceButton(
            label: 'COPY LINK',
            backgroundColor: const Color(0xFF1CB0F6),
            edgeColor: const Color(0xFF1899D6),
            onPressed: () {
              Navigator.pop(sheet);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile link copied')),
              );
            },
          ),
        ],
      ),
    ),
  ),
);

/// Avatar creation sheet (ref 03.png).
Future<void> showAvatarCreateSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ReferenceColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create your avatar!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: ReferenceColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AvatarChoice(color: Color(0xFFFF86C2), initial: 'A'),
                  _AvatarChoice(
                    color: Color(0xFF1CB0F6),
                    initial: '+',
                    selected: true,
                    size: 96,
                  ),
                  _AvatarChoice(color: Color(0xFFFFE29A), initial: 'J'),
                ],
              ),
              const SizedBox(height: 24),
              ReferenceButton(
                label: 'START',
                backgroundColor: const Color(0xFF1CB0F6),
                edgeColor: const Color(0xFF1899D6),
                onPressed: () => Navigator.pop(sheet),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text(
                  'MAYBE LATER',
                  style: TextStyle(
                    color: Color(0xFF1CB0F6),
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

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.color,
    required this.initial,
    this.selected = false,
    this.size = 72,
  });

  final Color color;
  final String initial;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: selected
          ? Border.all(color: Colors.white, width: 4)
          : null,
    ),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
