import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot_cache.dart';
import '../data/path_repository.dart';
import '../domain/learning_models.dart';
import 'course_navigation_controller.dart';
import 'learning_controller.dart';

/// Learning state as the path screen renders it: the local ledger, with node
/// progress for the shown unit replaced by the server path in API mode.
final pathLearningStateProvider = Provider<LearningState>((ref) {
  final local = ref.watch(learningStateProvider);
  watchSnapshot(ref, 'path');
  final active = ref.watch(courseNavigationProvider.select((s) => s.active));
  final remote = ref.watch(pathRepositoryProvider).unitProgress(active);
  if (remote == null) return local;
  return local.copyWith(
    completedNodes: remote.completedNodes,
    currentNode: remote.currentNode,
    lessonInNode: remote.lessonInNode,
    completedLessons: remote.completedLessons,
  );
});
