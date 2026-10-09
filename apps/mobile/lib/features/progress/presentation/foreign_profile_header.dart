import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../account/data/avatar_assets.dart';
import '../../account/presentation/avatar_motion.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/preview_controller.dart';
import '../application/profile_actions_controller.dart';
import '../application/profile_appearance_provider.dart';
import '../domain/profile_summary.dart';
import 'profile_actions.dart';

class ForeignProfileHero extends ConsumerWidget {
  const ForeignProfileHero({required this.summary, super.key});
  final ProfileSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(profileAppearanceProvider(summary.userId));
    final catalogState = ref.watch(avatarCatalogProvider);
    final catalog = catalogState.asData?.value;
    final display = catalog?.profileDisplays[appearance?.background];
    final background = catalog?.tabs
        .expand((tab) => tab.sections)
        .expand((section) => section.options)
        .where(
          (option) =>
              option.stateName == 'BackgroundColor' &&
              option.value == appearance?.background,
        )
        .firstOrNull
        ?.color;
    final selectedBackground = display?.backgroundColor ?? background;
    final color = selectedBackground == null
        ? const Color(0xFFFFDFDF)
        : Color(
            int.parse(selectedBackground.replaceFirst('#', 'FF'), radix: 16),
          );
    final iconColor = display == null
        ? ReferenceColors.ink
        : Color(
            int.parse(display.iconColor.replaceFirst('#', 'FF'), radix: 16),
          );
    final inset = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: color,
      child: SizedBox(
        height: inset + 182,
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: catalog != null && appearance != null
                    ? AvatarMotion(
                        key: ValueKey('foreign-avatar-${summary.userId}'),
                        values: appearance.valuesFor(catalog),
                        width: 210,
                        height: 182,
                      )
                    : SizedBox(
                        width: 210,
                        height: 182,
                        child: catalogState.hasError
                            ? Center(
                                child: IconButton(
                                  tooltip: 'Try again',
                                  onPressed: () =>
                                      ref.invalidate(avatarCatalogProvider),
                                  icon: Icon(Icons.refresh, color: iconColor),
                                ),
                              )
                            : null,
                      ),
              ),
            ),
            Positioned(
              top: inset,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () {
                      final router = GoRouter.maybeOf(context);
                      if (router != null) {
                        router.canPop() ? router.pop() : router.go('/home');
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    icon: Icon(Icons.close, color: iconColor, size: 32),
                  ),
                  IconButton(
                    tooltip: 'Profile options',
                    onPressed: () =>
                        showProfileOptions(context, ref, summary.userId),
                    icon: Icon(Icons.more_horiz, color: iconColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForeignProfileIdentity extends StatelessWidget {
  const ForeignProfileIdentity({required this.summary, super.key});
  final ProfileSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(summary.name, style: headingStyle.copyWith(fontSize: 28)),
      const SizedBox(height: 8),
      Text(
        '@${summary.username} • Joined ${summary.joinedYear}',
        style: const TextStyle(color: ReferenceColors.muted, fontSize: 16),
      ),
      const SizedBox(height: 24),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ProfileCounter(
                label: 'Courses',
                value: Semantics(
                  label: 'English, 1 course',
                  excludeSemantics: true,
                  child: const ReferenceArt(
                    LearningArt.english,
                    width: 31,
                    height: 24,
                  ),
                ),
              ),
            ),
            const VerticalDivider(
              width: 16,
              thickness: 2,
              color: ReferenceColors.border,
            ),
            Expanded(
              child: _ProfileCounter(
                label: 'Following',
                value: Text('${summary.followingCount}', style: _counterStyle),
              ),
            ),
            const VerticalDivider(
              width: 16,
              thickness: 2,
              color: ReferenceColors.border,
            ),
            Expanded(
              child: _ProfileCounter(
                label: 'Followers',
                value: Text('${summary.followersCount}', style: _counterStyle),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

const _counterStyle = TextStyle(
  color: ReferenceColors.ink,
  fontSize: 20,
  fontWeight: FontWeight.w700,
);

class _ProfileCounter extends StatelessWidget {
  const _ProfileCounter({required this.label, required this.value});
  final String label;
  final Widget value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      value,
      const SizedBox(height: 8),
      Text(
        label,
        style: const TextStyle(color: ReferenceColors.muted, fontSize: 16),
      ),
    ],
  );
}

class ForeignProfileFollowActions extends ConsumerWidget {
  const ForeignProfileFollowActions({required this.summary, super.key});
  final ProfileSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = summary.userId;
    final blocked = ref.watch(
      profileActionsProvider.select((state) => state.blocked.contains(userId)),
    );
    final following = ref.watch(
      previewControllerProvider.select(
        (state) => state.following.contains(userId),
      ),
    );
    void toggleFollow() => blocked
        ? ref.read(profileActionsProvider.notifier).unblock(userId)
        : ref.read(previewControllerProvider.notifier).follow(userId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            excludeSemantics: true,
            label:
                '${blocked
                    ? 'Unblock'
                    : following
                    ? 'Unfollow'
                    : 'Follow'} ${summary.name}',
            onTap: toggleFollow,
            child: ReferenceButton(
              label: blocked
                  ? 'UNBLOCK USER'
                  : following
                  ? 'FOLLOWING'
                  : 'FOLLOW',
              outlined: following || blocked,
              backgroundColor: LearningColors.blue,
              edgeColor: const Color(0xFF1899D6),
              foregroundColor: following || blocked
                  ? LearningColors.blue
                  : Colors.white,
              leading: Icon(
                blocked
                    ? Icons.block
                    : following
                    ? Icons.check
                    : Icons.person_add_alt_1,
                size: 24,
              ),
              onPressed: toggleFollow,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 48,
          child: Tooltip(
            message: 'Share profile',
            child: ReferenceButton(
              label: '',
              outlined: true,
              minHeight: 44,
              contentPadding: const EdgeInsets.all(8),
              leading: const Icon(
                CupertinoIcons.share,
                color: LearningColors.blue,
                size: 27,
              ),
              onPressed: () =>
                  showProfileShare(context, userId: userId, name: summary.name),
            ),
          ),
        ),
      ],
    );
  }
}

class ForeignProfileOverview extends StatelessWidget {
  const ForeignProfileOverview({required this.summary, super.key});
  final ProfileSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Overview', style: headingStyle),
      const SizedBox(height: 16),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _OverviewTile(
                value: '${summary.streak}',
                label: 'Day streak',
                icon: const ReferenceArt(
                  LearningArt.flame,
                  width: 22,
                  height: 26,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewTile(
                value: '${summary.xp}',
                label: 'Total XP',
                valueKey: const ValueKey('foreign-profile-total-xp'),
                icon: const Icon(
                  Icons.bolt_rounded,
                  color: LearningColors.yellow,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _OverviewTile(
                    value: summary.league,
                    label: 'League',
                    icon: Icon(
                      Icons.emoji_events_rounded,
                      size: 26,
                      color: summary.league == 'Silver'
                          ? const Color(0xFF8CC1CC)
                          : const Color(0xFFD48F52),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: -10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF8096AB),
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          'WEEK ${summary.leagueWeek}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewTile(
                value: '${summary.topThreeFinishes}',
                label: 'Top 3 finishes',
                icon: const Icon(
                  Icons.workspace_premium_rounded,
                  color: LearningColors.yellow,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.value,
    required this.label,
    required this.icon,
    this.valueKey,
  });
  final String value, label;
  final Widget icon;
  final Key? valueKey;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: ReferenceColors.border, width: 2),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                key: valueKey,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ReferenceColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: ReferenceColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
