import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/preview_controller.dart';
import '../application/streak_controller.dart';

const streakOrange = Color(0xFFFF6A22);
const streakBlue = Color(0xFF1CB0F6);
const streakGray = Color(0xFFAFAFAF);

abstract final class StreakArt {
  static const perfect = ArtRegion(
    'streak-perfect',
    Rect.fromLTWH(820, 520, 280, 350),
  );
  static const frozen = ArtRegion(
    'streak-frozen',
    Rect.fromLTWH(800, 518, 280, 386),
  );
  static const friends = ArtRegion(
    'streak-friends',
    Rect.fromLTWH(0, 476, 1179, 466),
  );
  static const alex = ArtRegion(
    'streak-avatar',
    Rect.fromLTWH(96, 720, 128, 128),
  );
  static const shield = ArtRegion(
    'streak-protection',
    Rect.fromLTWH(120, 800, 185, 210),
  );
  static const appIcons = ArtRegion(
    'streak-protection',
    Rect.fromLTWH(118, 1338, 200, 205),
  );
  static const chest = ArtRegion(
    'streak-protection',
    Rect.fromLTWH(118, 1905, 200, 205),
  );
}

void closeStreak(BuildContext context) =>
    context.canPop() ? context.pop() : context.go('/home');

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(streakControllerProvider),
        fixture = ref.watch(streakFixtureProvider);
    final background = s.showFriends
        ? streakOrange
        : fixture?.appearance == StreakAppearance.frozen
        ? const Color(0xFFDFF5FF)
        : Colors.white;
    final foreground = s.showFriends ? Colors.white : ReferenceColors.ink;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 75 : 55,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close streak',
                    onPressed: () => closeStreak(context),
                    icon: Icon(Icons.close, size: 30, color: foreground),
                  ),
                  Expanded(
                    child: Text(
                      'Streak',
                      textAlign: TextAlign.center,
                      style: headingStyle.copyWith(
                        fontSize: 23,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (!s.showFriends)
                    IconButton(
                      tooltip: 'Preview streak share',
                      onPressed: () => showStreakShare(context, ref),
                      icon: Icon(Icons.ios_share, size: 28, color: foreground),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Row(
              children: [
                for (final friends in [false, true])
                  Expanded(
                    child: InkWell(
                      onTap: () => ref
                          .read(streakControllerProvider.notifier)
                          .selectFriends(friends),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              friends ? 'FRIENDS' : 'PERSONAL',
                              style: TextStyle(
                                fontSize: 17,
                                letterSpacing: .6,
                                fontWeight: FontWeight.w700,
                                color: s.showFriends
                                    ? Colors.white
                                    : s.showFriends == friends
                                    ? streakBlue
                                    : ReferenceColors.ink,
                              ),
                            ),
                          ),
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: s.showFriends == friends
                                  ? (s.showFriends ? Colors.white : streakBlue)
                                  : s.showFriends
                                  ? const Color(0xFFFF9D6C)
                                  : ReferenceColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: s.showFriends
                  ? const _FriendStreaks()
                  : const _PersonalStreak(),
            ),
          ],
        ),
      ),
    );
  }
}

void showStreakShare(BuildContext context, WidgetRef ref) {
  final days =
      ref.read(streakFixtureProvider)?.days ??
      ref.read(learningStateProvider).streak;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ReferenceArt(StreakArt.perfect, width: 100, height: 125),
            Text(
              '$days day streak!',
              style: headingStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Share preview',
              style: TextStyle(fontSize: 18, color: streakGray),
            ),
            const SizedBox(height: 20),
            ReferenceButton(
              label: 'DONE',
              backgroundColor: streakBlue,
              edgeColor: const Color(0xFF1899D6),
              onPressed: () => Navigator.pop(sheet),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PersonalStreak extends ConsumerWidget {
  const _PersonalStreak();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learning = ref.watch(learningStateProvider),
        fixture = ref.watch(streakFixtureProvider),
        s = ref.watch(streakControllerProvider),
        now = ref.watch(streakClockProvider);
    final days = fixture?.days ?? learning.streak,
        frozen = fixture?.appearance == StreakAppearance.frozen;
    final fixtureDate = fixture?.month ?? now;
    final current =
        s.month.year == fixtureDate.year && s.month.month == fixtureDate.month;
    final practiced = current
        ? fixture?.practiced ??
              (learning.completedLessons > 0 ? {now.day} : <int>{})
        : <int>{};
    final freezes = current ? fixture?.frozen ?? <int>{} : <int>{};
    final color = frozen ? const Color(0xFF84DDFC) : streakOrange;
    return ListView(
      key: const PageStorageKey('personal-streak'),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$days',
                      style: TextStyle(
                        fontSize: 82,
                        height: 1.1,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'day streak!',
                      style: TextStyle(
                        fontSize: 23,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ReferenceArt(
                frozen ? StreakArt.frozen : StreakArt.perfect,
                width: 100,
                height: frozen ? 138 : 125,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: StreakOutline(
            color: frozen ? Colors.white : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  frozen ? Icons.timer_outlined : Icons.local_fire_department,
                  color: frozen ? LearningColors.red : streakOrange,
                  size: 34,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        frozen
                            ? 'Less than 3 hours to extend your $days day streak!'
                            : days == 0
                            ? 'Start your streak by doing a lesson today!'
                            : 'Keep your Perfect Streak by doing a lesson every day!',
                        style: const TextStyle(
                          fontSize: 18,
                          color: ReferenceColors.muted,
                        ),
                      ),
                      if (frozen || days == 0)
                        TextButton(
                          onPressed: () => context.go('/home'),
                          child: const Text(
                            'EXTEND STREAK',
                            style: TextStyle(
                              fontSize: 16,
                              color: streakBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${streakMonths[s.month.month - 1]} ${s.month.year}',
                        style: headingStyle.copyWith(fontSize: 25),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => ref
                          .read(streakControllerProvider.notifier)
                          .changeMonth(-1),
                      icon: const Icon(Icons.chevron_left, color: streakGray),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => ref
                          .read(streakControllerProvider.notifier)
                          .changeMonth(1),
                      icon: const Icon(Icons.chevron_right, color: streakGray),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _stat(
                        practiced.length,
                        'Days practiced',
                        Icons.check_circle,
                        streakOrange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _stat(
                        freezes.length,
                        'Freezes used',
                        Icons.ac_unit,
                        streakBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _StreakCalendar(
                  month: s.month,
                  practiced: practiced,
                  frozen: freezes,
                  perfect: fixture?.appearance == StreakAppearance.perfect,
                  milestone: current
                      ? (fixture != null
                            ? (frozen ? 15 : 13)
                            : (now.day + 3).clamp(
                                1,
                                DateTime(now.year, now.month + 1, 0).day,
                              ))
                      : null,
                ),
                const SizedBox(height: 26),
                const Text('Streak Goal', style: headingStyle),
                const SizedBox(height: 16),
                StreakOutline(
                  child: Row(
                    children: [
                      for (final goal
                          in days > 30
                              ? [(days ~/ 25) * 25, (days ~/ 25 + 1) * 25]
                              : [1, 3, 5])
                        Expanded(
                          child: Column(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: days >= goal ? streakOrange : streakGray,
                                size: 30,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$goal',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: days >= goal
                                      ? streakOrange
                                      : streakGray,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Streak Protection', style: headingStyle),
                const SizedBox(height: 16),
                StreakOutline(
                  child: _Benefit(
                    art: StreakArt.shield,
                    title: '7-day Streak Shield',
                    action:
                        ref
                            .watch(previewControllerProvider)
                            .purchases
                            .contains('streak-shield-local')
                        ? 'EQUIPPED'
                        : 'BUY FOR  ◆ 3000',
                    onTap:
                        ref
                            .watch(previewControllerProvider)
                            .purchases
                            .contains('streak-shield-local')
                        ? null
                        : () => _buyShield(context, ref),
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Streak Society', style: headingStyle),
                const SizedBox(height: 16),
                if (days < 7)
                  StreakOutline(
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: streakGray, size: 45),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            'Reach a 7 day streak to join the Streak Society!',
                            style: headingStyle.copyWith(
                              fontSize: 20,
                              color: streakGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  StreakOutline(
                    child: _Benefit(
                      art: StreakArt.appIcons,
                      title: 'New App Icon',
                      detail: 'Show off your streak status with this app icon.',
                      action: 'CHANGE APP ICON',
                      onTap: () => _iconSheet(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const StreakOutline(
                    child: _Benefit(
                      art: StreakArt.chest,
                      title: 'Special Milestone Chest',
                      detail: 'Reach a 875 day streak to earn this reward',
                      action: 'LOCKED',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(int value, String label, IconData icon, Color color) =>
      StreakOutline(
        padding: 12,
        child: Row(
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: headingStyle.copyWith(fontSize: 20)),
                  Text(
                    label,
                    style: const TextStyle(color: streakGray, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  void _buyShield(BuildContext context, WidgetRef ref) {
    if (ref.read(previewControllerProvider.notifier).buyStreakShield()) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Not enough gems', style: headingStyle),
              const SizedBox(height: 12),
              const Text(
                'You need 3000 gems for a Streak Shield.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ReferenceButton(
                label: 'GO TO SHOP',
                backgroundColor: streakBlue,
                edgeColor: const Color(0xFF1899D6),
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push('/shop');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _iconSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ReferenceArt(StreakArt.appIcons, width: 120, height: 123),
            const SizedBox(height: 12),
            const Text(
              'Streak app icon preview',
              style: headingStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ReferenceButton(
              label: 'DONE',
              onPressed: () => Navigator.pop(sheet),
            ),
          ],
        ),
      ),
    ),
  );
}

const streakMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _StreakCalendar extends StatelessWidget {
  const _StreakCalendar({
    required this.month,
    required this.practiced,
    required this.frozen,
    required this.perfect,
    this.milestone,
  });
  final DateTime month;
  final Set<int> practiced, frozen;
  final bool perfect;
  final int? milestone;
  @override
  Widget build(BuildContext context) {
    final length = DateTime(month.year, month.month + 1, 0).day,
        offset = month.weekday % 7;
    return StreakOutline(
      padding: 16,
      child: Column(
        children: [
          Row(
            children: [
              for (final name in ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'])
                Expanded(
                  child: Center(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        color: streakGray,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          for (var week = 0; week < ((length + offset) / 7).ceil(); week++)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = week * 7 + i - offset + 1;
                          if (day < 1 || day > length) {
                            return const SizedBox(height: 33);
                          }
                          final active = practiced.contains(day),
                              ice = frozen.contains(day);
                          final shape = BorderRadius.horizontal(
                            left: Radius.circular(
                              !practiced.contains(day - 1) || i == 0 ? 18 : 0,
                            ),
                            right: Radius.circular(
                              !practiced.contains(day + 1) || i == 6 ? 18 : 0,
                            ),
                          );
                          return Semantics(
                            label:
                                '${streakMonths[month.month - 1]} $day${active
                                    ? ', practiced'
                                    : ice
                                    ? ', freeze used'
                                    : ''}',
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: shape,
                                gradient: active && perfect
                                    ? const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFFFF4B4B),
                                          Color(0xFFFFB000),
                                        ],
                                      )
                                    : null,
                                color: active && !perfect
                                    ? const Color(0xFFFFF5DD)
                                    : null,
                              ),
                              child: ice
                                  ? const Icon(
                                      Icons.ac_unit,
                                      color: streakBlue,
                                      size: 24,
                                    )
                                  : day == milestone
                                  ? Tooltip(
                                      message: 'Next streak milestone',
                                      triggerMode: TooltipTriggerMode.tap,
                                      child: const Icon(
                                        Icons.flag_rounded,
                                        color: Color(0xFFFFB000),
                                        size: 24,
                                      ),
                                    )
                                  : Text(
                                      '$day',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: active
                                            ? perfect
                                                  ? Colors.white
                                                  : const Color(0xFFFF9600)
                                            : streakGray,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class StreakAvatar extends StatelessWidget {
  const StreakAvatar({required this.name, this.size = 44, super.key});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => name == 'Alex Smith'
      ? ClipOval(
          child: ReferenceArt(StreakArt.alex, width: size, height: size),
        )
      : CircleAvatar(
          radius: size / 2,
          backgroundColor: ReferenceColors.blueFill,
          child: Text(
            name.isEmpty ? '?' : name[0],
            style: TextStyle(
              fontSize: size / 2,
              color: streakBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
}

class _FriendStreaks extends ConsumerWidget {
  const _FriendStreaks();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(streakControllerProvider),
        vm = ref.read(streakControllerProvider.notifier);
    return ListView(
      key: const PageStorageKey('friend-streak'),
      padding: EdgeInsets.zero,
      children: [
        LayoutBuilder(
          builder: (context, c) => ReferenceArt(
            StreakArt.friends,
            width: c.maxWidth,
            height: c.maxWidth * 466 / 1179,
          ),
        ),
        ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.incoming.isNotEmpty && !s.editing) ...[
                  const Text('New Invites', style: headingStyle),
                  const SizedBox(height: 16),
                  for (final person in streakPeople.where(
                    (p) => s.incoming.contains(p.id),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: StreakOutline(
                        padding: 12,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width:
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.4
                                  ? double.infinity
                                  : 160,
                              child: Row(
                                children: [
                                  StreakAvatar(name: person.name),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      person.name,
                                      style: headingStyle.copyWith(
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: s.remaining > 0
                                  ? () => vm.accept(person.id)
                                  : null,
                              child: const Text(
                                'ACCEPT',
                                style: TextStyle(
                                  color: streakBlue,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Decline ${person.name}',
                              onPressed: () => vm.decline(person.id),
                              icon: const Icon(
                                Icons.close,
                                color: streakGray,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                Row(
                  children: [
                    const Expanded(
                      child: Text('Friend Streaks', style: headingStyle),
                    ),
                    TextButton(
                      onPressed: vm.toggleEdit,
                      child: Text(
                        s.editing ? 'DONE' : 'EDIT',
                        style: const TextStyle(
                          color: streakBlue,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreakOutline(
                  padding: 0,
                  child: Column(
                    children: [
                      for (final person in streakPeople.where(
                        (p) => s.friends.containsKey(p.id),
                      ))
                        Container(
                          constraints: const BoxConstraints(minHeight: 74),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: s.friends.keys.first == person.id
                              ? null
                              : const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: ReferenceColors.border,
                                      width: 2,
                                    ),
                                  ),
                                ),
                          child: Row(
                            children: [
                              StreakAvatar(name: person.name),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person.name,
                                      style: headingStyle.copyWith(
                                        fontSize: 21,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (s.friends[person.id] ==
                                        FriendStreakStatus.pending)
                                      const Text(
                                        'Request pending',
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: streakGray,
                                        ),
                                      )
                                    else
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.local_fire_department,
                                            color: streakGray,
                                            size: 21,
                                          ),
                                          Text(
                                            ' 0',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: streakGray,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              if (s.editing)
                                IconButton(
                                  tooltip: 'End streak with ${person.name}',
                                  onPressed: () =>
                                      _remove(context, ref, person),
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: LearningColors.red,
                                    size: 30,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (!s.editing)
                        for (var i = 0; i < s.remaining; i++)
                          InkWell(
                            onTap: () => context.push('/streak/invite'),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 74),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              decoration: i == 0 && s.friends.isEmpty
                                  ? null
                                  : const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: ReferenceColors.border,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: streakGray,
                                    size: 44,
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Invite a friend',
                                      style: TextStyle(
                                        color: streakGray,
                                        fontSize: 23,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (s.editing && s.friends.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No Friend Streaks yet',
                            style: TextStyle(color: streakGray, fontSize: 18),
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
    );
  }

  void _remove(BuildContext context, WidgetRef ref, StreakPerson person) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreakAvatar(name: person.name, size: 80),
                const SizedBox(height: 22),
                Text(
                  'End your Friend Streak with ${person.name}?',
                  textAlign: TextAlign.center,
                  style: headingStyle.copyWith(fontSize: 25),
                ),
                const SizedBox(height: 32),
                ReferenceButton(
                  label: 'END FRIEND STREAK',
                  backgroundColor: streakBlue,
                  edgeColor: const Color(0xFF1899D6),
                  onPressed: () {
                    ref
                        .read(streakControllerProvider.notifier)
                        .remove(person.id);
                    Navigator.pop(sheet);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text(
                    'NO THANKS',
                    style: TextStyle(
                      color: streakBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class FriendStreakInviteScreen extends ConsumerWidget {
  const FriendStreakInviteScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(streakControllerProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              tooltip: 'Close invites',
              onPressed: () => closeStreak(context),
              icon: const Icon(Icons.close, color: streakGray, size: 30),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  Text(
                    'Invite friends to start new Friend Streaks!',
                    style: headingStyle.copyWith(fontSize: 25),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${s.remaining} invites remaining',
                    style: const TextStyle(fontSize: 20, color: streakGray),
                  ),
                  const SizedBox(height: 26),
                  for (final person in streakPeople)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StreakOutline(
                        padding: 12,
                        child: Row(
                          children: [
                            StreakAvatar(name: person.name),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                person.name,
                                style: headingStyle.copyWith(fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextButton(
                                onPressed:
                                    s.remaining <= 0 ||
                                        s.friends.containsKey(person.id) ||
                                        s.incoming.contains(person.id)
                                    ? null
                                    : () => ref
                                          .read(
                                            streakControllerProvider.notifier,
                                          )
                                          .invite(person.id),
                                style: TextButton.styleFrom(
                                  side: const BorderSide(
                                    color: ReferenceColors.border,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  s.friends.containsKey(person.id)
                                      ? 'INVITED'
                                      : s.incoming.contains(person.id)
                                      ? 'REQUESTED'
                                      : 'INVITE',
                                  style: TextStyle(
                                    color: s.friends.containsKey(person.id)
                                        ? ReferenceColors.green
                                        : s.remaining == 0
                                        ? streakGray
                                        : streakBlue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
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
          ],
        ),
      ),
    );
  }
}

class StreakOutline extends StatelessWidget {
  const StreakOutline({
    required this.child,
    this.padding = 16,
    this.color,
    super.key,
  });
  final Widget child;
  final double padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color ?? ReferenceColors.border, width: 2),
    ),
    child: child,
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.art,
    required this.title,
    required this.action,
    this.detail,
    this.onTap,
  });
  final ArtRegion art;
  final String title, action;
  final String? detail;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ReferenceArt(art, width: 70, height: 78),
      const SizedBox(width: 18),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: headingStyle.copyWith(fontSize: 21)),
            if (detail != null) ...[
              const SizedBox(height: 12),
              Text(
                detail!,
                style: const TextStyle(
                  fontSize: 18,
                  color: ReferenceColors.muted,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (onTap != null)
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 16,
                    color: streakBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Text(
                action,
                style: const TextStyle(
                  fontSize: 16,
                  color: streakGray,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
