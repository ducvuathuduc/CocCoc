import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/presentation/signup_flow.dart';
import '../application/results_providers.dart';
import '../data/results_repository.dart';
import 'results_extra_screens.dart';
import 'results_screens.dart';
import 'score_unlock_screen.dart';

/// Post-lesson screens, in Duolingo order, shown after "Lesson complete".
enum ResultsStage {
  scoreUnlock,
  streakExtended,
  streakGoal,
  widgetUnlock,
  friendStreak,
  gems,
  quest,
  friendsQuest,
  league,
  createProfile,
}

/// Pure ordering rule so it can be tested without widgets.
///
/// Streak celebrations only appear when the streak grew. Gems appear when
/// the server paid any. Guests have no league or friends yet; they get the
/// create-profile prompt last instead.
List<ResultsStage> resultsChainStages({
  required ResultsRepository repository,
  required bool streakGrew,
  required bool gemsEarned,
  required bool guest,
  int? unlockedScore,
}) => [
  if (unlockedScore != null && unlockedScore > 0) ResultsStage.scoreUnlock,
  if (streakGrew) ...[
    ResultsStage.streakExtended,
    if (repository.streakGoal() != null) ResultsStage.streakGoal,
    if (repository.widgetUnlock() != null) ResultsStage.widgetUnlock,
    if (!guest && repository.friendStreak() != null) ResultsStage.friendStreak,
  ],
  if (gemsEarned) ResultsStage.gems,
  ResultsStage.quest,
  if (!guest) ...[
    if (repository.friendsQuest() != null) ResultsStage.friendsQuest,
    ResultsStage.league,
  ],
  if (guest) ResultsStage.createProfile,
];

class ResultsChainScreen extends ConsumerStatefulWidget {
  const ResultsChainScreen({
    required this.streakGrew,
    required this.gemsEarned,
    required this.guest,
    required this.onFinished,
    required this.onCreateProfile,
    this.unlockedScore,
    super.key,
  });
  final bool streakGrew;
  final bool gemsEarned;
  final bool guest;
  final int? unlockedScore;
  final VoidCallback onFinished;
  final VoidCallback onCreateProfile;

  @override
  ConsumerState<ResultsChainScreen> createState() => _ResultsChainScreenState();
}

class _ResultsChainScreenState extends ConsumerState<ResultsChainScreen> {
  late final int? _unlockedScore = widget.unlockedScore;
  late final List<ResultsStage> _stages = resultsChainStages(
    repository: ref.read(resultsRepositoryProvider),
    streakGrew: widget.streakGrew,
    gemsEarned: widget.gemsEarned,
    guest: widget.guest,
    unlockedScore: _unlockedScore,
  );
  int _index = 0;

  void _next() {
    if (_index >= _stages.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() => _index++);
  }

  Widget _screen(ResultsStage stage) => switch (stage) {
    ResultsStage.scoreUnlock => ScoreUnlockScreen(
      score: _unlockedScore!,
      onContinue: _next,
    ),
    ResultsStage.streakExtended => StreakExtendedScreen(onContinue: _next),
    ResultsStage.streakGoal => StreakGoalScreen(onContinue: _next),
    ResultsStage.widgetUnlock => WidgetUnlockScreen(onContinue: _next),
    ResultsStage.friendStreak => FriendStreakResultScreen(onContinue: _next),
    ResultsStage.gems => GemRewardScreen(onContinue: _next),
    ResultsStage.quest => QuestProgressResultScreen(onContinue: _next),
    ResultsStage.friendsQuest => FriendsQuestResultScreen(onContinue: _next),
    ResultsStage.league => LeagueRankResultScreen(onContinue: _next),
    ResultsStage.createProfile => CreateProfilePromptScreen(
      onCreate: widget.onCreateProfile,
      onLater: widget.onFinished,
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (_stages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
      return const SizedBox.shrink();
    }
    final stage = _stages[_index];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onFinished();
      },
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        child: KeyedSubtree(
          key: ValueKey('results-stage-${stage.name}'),
          child: _screen(stage),
        ),
      ),
    );
  }
}
