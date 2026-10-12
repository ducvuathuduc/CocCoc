import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot_cache.dart';
import '../data/api_roleplay_repository.dart';
import '../data/roleplay_repository.dart';
import '../domain/roleplay_models.dart';

/// Library + per-scenario progress. Sessions report results through
/// [RoleplayLibraryController.record].
final roleplayLibraryControllerProvider =
    NotifierProvider<RoleplayLibraryController, RoleplayLibraryState>(
      RoleplayLibraryController.new,
    );

class RoleplayLibraryController extends Notifier<RoleplayLibraryState> {
  RoleplayRepository get _repo => ref.read(roleplayRepositoryProvider);

  @override
  RoleplayLibraryState build() {
    final repo = ref.watch(roleplayRepositoryProvider);
    // Server history landing later merges into progress without dropping the
    // session's lastResult/featured pick.
    ref.listen(
      snapshotRevisionProvider.select((m) => m['roleplay'] ?? 0),
      (_, _) => state = state.copyWith(
        progress: {...state.progress, ...repo.initialProgress()},
      ),
    );
    return RoleplayLibraryState(
      progress: Map.unmodifiable(repo.initialProgress()),
      featuredId: repo.defaultFeaturedId(),
    );
  }

  List<RoleplayTopic> get topics => _repo.topics();
  List<RoleplayScenario> scenariosFor(String topicId) =>
      _repo.scenariosFor(topicId);
  RoleplayScenario? scenario(String id) => _repo.scenario(id);
  RoleplayScenario get featured =>
      _repo.scenario(state.featuredId) ??
      _repo.scenario(_repo.defaultFeaturedId())!;

  /// Completed scenarios out of the topic total.
  (int, int) topicProgress(String topicId) {
    final list = _repo.scenariosFor(topicId);
    return (
      list.where((s) => state.progressOf(s.id).completed).length,
      list.length,
    );
  }

  void feature(String scenarioId) {
    if (_repo.scenario(scenarioId) == null) return;
    state = state.copyWith(featuredId: scenarioId);
  }

  RoleplayResult? record(String scenarioId, int wordsUsed) {
    if (_repo.scenario(scenarioId) == null) return null;
    final before = state.progressOf(scenarioId);
    final repo = _repo;
    if (repo case final RoleplayCommands commands) {
      unawaited(
        commands.recordConversation(scenarioId).catchError((Object _) {}),
      );
    }
    final stars = roleplayStarsFor(wordsUsed);
    final result = RoleplayResult(
      scenarioId: scenarioId,
      wordsUsed: wordsUsed,
      stars: stars,
      xp: roleplayXpFor(stars),
      newRecord: wordsUsed > before.bestWords,
    );
    state = state.copyWith(
      featuredId: scenarioId,
      lastResult: result,
      progress: {
        ...state.progress,
        scenarioId: RoleplayProgress(
          stars: stars > before.stars ? stars : before.stars,
          bestWords: wordsUsed > before.bestWords
              ? wordsUsed
              : before.bestWords,
          completions: before.completions + 1,
        ),
      },
    );
    return result;
  }
}
