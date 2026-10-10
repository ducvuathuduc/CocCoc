export '../../quests/presentation/quests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/preview_controller.dart';
import '../application/extended_controller.dart';
import 'timer_boost_screen.dart';
import 'social_screens.dart';
import '../application/social_controller.dart';
import '../application/profile_summary_provider.dart';
import 'profile_weekly_progress.dart';
import 'foreign_profile_achievements.dart';
import 'foreign_profile_header.dart';
import 'own_profile_screen.dart';
import 'score_information_screen.dart';
import 'league_ranking.dart';
import 'league_entry_surface.dart';
import '../../account/application/avatar_controller.dart';
import '../../account/presentation/avatar_motion.dart';

class PreviewPage extends StatelessWidget {
  const PreviewPage({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          LearningHeader(
            title: title,
            onClose: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            trailing: trailing,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}


class LeagueScreen extends ConsumerWidget {
  const LeagueScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningStateProvider),
        preview = ref.watch(previewControllerProvider);
    if (!preview.leagueOptIn) {
      return LeagueEntrySurface(
        remainingLessons: progress.completedLessons < 1 ? 1 : 0,
        onStartLesson: () => context.go('/home'),
        onContinue: () =>
            ref.read(previewControllerProvider.notifier).optIntoLeague(),
      );
    }
    final avatar = ref.watch(avatarControllerProvider);
    return Scaffold(
      body: LeagueRankingSurface(
        ownAvatar: Tooltip(
          message: 'Set your status',
          excludeFromSemantics: true,
          child: StatusAvatar(
            name: preview.name,
            status: ref.watch(statusControllerProvider).selected,
            size: 45,
            portrait: avatar.hasAvatar
                ? AvatarMotion(
                    key: const ValueKey('league-saved-avatar'),
                    values: avatar.saved,
                    width: 45,
                    height: 45,
                    animate: false,
                  )
                : null,
          ),
        ),
        onOpenProfile: (id) => context.push('/profile/$id'),
        onSetStatus: () => showStatusPicker(context, ref),
      ),
    );
  }
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.name,
    this.color = LearningColors.green,
    super.key,
  });
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 23,
    backgroundColor: color,
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 24,
      ),
    ),
  );
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({this.userId = 'me', super.key});
  final String userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == 'me') return const OwnProfileScreen();
    final summary = ref.watch(profileSummaryProvider(userId));
    if (summary == null) {
      return const PreviewPage(
        title: 'Profile unavailable',
        children: [Text('This profile is unavailable.')],
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: ListView(
          key: PageStorageKey('profile-$userId'),
          padding: EdgeInsets.zero,
          children: [
            ForeignProfileHero(summary: summary),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ForeignProfileIdentity(summary: summary),
                  const SizedBox(height: 24),
                  ForeignProfileFollowActions(summary: summary),
                  const SizedBox(height: 28),
                  ProfileWeeklyProgress(userId: userId),
                  const SizedBox(height: 28),
                  ForeignProfileOverview(summary: summary),
                  const SizedBox(height: 28),
                  ForeignProfileAchievements(userId: userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});
  @override
  ConsumerState<FriendsScreen> createState() => _FriendsState();
}

class _FriendsState extends ConsumerState<FriendsScreen> {
  String query = '';
  int tab = 0;
  static const people = ['Alex', 'Maria', 'Lucas', 'Anna', 'Samira'];
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(previewControllerProvider);
    final shown = people.where(
      (p) =>
          p.toLowerCase().contains(query.toLowerCase()) &&
          (tab != 1 || state.following.contains(p)),
    );
    return PreviewPage(
      title: 'Friends',
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Find friends')),
            ButtonSegment(value: 1, label: Text('Following')),
          ],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (v) => setState(() => query = v),
          maxLength: 60,
          decoration: const InputDecoration(
            hintText: 'Search by name',
            prefixIcon: Icon(Icons.search),
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty) ...[
          const SizedBox(height: 40),
          const Icon(
            Icons.people_outline,
            size: 75,
            color: ReferenceColors.disabled,
          ),
          const SizedBox(height: 15),
          const Text(
            'No friends here yet',
            textAlign: TextAlign.center,
            style: headingStyle,
          ),
          const SizedBox(height: 15),
          const Text(
            'Find a friend to learn together.',
            textAlign: TextAlign.center,
          ),
        ],
        for (final person in shown)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            leading: PersonAvatar(name: person),
            title: Text(person, style: headingStyle.copyWith(fontSize: 20)),
            subtitle: const Text('Sample learner'),
            onTap: () => context.push('/profile/$person'),
            trailing: IconButton(
              tooltip: state.following.contains(person)
                  ? 'Unfollow $person'
                  : 'Follow $person',
              onPressed: () =>
                  ref.read(previewControllerProvider.notifier).follow(person),
              icon: Icon(
                state.following.contains(person)
                    ? Icons.check_circle
                    : Icons.person_add,
                color: LearningColors.blue,
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Find friends and learn together.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ReferenceColors.muted),
        ),
      ],
    );
  }
}

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(previewControllerProvider).following;
    return PreviewPage(
      title: 'Friends activity',
      children: [
        if (friends.isEmpty) ...[
          const SizedBox(height: 60),
          const ReferenceArt(LearningArt.friendsChest, width: 280, height: 215),
          const SizedBox(height: 25),
          const Text(
            'Learn together',
            textAlign: TextAlign.center,
            style: headingStyle,
          ),
          const SizedBox(height: 20),
          ReferenceButton(
            label: 'FIND FRIENDS',
            onPressed: () => context.push('/friends'),
          ),
        ],
        for (final friend in friends)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: LearningCard(
              child: Row(
                children: [
                  PersonAvatar(name: friend),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      '$friend finished a lesson\nSample activity',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Celebrate $friend',
                    onPressed: () => showLearningNotice(
                      context,
                      'Celebrated!',
                      'Cheer on your friends as they learn.',
                    ),
                    icon: const Icon(
                      Icons.celebration,
                      color: LearningColors.yellow,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(previewControllerProvider);
    final wallet = ref.watch(previewWalletProvider);
    final max = ref.watch(extendedControllerProvider).isMax;
    return PreviewPage(
      title: 'Shop',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ReferenceArt(LearningArt.gem, width: 22, height: 26),
          const SizedBox(width: 5),
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
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF090622),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'duolingo MAX',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ReferenceArt(LearningArt.maxDuo, width: 94, height: 94),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                max
                    ? 'Thanks for being a Duolingo Max subscriber!'
                    : 'Practice conversations with Lily',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 20),
              ReferenceButton(
                label: max ? 'MANAGE FEATURES' : 'EXPLORE FEATURES',
                backgroundColor: Colors.white,
                edgeColor: Colors.grey,
                foregroundColor: const Color(0xFF090622),
                onPressed: () => context.push(max ? '/max/tour' : '/max'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Text('My items', style: headingStyle),
        const SizedBox(height: 16),
        LearningCard(
          child: Row(
            children: [
              const ReferenceArt(timerBoostArt, width: 54, height: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Timer Boost',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '×${p.timerBoosts}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: ReferenceColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => showTimerBoostOffer(context, ref),
                child: const Text(
                  'GET',
                  style: TextStyle(
                    color: ReferenceColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Power-ups', style: headingStyle),
        const SizedBox(height: 16),
        LearningCard(
          child: Column(
            children: [
              Row(
                children: [
                  const ReferenceArt(LearningArt.freeze, width: 65, height: 88),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Streak Freeze', style: headingStyle),
                        const SizedBox(height: 8),
                        Text(
                          '${p.freezes}/2 equipped',
                          style: const TextStyle(color: ReferenceColors.muted),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Keep your streak if you miss a day.',
                          style: TextStyle(fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ReferenceButton(
                label: p.freezes >= 2 ? 'FULLY EQUIPPED' : 'GET FOR 200 GEMS',
                outlined: true,
                foregroundColor: LearningColors.blue,
                onPressed: p.freezes >= 2
                    ? null
                    : () {
                        final bought = ref
                            .read(previewControllerProvider.notifier)
                            .buyFreeze('freeze-${p.freezes}');
                        showLearningNotice(
                          context,
                          bought
                              ? 'Streak Freeze equipped!'
                              : 'Not enough gems',
                          bought ? 'Your streak freeze is ready.' : 'You need 200 gems. Earn gems by finishing lessons and quests.',
                        );
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Virtual items only. No payment or subscription is activated.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ReferenceColors.muted),
        ),
      ],
    );
  }
}

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(previewControllerProvider).course;
    final names = [
      'Spanish',
      'French',
      'German',
      'Italian',
      'English',
      'Japanese',
    ];
    return PreviewPage(
      title: 'My courses',
      children: [
        const Text('Choose a course', style: headingStyle),
        const SizedBox(height: 22),
        for (var i = 0; i < names.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: LearningCard(
              selected: current == names[i],
              onTap: () => learningSheet<void>(
                context,
                title: names[i],
                child: Column(
                  children: [
                    Text(
                      names[i] == 'English'
                          ? 'Continue your English course.'
                          : 'Explore this language course.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ReferenceButton(
                      label: names[i] == 'English' ? 'SELECT COURSE' : 'CLOSE',
                      onPressed: () {
                        ref
                            .read(previewControllerProvider.notifier)
                            .chooseCourse(names[i]);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              child: Row(
                children: [
                  ReferenceArt(
                    ReferenceArtRegions.flags[i],
                    width: 40,
                    height: 31,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      names[i],
                      style: headingStyle.copyWith(fontSize: 20),
                    ),
                  ),
                  if (current == names[i])
                    const Icon(Icons.check_circle, color: LearningColors.blue),
                ],
              ),
            ),
          ),
        const SizedBox(height: 15),
        const Text(
          'Your progress is saved for each course.',
          style: TextStyle(color: ReferenceColors.muted),
        ),
        const SizedBox(height: 20),
        ReferenceButton(
          label: 'CHECK YOUR LEVEL',
          outlined: true,
          foregroundColor: LearningColors.blue,
          onPressed: () => context.push('/placement'),
        ),
        const SizedBox(height: 16),
        ReferenceButton(
          label: 'START LESSON',
          outlined: true,
          foregroundColor: LearningColors.blue,
          onPressed: () => context.push('/onboarding/demo'),
        ),
      ],
    );
  }
}

class ScoreScreen extends ConsumerWidget {
  const ScoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const ScoreInformationScreen();
}
