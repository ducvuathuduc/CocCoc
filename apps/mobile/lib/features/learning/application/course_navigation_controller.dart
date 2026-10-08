import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/course_catalog.dart';
import '../domain/unit_skip.dart';
import '../domain/course_review.dart';
import '../domain/learning_models.dart';
import 'learning_controller.dart';

class CourseNavigationState {
  CourseNavigationState({
    this.active = const CourseTarget(1, 1),
    Set<CourseTarget>? unlocked,
  }) : unlocked = Set.unmodifiable(unlocked ?? {const CourseTarget(1, 1)});
  final CourseTarget active;
  final Set<CourseTarget> unlocked;
  bool sectionUnlocked(int section) =>
      unlocked.contains(CourseTarget(section, 1));
}

final courseNavigationProvider =
    NotifierProvider<CourseNavigationController, CourseNavigationState>(
      CourseNavigationController.new,
    );

// A local UI projection. Real enrollment, XP and course settlement belong to
// the learning service; browsing and a fixture check never write those counters.
class CourseNavigationController extends Notifier<CourseNavigationState> {
  final _consumedChecks = Set<UnitSkipState>.identity();
  @override
  CourseNavigationState build() => CourseNavigationState();

  bool select(CourseTarget target) {
    if (!target.valid || !state.unlocked.contains(target)) return false;
    state = CourseNavigationState(active: target, unlocked: state.unlocked);
    return true;
  }

  bool acceptCompletedCheck(CourseTarget target, UnitSkipState result) {
    final expected = target.unit == 1 ? target.section : target.unit;
    if (!target.valid ||
        expected < 2 ||
        expected > 8 ||
        result.unit != expected ||
        result.stage != UnitSkipStage.passed ||
        !result.passAcknowledged ||
        result.section != target.section ||
        result.sectionCheck != (target.unit == 1) ||
        _consumedChecks.contains(result) ||
        (target.unit > 1 && !state.sectionUnlocked(target.section))) {
      return false;
    }
    _consumedChecks.add(result);
    state = CourseNavigationState(
      active: target,
      unlocked: {...state.unlocked, target},
    );
    return true;
  }

  Future<void> startLesson(int node) async {
    if (node < 0 || node > 7) return;
    final target = state.active;
    final vm = ref.read(lessonControllerProvider.notifier);
    final lesson = ref.read(lessonControllerProvider);
    final id = courseNodeId(target, node);
    if (lesson.stage == LessonStage.paused && lesson.nodeId == id) {
      vm.resume();
      return;
    }
    final isReview = target != const CourseTarget(1, 1);
    await vm.start(
      nodeId: id,
      guest: isReview,
      exercises: isReview ? courseReviewExercises(target) : null,
    );
  }
}
