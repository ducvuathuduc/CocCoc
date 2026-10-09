import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/preview_controller.dart';
import '../application/profile_actions_controller.dart';
import '../application/profile_lists_controller.dart';
import '../application/profile_surface_controller.dart';

class ProfileCoursesScreen extends ConsumerWidget {
  const ProfileCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(previewControllerProvider.select((s) => s.name));
    final courses = ref.watch(profileCoursesProvider);
    return _ProfileListPage(
      title: '$name’s Courses',
      children: [
        _TableFrame(
          child: Column(
            children: [
              for (var i = 0; i < courses.length; i++) ...[
                if (i != 0) const _TableDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      ProfileCourseFlag(courses[i].id),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          courses[i].name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${courses[i].xp} XP',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 17,
                            color: ReferenceColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileFriendsScreen extends ConsumerStatefulWidget {
  const ProfileFriendsScreen({
    this.initialTab = ProfileFriendsTab.following,
    super.key,
  });
  final ProfileFriendsTab initialTab;
  @override
  ConsumerState<ProfileFriendsScreen> createState() =>
      _ProfileFriendsScreenState();
}

class _ProfileFriendsScreenState extends ConsumerState<ProfileFriendsScreen> {
  late ProfileFriendsTab tab = widget.initialTab;
  @override
  void didUpdateWidget(covariant ProfileFriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final following = tab == ProfileFriendsTab.following;
    final people = ref.watch(
      following ? profileFollowingProvider : profileFollowersProvider,
    );
    final followedPeople = ref.watch(
      previewControllerProvider.select((state) => state.following),
    );
    final blockedPeople = ref.watch(
      profileActionsProvider.select((state) => state.blocked),
    );
    return _ProfileListPage(
      title: 'Friends',
      children: [
        _TableFrame(
          child: Column(
            children: [
              Row(
                children: [
                  for (final value in ProfileFriendsTab.values)
                    Expanded(
                      child: Semantics(
                        key: ValueKey('friends-tab-${value.name}'),
                        button: true,
                        selected: tab == value,
                        child: InkWell(
                          onTap: () => setState(() => tab = value),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: tab == value
                                      ? LearningColors.blue
                                      : ReferenceColors.border,
                                  width: tab == value ? 4 : 2,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              value == ProfileFriendsTab.following
                                  ? 'FOLLOWING'
                                  : 'FOLLOWERS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: tab == value
                                    ? LearningColors.blue
                                    : ReferenceColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (people.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 28,
                  ),
                  child: Text(
                    following ? 'No following yet' : 'No followers yet',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                for (var i = 0; i < people.length; i++) ...[
                  if (i != 0) const _TableDivider(),
                  _FriendRow(
                    name: people[i],
                    followed: followedPeople.contains(people[i]),
                    showFollowBack:
                        !following &&
                        !followedPeople.contains(people[i]) &&
                        !blockedPeople.contains(people[i]),
                    onFollowBack: () => ref
                        .read(profileSurfaceProvider.notifier)
                        .followBack(people[i]),
                    onOpen: () => context.push(
                      '/profile/${Uri.encodeComponent(people[i])}',
                    ),
                  ),
                ],
            ],
          ),
        ),
        if (following) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => context.push('/friends'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text(
              'ADD FRIENDS',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: LearningColors.blue,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.name,
    required this.followed,
    required this.showFollowBack,
    required this.onFollowBack,
    required this.onOpen,
  });

  final String name;
  final bool followed;
  final bool showFollowBack;
  final VoidCallback onFollowBack;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    leading: _FriendAvatar(name: name),
    title: Text(
      name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    subtitle: followed
        ? const Row(
            children: [
              ReferenceArt(LearningArt.english, width: 16, height: 12),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'English',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: ReferenceColors.muted),
                ),
              ),
            ],
          )
        : null,
    trailing: showFollowBack
        ? _FollowBackButton(name: name, onPressed: onFollowBack)
        : const Icon(Icons.chevron_right, color: ReferenceColors.disabled),
    onTap: onOpen,
  );
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    if (name == 'Alex') {
      return const ReferenceArt(
        ArtRegion('friends-02', Rect.fromLTWH(97, 568, 128, 128)),
        width: 42,
        height: 42,
      );
    }
    const colors = [
      Color(0xFFFF9600),
      Color(0xFF1CB0F6),
      Color(0xFFCE82FF),
      Color(0xFF58CC02),
    ];
    final colorIndex = name.runes.fold<int>(0, (sum, rune) => sum + rune);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 21,
      backgroundColor: name == 'James Smith'
          ? const Color(0xFFFF9600)
          : colors[colorIndex % colors.length],
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FollowBackButton extends StatelessWidget {
  const _FollowBackButton({required this.name, required this.onPressed});

  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Follow back $name',
    excludeFromSemantics: true,
    child: Semantics(
      button: true,
      label: 'Follow back $name',
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          key: ValueKey('follow-back-$name'),
          width: 52,
          height: 48,
          child: Center(
            child: SizedBox(
              width: 42,
              height: 36,
              child: ReferenceButton(
                label: '',
                minHeight: 32,
                cornerRadius: 8,
                backgroundColor: LearningColors.blue,
                edgeColor: LearningColors.blueDark,
                contentPadding: const EdgeInsets.all(4),
                onPressed: onPressed,
                leading: const Icon(Icons.person_add_alt_1_rounded, size: 24),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProfileListPage extends StatelessWidget {
  const _ProfileListPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 49),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: ReferenceColors.disabled,
                    size: 28,
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: ReferenceColors.disabled,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          const _TableDivider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TableFrame extends StatelessWidget {
  const _TableFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: ReferenceColors.border, width: 2),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class _TableDivider extends StatelessWidget {
  const _TableDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 2, thickness: 2, color: ReferenceColors.border);
}

class ProfileCourseFlag extends StatelessWidget {
  const ProfileCourseFlag(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    if (id == 'english') {
      return const ReferenceArt(LearningArt.english, width: 31, height: 24);
    }
    if (id == 'chinese') {
      return const SizedBox(
        width: 31,
        height: 24,
        child: FittedBox(child: ChineseFlag()),
      );
    }
    final horizontal = id == 'indonesian';
    final colors = horizontal
        ? const [Color(0xFFFF4B4B), Color(0xFFF3F3F3)]
        : const [Color(0xFF58CC02), Colors.white, Color(0xFFFF4B4B)];
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 31,
          height: 24,
          child: Flex(
            direction: horizontal ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final color in colors)
                Expanded(child: ColoredBox(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
