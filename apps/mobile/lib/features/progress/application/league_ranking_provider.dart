import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../learning/application/learning_controller.dart';
import '../domain/league_ranking.dart';
import 'preview_controller.dart';
import 'profile_summary_provider.dart';

const _fixtureUserIds = <String>[
  'Alex',
  'Maria',
  'Lucas',
  'Anna',
  'Samira',
  'Noah',
  'Emma',
];

final leagueRankingProvider = Provider<LeagueRanking>((ref) {
  final candidates =
      <_LeagueCandidate>[
        for (final (order, userId) in _fixtureUserIds.indexed)
          if (ref.watch(profileSummaryProvider(userId)) case final profile?)
            _LeagueCandidate(
              userId: profile.userId,
              name: profile.name,
              xp: profile.xp,
              order: order,
              isOwn: false,
            ),
        _LeagueCandidate(
          userId: 'me',
          name: ref.watch(previewControllerProvider).name,
          xp: ref.watch(learningStateProvider).xp,
          order: _fixtureUserIds.length,
          isOwn: true,
        ),
      ]..sort((a, b) {
        final byXp = b.xp.compareTo(a.xp);
        return byXp == 0 ? a.order.compareTo(b.order) : byXp;
      });

  return LeagueRanking(
    entries: [
      for (final (index, candidate) in candidates.indexed)
        LeagueRankingEntry(
          userId: candidate.userId,
          name: candidate.name,
          xp: candidate.xp,
          rank: index + 1,
          isOwn: candidate.isOwn,
        ),
    ],
  );
});

class _LeagueCandidate {
  const _LeagueCandidate({
    required this.userId,
    required this.name,
    required this.xp,
    required this.order,
    required this.isOwn,
  });

  final String userId;
  final String name;
  final int xp;
  final int order;
  final bool isOwn;
}
