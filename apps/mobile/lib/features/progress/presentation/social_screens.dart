import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/character_motion.dart';
import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../account/application/avatar_controller.dart';
import '../../account/presentation/avatar_motion.dart';
import '../application/preview_controller.dart';
import '../application/social_controller.dart';

const _statusArt = {
  'cool': ArtRegion('status-icons', Rect.fromLTWH(54, 1664, 147, 127)),
  'party': ArtRegion('status-icons', Rect.fromLTWH(263, 1670, 68, 96)),
  'flex': ArtRegion('status-icons', Rect.fromLTWH(449, 1655, 99, 108)),
  'eyes': ArtRegion('status-icons', Rect.fromLTWH(625, 1668, 113, 89)),
  'popcorn': ArtRegion('status-icons', Rect.fromLTWH(812, 1658, 106, 112)),
  'english': LearningArt.english,
  'angry': ArtRegion('status-icons', Rect.fromLTWH(54, 1832, 148, 154)),
  'hundred': ArtRegion('status-icons', Rect.fromLTWH(258, 1838, 113, 139)),
  'poop': ArtRegion('status-icons', Rect.fromLTWH(443, 1854, 113, 110)),
  'trophy': ArtRegion('status-icons', Rect.fromLTWH(625, 1848, 110, 123)),
  'fries': ArtRegion('status-icons', Rect.fromLTWH(812, 1848, 112, 123)),
  'cat': ArtRegion('status-icons', Rect.fromLTWH(990, 1857, 122, 105)),
};
const _statusNames = {
  'cool': 'Cool Duo',
  'party': 'Party',
  'flex': 'Flex',
  'eyes': 'Eyes',
  'popcorn': 'Popcorn',
  'english': 'English',
  'angry': 'Angry Duo',
  'hundred': 'One hundred',
  'poop': 'Poop',
  'trophy': 'Trophy',
  'fries': 'Fries',
  'cat': 'Cat',
};

class StatusAvatar extends StatelessWidget {
  const StatusAvatar({
    required this.name,
    this.status,
    this.size = 60,
    this.portrait,
    super.key,
  });
  final String name;
  final String? status;
  final double size;
  final Widget? portrait;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size + 14,
    height: size + 12,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF7F7F7),
              border: Border.all(color: const Color(0xFFB0B0B0), width: 2),
            ),
            alignment: Alignment.center,
            child: portrait == null
                ? Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: size * .47,
                      color: ReferenceColors.disabled,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : ClipOval(child: portrait),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: size * .52,
            height: size * .52,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(size * .21),
              border: Border.all(color: ReferenceColors.border, width: 2),
            ),
            child: _statusArt[status] != null
                ? FittedBox(
                    child: ReferenceArt(
                      _statusArt[status]!,
                      width: _statusArt[status]!.source.width,
                      height: _statusArt[status]!.source.height,
                    ),
                  )
                : const Icon(
                    Icons.sentiment_satisfied_alt,
                    color: ReferenceColors.border,
                  ),
          ),
        ),
        Positioned(
          right: 11,
          bottom: 0,
          child: Container(
            width: size * .2,
            height: size * .2,
            decoration: BoxDecoration(
              color: ReferenceColors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> showStatusPicker(BuildContext context, WidgetRef ref) async {
  ref.read(statusControllerProvider.notifier).begin();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const StatusPickerSheet(),
  );
  if (context.mounted) ref.read(statusControllerProvider.notifier).cancel();
}

class StatusPickerSheet extends ConsumerWidget {
  const StatusPickerSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statusControllerProvider);
    final wallet = ref.watch(previewWalletProvider);
    final vm = ref.read(statusControllerProvider.notifier);
    final preview = ref.watch(previewControllerProvider);
    final avatar = ref.watch(avatarControllerProvider);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .94,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: ReferenceColors.disabled,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ReferenceArt(LearningArt.gem, width: 24, height: 29),
                    const SizedBox(width: 8),
                    Text(
                      '$wallet',
                      style: const TextStyle(
                        color: LearningColors.blue,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Set your status',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              StatusAvatar(
                name: preview.name,
                status: state.draft,
                size: 75,
                portrait: avatar.hasAvatar
                    ? AvatarMotion(
                        values: avatar.saved,
                        width: 75,
                        height: 75,
                        animate: false,
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = textScale > 1.3 ? 4 : 6;
                  final cell =
                      (constraints.maxWidth - (columns - 1) * 9) / columns;
                  return Wrap(
                    spacing: 9,
                    runSpacing: 12,
                    children: [
                      for (final id in statusIds)
                        SizedBox(
                          width: cell,
                          height: cell + 4,
                          child: Semantics(
                            button: true,
                            selected: state.draft == id,
                            label:
                                '${_statusNames[id]} status${vm.unlocked(id) ? '' : ', 500 gems'}',
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Material(
                                    color: state.draft == id
                                        ? ReferenceColors.blueFill
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                      side: BorderSide(
                                        width: 2,
                                        color: state.draft == id
                                            ? ReferenceColors.blueBorder
                                            : ReferenceColors.border,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(13),
                                      onTap: () => vm.choose(id),
                                      child: Padding(
                                        padding: const EdgeInsets.all(7),
                                        child: FittedBox(
                                          child: ReferenceArt(
                                            _statusArt[id]!,
                                            width: _statusArt[id]!.source.width,
                                            height:
                                                _statusArt[id]!.source.height,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!vm.unlocked(id))
                                  const Positioned(
                                    right: -3,
                                    top: -7,
                                    child: ReferenceArt(
                                      LearningArt.gem,
                                      width: 17,
                                      height: 20,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              ReferenceButton(
                label: 'DONE',
                backgroundColor: LearningColors.blue,
                edgeColor: LearningColors.blueDark,
                onPressed: () async {
                  if (vm.save()) {
                    Navigator.pop(context);
                    return;
                  }
                  await _purchase(context, ref);
                },
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () {
                  vm.clear();
                  Navigator.pop(context);
                },
                child: const Text(
                  'CLEAR STATUS',
                  style: TextStyle(
                    color: LearningColors.blue,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchase(BuildContext context, WidgetRef ref) async {
    final vm = ref.read(statusControllerProvider.notifier);
    final name = _statusNames[ref.read(statusControllerProvider).draft];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unlock $name?'),
        content: const Text('Use 500 gems to unlock this status.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('USE GEMS'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    if (vm.purchaseSelected()) {
      vm.save();
      Navigator.pop(context);
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Not enough gems'),
          content: const Text(
            'Your status choice is saved. Earn more gems by learning.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

void _back(BuildContext context) {
  if (GoRouter.maybeOf(context) case final router?) {
    router.canPop() ? router.pop() : router.go('/home');
  } else if (Navigator.canPop(context)) {
    Navigator.pop(context);
  }
}

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(previewControllerProvider).following;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => _back(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: ReferenceColors.muted,
                    ),
                  ),
                  const Text(
                    'Feed',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ReferenceColors.border),
            Expanded(
              child: following.isEmpty
                  ? const _FeedSuggestions()
                  : const _FeedPosts(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedSuggestions extends ConsumerWidget {
  const _FeedSuggestions();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedControllerProvider);
    final following = ref.watch(previewControllerProvider).following;
    final count = state.selectedSuggestions.difference(following).length;
    final vm = ref.read(feedControllerProvider.notifier);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
            children: [
              const Center(
                child: ReferenceArt(
                  ArtRegion(
                    'feed-suggestions',
                    Rect.fromLTWH(315, 449, 557, 509),
                  ),
                  width: 200,
                  height: 183,
                ),
              ),
              const SizedBox(height: 24),
              RichText(
                textAlign: TextAlign.center,
                textScaler: MediaQuery.textScalerOf(context),
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'DuolingoSans',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: ReferenceColors.ink,
                    height: 1.2,
                  ),
                  children: [
                    TextSpan(
                      text: 'Add friends',
                      style: TextStyle(color: Color(0xFF4EAAED)),
                    ),
                    TextSpan(text: ' to see their progress and fun updates!'),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              for (final name in suggestedFriends)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _FeedAvatar(name),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'You may know each other',
                    style: TextStyle(color: ReferenceColors.muted),
                  ),
                  trailing: IconButton(
                    tooltip: 'Select $name',
                    isSelected: state.selectedSuggestions.contains(name),
                    onPressed: () => vm.toggleSuggestion(name),
                    icon: const Icon(
                      Icons.check_box_outline_blank,
                      color: Color(0xFF4EAAED),
                    ),
                    selectedIcon: const Icon(
                      Icons.check_box,
                      color: Color(0xFF4EAAED),
                    ),
                  ),
                  onTap: () => vm.toggleSuggestion(name),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: ReferenceColors.blueFill,
                  child: Icon(Icons.person_add, color: LearningColors.blue),
                ),
                title: const Text(
                  'Find more friends',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: ReferenceColors.muted,
                ),
                onTap: () => context.push('/friends'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: ReferenceButton(
            label: 'ADD $count FRIEND${count == 1 ? '' : 'S'}',
            backgroundColor: const Color(0xFF4EAAED),
            edgeColor: const Color(0xFF3C91D0),
            leading: const Icon(Icons.person_add, color: Colors.white),
            onPressed: count == 0 ? null : () => vm.addSuggested(),
          ),
        ),
      ],
    );
  }
}

class _FeedAvatar extends StatelessWidget {
  const _FeedAvatar(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => ClipOval(
    child: ReferenceArt(
      name == 'Alex'
          ? const ArtRegion('feed-learning', Rect.fromLTWH(73, 363, 132, 133))
          : const ArtRegion('feed-sentences', Rect.fromLTWH(73, 373, 134, 134)),
      width: 44,
      height: 44,
    ),
  );
}

class _FeedPosts extends ConsumerWidget {
  const _FeedPosts();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(previewControllerProvider).following.toList()
      ..sort();
    return ListView(
      key: const PageStorageKey('english-feed'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        for (final name in names) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeedAvatar(name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name followed you back!',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '33 mins',
                      style: TextStyle(
                        color: ReferenceColors.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 190,
              child: ReferenceButton(
                label: 'VIEW PROFILE',
                outlined: true,
                foregroundColor: ReferenceColors.ink,
                onPressed: () => context.push('/profile/$name'),
              ),
            ),
          ),
          const _PostDivider(),
        ],
        const _LearningPost(kind: 'cartoons'),
        const _PostDivider(),
        const _SentencePost(
          id: 'stores',
          sentence: 'The stores are big.',
          translation: 'Các cửa hàng lớn.',
          character: LessonCharacter.oscar,
          art: ArtRegion('feed-sentences', Rect.fromLTWH(855, 585, 183, 347)),
          baseLikes: 1,
        ),
        const _PostDivider(),
        const _SentencePost(
          id: 'restaurant',
          sentence: 'The restaurant is small.',
          translation: 'Nhà hàng nhỏ.',
          character: LessonCharacter.eddy,
          art: ArtRegion('feed-sentences', Rect.fromLTWH(835, 1657, 223, 363)),
        ),
        const _PostDivider(),
        const _FirstFriendPost(),
        const _PostDivider(),
        const _LearningPost(kind: 'streak'),
      ],
    );
  }
}

class _PostDivider extends StatelessWidget {
  const _PostDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 27),
    child: Divider(height: 2, thickness: 2, color: Color(0xFFF3F3F3)),
  );
}

class _SentencePost extends ConsumerWidget {
  const _SentencePost({
    required this.id,
    required this.sentence,
    required this.translation,
    required this.character,
    required this.art,
    this.baseLikes = 0,
  });
  final String id, sentence, translation;
  final LessonCharacter character;
  final ArtRegion art;
  final int baseLikes;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          _FeedAvatar('Sam Lee'),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sam shared a sentence', style: TextStyle(fontSize: 18)),
                Text(
                  '2 days',
                  style: TextStyle(color: ReferenceColors.muted, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ReferenceArt(
                    LearningArt.english,
                    width: 27,
                    height: 21,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    sentence,
                    style: const TextStyle(fontSize: 22, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    translation,
                    style: const TextStyle(
                      color: ReferenceColors.muted,
                      fontSize: 17,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          CharacterMotion(
            character: character,
            width: 83,
            height: 146,
            fallback: ReferenceArt(art, width: 83, height: 146),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _PostActions(id: id, baseLikes: baseLikes),
      if (baseLikes > 0)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Row(
            children: [
              _FeedAvatar('Alex'),
              SizedBox(width: 10),
              Expanded(
                child: Text('Liked by Alex', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
    ],
  );
}

class _FirstFriendPost extends StatelessWidget {
  const _FirstFriendPost();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          _FeedAvatar('Sam Lee'),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sam Lee',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                Text(
                  '3 days',
                  style: TextStyle(color: ReferenceColors.muted, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const Row(
        children: [
          Expanded(
            child: Text(
              'Added their first friend!',
              style: TextStyle(fontSize: 20, height: 1.3),
            ),
          ),
          SizedBox(width: 8),
          ReferenceArt(
            ArtRegion('feed-friend', Rect.fromLTWH(770, 339, 329, 304)),
            width: 112,
            height: 104,
          ),
        ],
      ),
      const SizedBox(height: 16),
      const _PostActions(id: 'first-friend', comment: true),
    ],
  );
}

class _PostActions extends ConsumerWidget {
  const _PostActions({
    required this.id,
    this.baseLikes = 0,
    this.comment = false,
  });
  final String id;
  final int baseLikes;
  final bool comment;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedControllerProvider);
    final liked = state.liked.contains(id);
    final count = baseLikes + (liked ? 1 : 0);
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _ActionButton(
          label: 'Like $id',
          selected: liked,
          icon: liked ? Icons.favorite : Icons.favorite_border,
          count: count,
          onTap: () => ref.read(feedControllerProvider.notifier).like(id),
        ),
        if (comment)
          _ActionButton(
            label: 'Comment $id',
            icon: Icons.chat_bubble,
            count: state.comments[id]?.length ?? 0,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => FeedCommentSheet(id: id),
            ),
          ),
        _ActionButton(
          label: 'Share $id',
          icon: Icons.ios_share,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      id == 'first-friend'
                          ? 'Learning is better together!'
                          : 'I’m practicing English!',
                    ),
                    const SizedBox(height: 20),
                    ReferenceButton(
                      label: 'CLOSE',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.count = 0,
    this.selected = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int count;
  final bool selected;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: const BorderSide(color: ReferenceColors.border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected ? LearningColors.red : ReferenceColors.ink,
            size: 27,
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                color: ReferenceColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class FeedCommentSheet extends ConsumerStatefulWidget {
  const FeedCommentSheet({required this.id, super.key});
  final String id;
  @override
  ConsumerState<FeedCommentSheet> createState() => _FeedCommentState();
}

class _FeedCommentState extends ConsumerState<FeedCommentSheet> {
  final draft = TextEditingController();
  String? error;
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments =
        ref.watch(feedControllerProvider).comments[widget.id] ?? const [];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                if (comments.isEmpty) const Text('Be the first to celebrate!'),
                for (final text in comments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(text, style: const TextStyle(fontSize: 18)),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: draft,
                  maxLength: 280,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Write a comment',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 12),
                ReferenceButton(
                  label: 'POST',
                  backgroundColor: LearningColors.blue,
                  edgeColor: LearningColors.blueDark,
                  onPressed: () {
                    final result = ref
                        .read(feedControllerProvider.notifier)
                        .comment(widget.id, draft.text);
                    setState(() => error = result);
                    if (result == null) draft.clear();
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningPost extends StatelessWidget {
  const _LearningPost({required this.kind});
  final String kind;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LayoutBuilder(
        builder: (context, box) => ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ReferenceArt(
            kind == 'streak'
                ? const ArtRegion(
                    'feed-friend',
                    Rect.fromLTWH(72, 1004, 1035, 391),
                  )
                : const ArtRegion(
                    'feed-learning',
                    Rect.fromLTWH(72, 855, 1035, 398),
                  ),
            width: box.maxWidth,
            height: box.maxWidth * .385,
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (kind != 'streak')
        const Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              label: Text(
                'LEARNING',
                style: TextStyle(
                  color: Color(0xFFCD8627),
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: Color(0xFFFDF5D6),
              side: BorderSide.none,
            ),
            Text(
              '2 days',
              style: TextStyle(
                color: ReferenceColors.muted,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      Text(
        kind == 'streak'
            ? 'Complete a lesson every day to maintain your streak!'
            : 'You, a grown-up, watching cartoons. It’s called studying 😎',
        style: const TextStyle(fontSize: 22, height: 1.45),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 200,
          child: ReferenceButton(
            label: kind == 'streak' ? 'START A LESSON' : 'TELL ME MORE',
            outlined: true,
            foregroundColor: ReferenceColors.ink,
            onPressed: () => kind == 'streak'
                ? context.go('/home')
                : context.push('/feed/learning'),
          ),
        ),
      ),
    ],
  );
}

class FeedLearningScreen extends StatelessWidget {
  const FeedLearningScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => _back(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          const Text(
            'Learn with familiar stories',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          const ReferenceArt(
            ArtRegion('feed-learning', Rect.fromLTWH(72, 855, 1035, 398)),
            width: 320,
            height: 123,
          ),
          const SizedBox(height: 24),
          const Text(
            'Try a familiar cartoon in English. Knowing the story can make the dialogue easier to follow. Use subtitles for reading practice, or try a short scene without them for listening practice.',
            style: TextStyle(fontSize: 20, height: 1.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Based on Duolingo’s guide to children’s materials for language learning.',
            style: TextStyle(color: ReferenceColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 30),
          ReferenceButton(
            label: 'PRACTICE ENGLISH',
            onPressed: () => context.go('/practice'),
          ),
        ],
      ),
    ),
  );
}
