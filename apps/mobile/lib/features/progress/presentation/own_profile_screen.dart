import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../account/application/avatar_controller.dart';
import '../../account/application/profile_editor_controller.dart';
import '../../account/presentation/avatar_motion.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/preview_controller.dart';
import '../application/extended_controller.dart';
import '../application/profile_surface_controller.dart';
import 'profile_actions.dart';
import 'profile_sections.dart';

const _profilePlaceholder = ArtRegion(
  'profile-04',
  Rect.fromLTWH(454, 407, 270, 362),
);
const _completeProfileDuo = ArtRegion(
  'profile-04',
  Rect.fromLTWH(708, 1396, 352, 213),
);
const _scoreDuo = ArtRegion(
  'profile-score-source',
  Rect.fromLTWH(700, 1385, 287, 243),
);
const _maxBadge = ArtRegion('profile-06', Rect.fromLTWH(921, 314, 184, 66));
const _superBadge = ArtRegion(
  'profile-score-source',
  Rect.fromLTWH(921, 314, 184, 66),
);

class OwnProfileScreen extends ConsumerWidget {
  const OwnProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewControllerProvider);
    final progress = ref.watch(learningStateProvider);
    final avatar = ref.watch(avatarControllerProvider);
    final profile = ref.watch(profileEditorProvider);
    final surface = ref.watch(profileSurfaceProvider);
    final plan = ref.watch(extendedControllerProvider);
    final name = preview.name;
    final heroColor = avatar.hasAvatar
        ? _avatarBackground(avatar)
        : const Color(0xFFDDF4FF);
    final headerHeight = (MediaQuery.textScalerOf(context).scale(28) * 1.25)
        .clamp(49.0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          key: const PageStorageKey('profile-me'),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileHeroHeader(
                name: name,
                avatar: avatar,
                backgroundColor: heroColor,
                badge: plan.unlimited
                    ? (plan.isMax ? _maxBadge : _superBadge)
                    : null,
                badgeLabel: plan.isMax ? 'Duolingo Max' : 'Duolingo Super',
                topInset: MediaQuery.paddingOf(context).top,
                headerHeight: headerHeight,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${profile.username.toUpperCase()} · JOINED 2026',
                      style: const TextStyle(
                        color: ReferenceColors.disabled,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileCounters(
                      following: preview.following.length,
                      followers: surface.followers.length,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ReferenceButton(
                            label: 'ADD FRIENDS',
                            outlined: true,
                            foregroundColor: ReferenceColors.ink,
                            leading: const Icon(
                              Icons.person_add_alt_1,
                              size: 25,
                            ),
                            onPressed: () => context.push('/friends'),
                          ),
                        ),
                        const SizedBox(width: 13),
                        _SquareAction(
                          tooltip: 'Profile link',
                          icon: Icons.qr_code_rounded,
                          onPressed: () => showProfileShare(
                            context,
                            userId: 'me',
                            name: name,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (!avatar.hasAvatar)
                      _CompleteProfileCard(
                        onPressed: () => context.push('/settings/avatar'),
                      )
                    else if (!surface.scoreCardDismissed)
                      _ScoreCard(
                        onDismiss: () => ref
                            .read(profileSurfaceProvider.notifier)
                            .dismissScoreCard(),
                        onPressed: () => context.push('/score'),
                      ),
                    if (!avatar.hasAvatar || !surface.scoreCardDismissed)
                      const SizedBox(height: 34),
                    const Text(
                      'OVERVIEW',
                      style: TextStyle(
                        color: ReferenceColors.disabled,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ProfileOverview(
                      streak: progress.streak,
                      score: progress.score,
                      league: preview.leagueOptIn ? 'Bronze' : 'No current',
                      xp: progress.xp,
                    ),
                    const SizedBox(height: 30),
                    const OwnProfileSections(),
                    const SizedBox(height: 16),
                    ReferenceButton(
                      label: '2025 YEAR IN REVIEW',
                      outlined: true,
                      onPressed: () => context.push('/year-review'),
                    ),
                    if (!preview.registered) ...[
                      const SizedBox(height: 20),
                      ReferenceButton(
                        label: 'CREATE A PROFILE',
                        onPressed: () => context.push('/auth/register'),
                      ),
                    ],
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

class _ProfileHeroHeader extends SliverPersistentHeaderDelegate {
  const _ProfileHeroHeader({
    required this.name,
    required this.avatar,
    required this.backgroundColor,
    required this.badge,
    required this.badgeLabel,
    required this.topInset,
    required this.headerHeight,
  });

  final String name;
  final AvatarState avatar;
  final Color backgroundColor;
  final ArtRegion? badge;
  final String badgeLabel;
  final double topInset;
  final double headerHeight;

  @override
  double get minExtent => topInset + headerHeight;
  @override
  double get maxExtent => minExtent + 147;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapsed = (shrinkOffset / 147).clamp(0.0, 1.0);
    final color = Color.lerp(backgroundColor, Colors.white, collapsed)!;
    return ClipRect(
      child: ColoredBox(
        color: color,
        child: Stack(
          fit: StackFit.expand,
          children: [
            OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: maxExtent,
              maxHeight: maxExtent,
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: _ProfileHero(
                  name: name,
                  avatar: avatar,
                  backgroundColor: color,
                  badge: badge,
                  badgeLabel: badgeLabel,
                  headerHeight: headerHeight,
                ),
              ),
            ),
            if (collapsed == 1)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: ColoredBox(color: ReferenceColors.border),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileHeroHeader oldDelegate) =>
      name != oldDelegate.name ||
      avatar != oldDelegate.avatar ||
      backgroundColor != oldDelegate.backgroundColor ||
      badge != oldDelegate.badge ||
      badgeLabel != oldDelegate.badgeLabel ||
      topInset != oldDelegate.topInset ||
      headerHeight != oldDelegate.headerHeight;
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.avatar,
    required this.backgroundColor,
    required this.badge,
    required this.badgeLabel,
    required this.headerHeight,
  });

  final String name;
  final AvatarState avatar;
  final Color backgroundColor;
  final ArtRegion? badge;
  final String badgeLabel;
  final double headerHeight;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: backgroundColor,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            height: headerHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: headingStyle.copyWith(fontSize: 28),
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: ReferenceColors.ink,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 147,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  button: true,
                  label: avatar.hasAvatar ? 'Change avatar' : 'Create avatar',
                  child: InkWell(
                    onTap: () => context.push('/settings/avatar'),
                    child: avatar.hasAvatar
                        ? AvatarMotion(
                            values: avatar.saved,
                            width: double.infinity,
                            height: 147,
                            animate: false,
                          )
                        : const Align(
                            alignment: Alignment.bottomCenter,
                            child: ReferenceArt(
                              _profilePlaceholder,
                              width: 89,
                              height: 120,
                            ),
                          ),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Semantics(
                      image: true,
                      label: badgeLabel,
                      child: ReferenceArt(badge!, width: 61, height: 22),
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

Color _avatarBackground(AvatarState avatar) {
  if (avatar.catalog.tabs.isNotEmpty) {
    final selected = avatar.catalog.tabs.last.sections.first.options
        .where((option) => option.value == avatar.saved['BackgroundColor'])
        .firstOrNull
        ?.color;
    if (selected != null) {
      return Color(int.parse(selected.replaceFirst('#', 'FF'), radix: 16));
    }
  }
  return const Color(0xFFFFDFDF);
}

class _ProfileCounters extends StatelessWidget {
  const _ProfileCounters({required this.following, required this.followers});

  final int following;
  final int followers;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _Counter(
          key: const ValueKey('profile-courses'),
          label: 'Courses',
          value: const ReferenceArt(LearningArt.english, width: 31, height: 24),
          onPressed: () => context.push('/profile/courses'),
        ),
      ),
      Expanded(
        child: _Counter(
          key: const ValueKey('profile-following'),
          label: 'Following',
          value: Text('$following', style: _counterValueStyle),
          onPressed: () => context.push('/profile/friends?tab=following'),
        ),
      ),
      Expanded(
        child: _Counter(
          key: const ValueKey('profile-followers'),
          label: 'Followers',
          value: Text('$followers', style: _counterValueStyle),
          onPressed: () => context.push('/profile/friends?tab=followers'),
        ),
      ),
    ],
  );
}

const _counterValueStyle = TextStyle(
  color: ReferenceColors.ink,
  fontSize: 22,
  height: 1,
  fontWeight: FontWeight.w700,
);

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
  Widget build(BuildContext context) {
    final valueHeight = MediaQuery.textScalerOf(context)
        .scale(25)
        .clamp(25, 50)
        .toDouble();
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: valueHeight,
                child: Align(alignment: Alignment.centerLeft, child: value),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: ReferenceColors.disabled,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ReferenceColors.border, width: 2),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 51,
          height: 51,
          child: Icon(icon, color: ReferenceColors.ink, size: 27),
        ),
      ),
    ),
  );
}

class _CompleteProfileCard extends StatelessWidget {
  const _CompleteProfileCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _ProfileCard(
    title: 'Finish your profile!',
    subtitle: '1 STEP LEFT',
    art: _completeProfileDuo,
    artWidth: 116,
    artHeight: 74,
    action: 'COMPLETE PROFILE',
    onPressed: onPressed,
  );
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.onDismiss, required this.onPressed});

  final VoidCallback onDismiss;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _ProfileCard(
    title: 'Add your Duolingo\nScore to LinkedIn!',
    art: _scoreDuo,
    artWidth: 96,
    artHeight: 76,
    action: 'GET STARTED',
    onPressed: onPressed,
    onDismiss: onDismiss,
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.title,
    required this.art,
    required this.artWidth,
    required this.artHeight,
    required this.action,
    required this.onPressed,
    this.subtitle,
    this.onDismiss,
  });

  final String title;
  final String? subtitle;
  final ArtRegion art;
  final double artWidth;
  final double artHeight;
  final String action;
  final VoidCallback onPressed;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(16) / 16;
    final headerHeight = scale <= 1.2
        ? 55.0
        : scaler.scale(subtitle == null ? 65 : 100).clamp(90, 200).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF4FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: headerHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  right: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ReferenceColors.ink,
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: ReferenceColors.disabled,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: -4,
                  top: 0,
                  child: ReferenceArt(art, width: artWidth, height: artHeight),
                ),
                if (onDismiss != null)
                  Positioned(
                    right: -13,
                    top: -13,
                    child: IconButton(
                      tooltip: 'Dismiss score card',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDismiss,
                      icon: const Icon(
                        Icons.close,
                        color: ReferenceColors.disabled,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ReferenceButton(
            label: action,
            backgroundColor: const Color(0xFF1CB0F6),
            edgeColor: const Color(0xFF1899D6),
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _ProfileOverview extends StatelessWidget {
  const _ProfileOverview({
    required this.streak,
    required this.score,
    required this.league,
    required this.xp,
  });

  final int streak;
  final int score;
  final String league;
  final int xp;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _OverviewItem(
              art: LearningArt.flame,
              value: '$streak ${streak == 1 ? 'day' : 'days'}',
            ),
          ),
          Expanded(
            child: _OverviewItem(art: LearningArt.english, value: '$score'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _OverviewItem(
              icon: Icons.emoji_events_rounded,
              iconColor: ReferenceColors.disabled,
              value: league,
              muted: true,
            ),
          ),
          Expanded(
            child: _OverviewItem(
              icon: Icons.star_rounded,
              iconColor: LearningColors.yellow,
              value: '$xp XP',
            ),
          ),
        ],
      ),
    ],
  );
}

class _OverviewItem extends StatelessWidget {
  const _OverviewItem({
    required this.value,
    this.art,
    this.icon,
    this.iconColor,
    this.muted = false,
  });

  final String value;
  final ArtRegion? art;
  final IconData? icon;
  final Color? iconColor;
  final bool muted;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 29,
        height: 29,
        child: art != null
            ? ReferenceArt(art!, width: 29, height: 29)
            : Icon(icon, color: iconColor, size: 29),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: muted ? ReferenceColors.disabled : ReferenceColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}
