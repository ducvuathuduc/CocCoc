import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_theme.dart';
import '../application/friends_provider.dart';
import '../domain/friend.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({this.onBack, this.onAddFriends, super.key});

  final VoidCallback? onBack;
  final VoidCallback? onAddFriends;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: ReferenceColors.disabled,
            size: 28,
          ),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Friends',
          style: TextStyle(
            color: ReferenceColors.disabled,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 2,
            color: ReferenceColors.border,
          ),
        ),
      ),
      body: friendsAsync.when(
        data: (friends) {
          final following = friends.where((f) => f.isFollowing).toList();
          final followers = friends.where((f) => f.isFollower).toList();
          return _FriendsBody(
            following: following,
            followers: followers,
            onAddFriends: onAddFriends,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _FriendsBody extends StatefulWidget {
  const _FriendsBody({
    required this.following,
    required this.followers,
    this.onAddFriends,
  });

  final List<Friend> following;
  final List<Friend> followers;
  final VoidCallback? onAddFriends;

  @override
  State<_FriendsBody> createState() => _FriendsBodyState();
}

class _FriendsBodyState extends State<_FriendsBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: ReferenceColors.border, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: ReferenceColors.blue,
                  unselectedLabelColor: ReferenceColors.ink,
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                  indicatorColor: ReferenceColors.blue,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: ReferenceColors.border,
                  dividerHeight: 2,
                  tabs: const [
                    Tab(text: 'FOLLOWING'),
                    Tab(text: 'FOLLOWERS'),
                  ],
                ),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final isFollowing = _tabController.index == 0;
                    final list = isFollowing
                        ? widget.following
                        : widget.followers;

                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No friends here yet',
                            style: TextStyle(
                              color: ReferenceColors.disabled,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 2,
                              thickness: 2,
                              color: ReferenceColors.border,
                            ),
                          _FriendRow(friend: list[i]),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: widget.onAddFriends ?? () {},
            style: TextButton.styleFrom(
              foregroundColor: ReferenceColors.blue,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            child: const Text('ADD FRIENDS'),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: friend.color,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.face_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: const TextStyle(
                      color: ReferenceColors.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _FlagIcon(colors: friend.flagColors),
                      const SizedBox(width: 6),
                      Text(
                        '${friend.xp}',
                        style: const TextStyle(
                          color: ReferenceColors.disabled,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ReferenceColors.disabled,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagIcon extends StatelessWidget {
  const _FlagIcon({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 16,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ReferenceColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in colors) Expanded(child: ColoredBox(color: c)),
        ],
      ),
    );
  }
}
