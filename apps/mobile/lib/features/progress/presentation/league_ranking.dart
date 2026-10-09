import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../account/data/avatar_assets.dart';
import '../../account/domain/avatar_configuration.dart';
import '../../account/presentation/avatar_motion.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/league_ranking_provider.dart';
import '../application/profile_appearance_provider.dart';
import '../domain/league_ranking.dart';

const _bronzeTrophy = ArtRegion(
  'status-league',
  Rect.fromLTWH(78, 501, 126, 229),
);
const _lockedTrophy = ArtRegion(
  'status-league',
  Rect.fromLTWH(650, 506, 168, 222),
);

class LeagueRankingSurface extends ConsumerWidget {
  const LeagueRankingSurface({
    required this.ownAvatar,
    required this.onOpenProfile,
    required this.onSetStatus,
    super.key,
  });

  final Widget ownAvatar;
  final ValueChanged<String> onOpenProfile;
  final VoidCallback onSetStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(leagueRankingProvider);
    final catalog = ref.watch(avatarCatalogProvider).asData?.value;
    final rows = [
      for (final entry in ranking.entries)
        _LeagueRow(
          key: ValueKey('league-entry-${entry.userId}'),
          entry: entry,
          avatar: entry.isOwn
              ? ownAvatar
              : _foreignAvatar(ref, entry.userId, catalog),
          onOpenProfile: onOpenProfile,
          onSetStatus: onSetStatus,
        ),
    ];
    const header = _LeagueHeader();
    const divider = Divider(
      height: 2,
      thickness: 2,
      color: ReferenceColors.border,
    );
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Source keeps the header pinned. Large text and short windows let it
          // scroll so the list and its actions remain reachable.
          if (constraints.maxHeight < 500 ||
              MediaQuery.textScalerOf(context).scale(19) > 28) {
            return ListView(
              key: const PageStorageKey('league'),
              padding: EdgeInsets.zero,
              children: [header, divider, ...rows],
            );
          }
          return Column(
            children: [
              header,
              divider,
              Expanded(
                child: ListView(
                  key: const PageStorageKey('league'),
                  padding: EdgeInsets.zero,
                  children: rows,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _foreignAvatar(WidgetRef ref, String userId, AvatarCatalog? catalog) {
    final appearance = ref.watch(profileAppearanceProvider(userId));
    if (appearance == null || catalog == null) {
      return const Icon(Icons.person, color: ReferenceColors.muted, size: 28);
    }
    final display = catalog.profileDisplays[appearance.background];
    final color = display == null
        ? ReferenceColors.border
        : Color(
            int.parse(
              display.backgroundColor.replaceFirst('#', 'FF'),
              radix: 16,
            ),
          );
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: ClipOval(
        child: AvatarMotion(
          values: appearance.valuesFor(catalog),
          width: 45,
          height: 45,
          animate: false,
        ),
      ),
    );
  }
}

class _LeagueHeader extends StatelessWidget {
  const _LeagueHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('Bronze League', style: headingStyle.copyWith(fontSize: 28)),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: LearningColors.orange,
                  size: 25,
                ),
                SizedBox(width: 6),
                Text(
                  '6 DAYS',
                  style: TextStyle(
                    color: LearningColors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Compete with other learners.',
          style: TextStyle(fontSize: 19, color: ReferenceColors.muted),
        ),
        const SizedBox(height: 26),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const ReferenceArt(_bronzeTrophy, width: 55, height: 100),
              const SizedBox(width: 28),
              for (var index = 0; index < 4; index++) ...[
                const ReferenceArt(_lockedTrophy, width: 72, height: 95),
                if (index < 3) const SizedBox(width: 24),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({
    required this.entry,
    required this.avatar,
    required this.onOpenProfile,
    required this.onSetStatus,
    super.key,
  });

  final LeagueRankingEntry entry;
  final Widget avatar;
  final ValueChanged<String> onOpenProfile;
  final VoidCallback onSetStatus;

  @override
  Widget build(BuildContext context) {
    void openProfile() => onOpenProfile(entry.userId);
    final foreground = entry.isOwn ? LearningColors.green : ReferenceColors.ink;
    final stacked = MediaQuery.textScalerOf(context).scale(19) > 28;
    return Material(
      key: ValueKey('league-row-${entry.userId}'),
      color: entry.isOwn ? const Color(0xFFD7FFB8) : Colors.white,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: 'Rank ${entry.rank}, ${entry.name}, ${entry.xp} XP',
        onTap: openProfile,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: openProfile,
          child: Container(
            constraints: const BoxConstraints(minHeight: 69),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: 34,
                    child: _RankMark(rank: entry.rank),
                  ),
                ),
                const SizedBox(width: 11),
                SizedBox(
                  width: 59,
                  child: Center(
                    child: entry.isOwn
                        ? Semantics(
                            container: true,
                            button: true,
                            label: 'Set your status',
                            onTap: onSetStatus,
                            excludeSemantics: true,
                            child: InkWell(
                              key: const ValueKey('league-own-status'),
                              onTap: onSetStatus,
                              child: avatar,
                            ),
                          )
                        : ExcludeSemantics(
                            child: SizedBox(
                              width: 45,
                              height: 45,
                              child: avatar,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.name,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (stacked)
                          Text(
                            '${entry.xp} XP',
                            style: TextStyle(color: foreground, fontSize: 19),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!stacked) const SizedBox(width: 8),
                if (!stacked)
                  ExcludeSemantics(
                    child: Text(
                      '${entry.xp} XP',
                      style: TextStyle(color: foreground, fontSize: 19),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankMark extends StatelessWidget {
  const _RankMark({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    if (rank > 3) {
      return Text(
        '$rank',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: LearningColors.green,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return ReferenceArt(
      ArtRegion(
        'league-ranking-source',
        Rect.fromLTWH(24, 883.0 + (rank - 1) * 207, 82, 97),
      ),
      width: 27,
      height: 32,
    );
  }
}
