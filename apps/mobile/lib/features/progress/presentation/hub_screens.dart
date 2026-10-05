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
import '../application/profile_actions_controller.dart';
import 'profile_actions.dart';

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

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learning = ref.watch(learningStateProvider);
    final preview = ref.watch(previewControllerProvider);
    final controller = ref.read(previewControllerProvider.notifier);
    if (!preview.questIntroSeen) {
      const magenta = Color(0xFFA71E6E);
      return Scaffold(
        backgroundColor: magenta,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReferenceArt(
                          LearningArt.singer,
                          width: 206,
                          height: 220,
                        ),
                        SizedBox(height: 28),
                        Text(
                          'Earn 30 quest points this month\nto claim your October Badge!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            height: 1.28,
                            fontWeight: FontWeight.w700,
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
                  label: 'CONTINUE',
                  backgroundColor: Colors.white,
                  edgeColor: const Color(0xFFCE82AF),
                  foregroundColor: magenta,
                  onPressed: controller.dismissQuestIntro,
                ),
              ),
            ],
          ),
        ),
      );
    }
    Widget quest(
      String id,
      String title,
      int value,
      int target,
      IconData icon,
    ) {
      final done = value >= target, claimed = preview.claims.contains(id);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: LearningCard(
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, size: 36, color: LearningColors.yellow),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: headingStyle.copyWith(fontSize: 19),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              QuestProgress(
                value: value,
                target: target,
                color: LearningColors.yellow,
              ),
              if (done) ...[
                const SizedBox(height: 12),
                ReferenceButton(
                  label: claimed ? 'CLAIMED' : 'CLAIM 10 GEMS',
                  onPressed: claimed
                      ? null
                      : () => controller.claimQuest(id, eligible: done),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('quests'),
          children: [
            Container(
              color: const Color(0xFF992C6B),
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'October Quest',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '15 DAYS',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ReferenceArt(
                        LearningArt.questSinger,
                        width: 96,
                        height: 82,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LearningCard(
                    child: Column(
                      children: [
                        const Text('Complete 30 quests', style: headingStyle),
                        const SizedBox(height: 12),
                        QuestProgress(
                          value: preview.claims.length,
                          target: 30,
                          color: const Color(0xFFE843BA),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daily quests', style: headingStyle),
                  TextButton(
                    onPressed: () => context.push('/badges'),
                    child: const Text(
                      'MONTHLY BADGES',
                      style: TextStyle(
                        color: LearningColors.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  quest(
                    'daily-xp',
                    'Earn 20 XP',
                    learning.xp,
                    20,
                    Icons.bolt_rounded,
                  ),
                  quest(
                    'daily-2',
                    'Complete 2 lessons',
                    learning.completedLessons,
                    2,
                    Icons.menu_book_rounded,
                  ),
                  const Text('Friends Clash', style: headingStyle),
                  const SizedBox(height: 16),
                  LearningCard(
                    child: Column(
                      children: [
                        const Text('Win 3 clashes', style: headingStyle),
                        const SizedBox(height: 12),
                        const QuestProgress(
                          value: 0,
                          target: 3,
                          color: LearningColors.yellow,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: LearningColors.orange,
                              child: Text(
                                'J',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text('Joshua', style: headingStyle),
                            ),
                            Flexible(
                              child: ReferenceButton(
                                label: 'START',
                                backgroundColor: LearningColors.blue,
                                edgeColor: const Color(0xFF1899D6),
                                onPressed: () => context.push('/clash'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Friends quest', style: headingStyle),
                  const SizedBox(height: 16),
                  LearningCard(
                    child: Column(
                      children: [
                        const ReferenceArt(
                          LearningArt.questFriends,
                          width: 290,
                          height: 107,
                        ),
                        const SizedBox(height: 18),
                        const Text('Better together!', style: headingStyle),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose a friend and work toward your next goal together.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: ReferenceColors.muted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ReferenceButton(
                          label: 'FIND FRIENDS',
                          onPressed: () => context.push('/friends'),
                        ),
                      ],
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
}

class QuestProgress extends StatelessWidget {
  const QuestProgress({
    required this.value,
    required this.target,
    required this.color,
    super.key,
  });
  final int value, target;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: TweenAnimationBuilder<double>(
          duration: motionDuration(context, 350),
          tween: Tween(begin: 0, end: (value / target).clamp(0, 1)),
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 18,
            color: color,
            backgroundColor: ReferenceColors.border,
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        '${value.clamp(0, target)} / $target',
        style: const TextStyle(
          color: ReferenceColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class LeagueScreen extends ConsumerWidget {
  const LeagueScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningStateProvider),
        preview = ref.watch(previewControllerProvider);
    if (!preview.leagueOptIn) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),
              const Text(
                'Leaderboards',
                textAlign: TextAlign.center,
                style: headingStyle,
              ),
              const SizedBox(height: 65),
              const ReferenceArt(
                LearningArt.leagueLocked,
                width: 290,
                height: 195,
              ),
              const SizedBox(height: 30),
              const Text(
                'A little friendly competition',
                textAlign: TextAlign.center,
                style: headingStyle,
              ),
              const SizedBox(height: 18),
              Text(
                progress.completedLessons < 1
                    ? 'Finish a lesson to join the weekly leaderboard.'
                    : 'You’re ready! Join the Bronze League and keep learning.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  color: ReferenceColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 35),
              ReferenceButton(
                label: progress.completedLessons < 1
                    ? 'START A LESSON'
                    : 'JOIN LEAGUE',
                onPressed: () => progress.completedLessons < 1
                    ? context.go('/home')
                    : ref
                          .read(previewControllerProvider.notifier)
                          .optIntoLeague(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Preview rankings are sample data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ReferenceColors.muted),
              ),
            ],
          ),
        ),
      );
    }
    final names = [
      'Alex',
      'Maria',
      'You',
      'Lucas',
      'Anna',
      'Samira',
      'Noah',
      'Emma',
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('league'),
          children: [
            const SizedBox(height: 16),
            const Center(
              child: ReferenceArt(
                ArtRegion('status-league', Rect.fromLTWH(78, 501, 126, 229)),
                width: 62,
                height: 113,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Bronze League',
              textAlign: TextAlign.center,
              style: headingStyle,
            ),
            const SizedBox(height: 8),
            const Text(
              'Sample weekly ranking • 6 days left',
              textAlign: TextAlign.center,
              style: TextStyle(color: ReferenceColors.muted),
            ),
            const SizedBox(height: 25),
            for (var i = 0; i < names.length; i++)
              Material(
                color: i == 2 ? ReferenceColors.blueFill : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 25,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 19,
                            color: i < 3
                                ? LearningColors.green
                                : ReferenceColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      if (i == 2)
                        Tooltip(
                          message: 'Set your status',
                          child: InkWell(
                            onTap: () => showStatusPicker(context, ref),
                            child: StatusAvatar(
                              name: preview.name,
                              status: ref
                                  .watch(statusControllerProvider)
                                  .selected,
                              size: 44,
                            ),
                          ),
                        )
                      else
                        PersonAvatar(
                          name: names[i],
                          color: i == 2
                              ? LearningColors.blue
                              : Colors.primaries[i],
                        ),
                    ],
                  ),
                  title: Text(
                    i == 2 ? preview.name : names[i],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Text(
                    '${i == 2 ? progress.xp : 100 - i * 11} XP',
                    style: const TextStyle(
                      color: ReferenceColors.muted,
                      fontSize: 17,
                    ),
                  ),
                  onTap: () =>
                      context.push('/profile/${i == 2 ? 'me' : names[i]}'),
                ),
              ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'PROMOTION ZONE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LearningColors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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
    final preview = ref.watch(previewControllerProvider),
        progress = ref.watch(learningStateProvider);
    final own = userId == 'me';
    if (!own && !sampleProfileIds.contains(userId)) {
      return const PreviewPage(
        title: 'Profile unavailable',
        children: [Text('This profile is not available in the local preview.')],
      );
    }
    final blocked = ref.watch(profileActionsProvider).blocked.contains(userId);
    final name = own
        ? preview.name
        : sampleProfileIds.contains(userId)
        ? userId
        : 'Alex';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: PageStorageKey('profile-$userId'),
          children: [
            Container(
              color: const Color(0xFFFFDFDF),
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!own)
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: ReferenceColors.muted,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          name,
                          style: headingStyle.copyWith(fontSize: 28),
                        ),
                      ),
                      IconButton(
                        tooltip: own ? 'Settings' : 'Profile options',
                        onPressed: () => own
                            ? context.push('/settings')
                            : showProfileOptions(context, ref, userId),
                        icon: Icon(
                          own ? Icons.settings : Icons.more_horiz,
                          color: ReferenceColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const ReferenceArt(
                    LearningArt.avatar,
                    width: 145,
                    height: 147,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (own)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Profile link',
                            onPressed: () => showProfileShare(
                              context,
                              userId: userId,
                              name: name,
                            ),
                            icon: const Icon(
                              Icons.qr_code,
                              color: LearningColors.blue,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/settings/profile'),
                            child: const Text(
                              'EDIT',
                              style: TextStyle(
                                color: LearningColors.blue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    own
                        ? '${preview.email.split('@').first} • Joined October 2026'
                        : '${name.toLowerCase().replaceAll(' ', '.')}.learns • Sample profile',
                    style: const TextStyle(
                      fontSize: 16,
                      color: ReferenceColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const ReferenceArt(
                        LearningArt.english,
                        width: 31,
                        height: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        own ? '${progress.xp} XP' : '120 XP',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ReferenceColors.muted,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/friends'),
                        child: Text(
                          '${preview.following.length} following',
                          style: const TextStyle(color: LearningColors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ReferenceButton(
                    label: own
                        ? 'ADD FRIENDS'
                        : blocked
                        ? 'UNBLOCK USER'
                        : preview.following.contains(userId)
                        ? 'FOLLOWING'
                        : 'FOLLOW',
                    outlined: true,
                    foregroundColor: LearningColors.blue,
                    onPressed: () => own
                        ? context.push('/friends')
                        : blocked
                        ? ref
                              .read(profileActionsProvider.notifier)
                              .unblock(userId)
                        : ref
                              .read(previewControllerProvider.notifier)
                              .follow(userId),
                  ),
                  const SizedBox(height: 28),
                  const Text('Overview', style: headingStyle),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _overview(
                        context,
                        '${progress.streak}',
                        'Day streak',
                        LearningArt.flame,
                      ),
                      _overview(
                        context,
                        '${progress.xp}',
                        'Total XP',
                        LearningArt.gem,
                      ),
                      _overview(
                        context,
                        preview.leagueOptIn ? 'Bronze' : 'No league',
                        'Current league',
                        LearningArt.trophy,
                      ),
                      _overview(
                        context,
                        '${progress.completedLessons}',
                        'Lessons',
                        LearningArt.guide,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Achievements', style: headingStyle),
                      ),
                      TextButton(
                        onPressed: () => context.push('/achievements'),
                        child: const Text(
                          'VIEW ALL',
                          style: TextStyle(
                            color: LearningColors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LearningCard(
                    onTap: () => context.push('/achievements'),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.military_tech_rounded,
                          size: 50,
                          color: LearningColors.yellow,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Wildfire', style: headingStyle),
                              const SizedBox(height: 8),
                              QuestProgress(
                                value: progress.streak,
                                target: 3,
                                color: LearningColors.orange,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ReferenceButton(
                    label: 'FRIENDS ACTIVITY',
                    outlined: true,
                    foregroundColor: LearningColors.blue,
                    onPressed: () => context.push('/activity'),
                  ),
                  if (own && !preview.registered) ...[
                    const SizedBox(height: 20),
                    ReferenceButton(
                      label: 'CREATE A PROFILE',
                      onPressed: () => context.push('/auth/register'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overview(
    BuildContext context,
    String value,
    String label,
    ArtRegion art,
  ) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 52) / 2,
    child: LearningCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReferenceArt(art, width: 28, height: 31),
          const SizedBox(height: 8),
          Text(value, style: headingStyle.copyWith(fontSize: 21)),
          Text(
            label,
            style: const TextStyle(color: ReferenceColors.muted, fontSize: 15),
          ),
        ],
      ),
    ),
  );
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
          'Follows stay in this preview. No invitation is sent.',
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
                      'Your celebration is saved only in this preview.',
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
                          bought
                              ? 'Your virtual freeze was added to this preview.'
                              : 'You need 200 gems. Earn gems by finishing lessons and quests.',
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
                      names[i] == 'English' ? 'Continue your English course.' : 'Interactive lessons in this preview focus on English. This course is a reference choice.',
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
          'Changing the preview selection preserves your lesson progress.',
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
          label: 'TRY A DEMO LESSON',
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
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(learningStateProvider).score;
    return PreviewPage(
      title: 'English Score',
      children: [
        const SizedBox(height: 30),
        const ReferenceArt(LearningArt.scoreDuo, width: 135, height: 220),
        const SizedBox(height: 22),
        Text(
          '$score',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 65,
            fontWeight: FontWeight.w700,
            color: LearningColors.blue,
          ),
        ),
        const Text(
          'Build your English skills',
          textAlign: TextAlign.center,
          style: headingStyle,
        ),
        const SizedBox(height: 30),
        QuestProgress(value: score, target: 10, color: LearningColors.blue),
        const SizedBox(height: 22),
        const Text(
          'Keep completing lessons to move toward your next milestone. This is local preview progress.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: ReferenceColors.muted),
        ),
      ],
    );
  }
}
