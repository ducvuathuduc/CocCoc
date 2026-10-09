import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CourseRemovalPhase { idle, confirming, removing }

class ManagedCourse {
  const ManagedCourse({
    required this.id,
    required this.name,
    this.active = false,
  });

  final String id;
  final String name;
  final bool active;
}

class CourseManagementState {
  const CourseManagementState({
    this.courses = _seedCourses,
    this.phase = CourseRemovalPhase.idle,
    this.pendingCourseId,
    this.protectionMessage,
  });

  static const _seedCourses = <ManagedCourse>[
    ManagedCourse(id: 'english', name: 'English', active: true),
    ManagedCourse(id: 'chinese', name: 'Chinese'),
    ManagedCourse(id: 'indonesian', name: 'Indonesian'),
    ManagedCourse(id: 'italian', name: 'Italian'),
  ];

  final List<ManagedCourse> courses;
  final CourseRemovalPhase phase;
  final String? pendingCourseId;
  final String? protectionMessage;

  ManagedCourse? get pendingCourse {
    for (final course in courses) {
      if (course.id == pendingCourseId) return course;
    }
    return null;
  }

  CourseManagementState copyWith({
    List<ManagedCourse>? courses,
    CourseRemovalPhase? phase,
    String? pendingCourseId,
    bool clearPendingCourse = false,
    String? protectionMessage,
    bool clearProtectionMessage = false,
  }) => CourseManagementState(
    courses: courses ?? this.courses,
    phase: phase ?? this.phase,
    pendingCourseId: clearPendingCourse
        ? null
        : pendingCourseId ?? this.pendingCourseId,
    protectionMessage: clearProtectionMessage
        ? null
        : protectionMessage ?? this.protectionMessage,
  );
}

final courseManagementProvider =
    NotifierProvider<CourseManagementController, CourseManagementState>(
      CourseManagementController.new,
    );

class CourseManagementController extends Notifier<CourseManagementState> {
  @override
  CourseManagementState build() => const CourseManagementState();

  bool get isAlive => ref.mounted;

  bool requestRemoval(String courseId) {
    if (state.phase != CourseRemovalPhase.idle) return false;
    final course = _course(courseId);
    if (course == null) return false;
    if (course.active) {
      state = state.copyWith(
        protectionMessage:
            'English is your active course and cannot be removed.',
      );
      return false;
    }
    state = state.copyWith(
      phase: CourseRemovalPhase.confirming,
      pendingCourseId: courseId,
      clearProtectionMessage: true,
    );
    return true;
  }

  void cancelRemoval() {
    if (!ref.mounted || state.phase != CourseRemovalPhase.confirming) return;
    state = state.copyWith(
      phase: CourseRemovalPhase.idle,
      clearPendingCourse: true,
    );
  }

  Future<bool> confirmRemoval() async {
    if (!ref.mounted) return false;
    final course = state.pendingCourse;
    if (state.phase != CourseRemovalPhase.confirming ||
        course == null ||
        course.active) {
      return false;
    }
    state = state.copyWith(phase: CourseRemovalPhase.removing);
    // A bounded local wait exposes the archived disabled-row state. The exact
    // source request duration is not established by screenshots.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!ref.mounted ||
        state.phase != CourseRemovalPhase.removing ||
        state.pendingCourseId != course.id) {
      return false;
    }
    state = state.copyWith(
      courses: List<ManagedCourse>.unmodifiable(
        state.courses.where((item) => item.id != course.id),
      ),
      phase: CourseRemovalPhase.idle,
      clearPendingCourse: true,
    );
    return true;
  }

  ManagedCourse? _course(String id) {
    for (final course in state.courses) {
      if (course.id == id) return course;
    }
    return null;
  }
}
