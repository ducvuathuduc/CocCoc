import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../data/course_management_repository.dart';

enum CourseRemovalPhase { idle, confirming, removing }

class ManagedCourse {
  const ManagedCourse({
    required this.id,
    required this.name,
    this.active = false,
    this.wireCourseId,
    this.revision = 0,
  });

  /// Screen/flag vocabulary (`english`, `chinese`, ...).
  final String id;
  final String name;
  final bool active;

  /// OpenAPI course id (`vi_en`, ...) when the row came from the server.
  final String? wireCourseId;

  /// Enrollment revision the server commands carry.
  final int revision;

  String get apiId => wireCourseId ?? id;
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

/// Course rows and enrollment commands for the signed-in account.
///
/// Mock mode and guest sessions keep the local fixtures; API mode reads the
/// enrolled catalog from the Learning service.
final courseManagementRepositoryProvider =
    Provider<CourseManagementRepository>((ref) {
      final config = ref.watch(appConfigProvider);
      final user = ref.watch(authControllerProvider.select((s) => s.user));
      if (!config.isApi || user == null || user.guest) {
        return const MockCourseManagementRepository();
      }
      return ApiCourseManagementRepository(
        ref.watch(apiEndpointsProvider),
        ref.watch(activeCourseProvider),
      );
    });

final courseManagementProvider =
    NotifierProvider<CourseManagementController, CourseManagementState>(
      CourseManagementController.new,
    );

class CourseManagementController extends Notifier<CourseManagementState> {
  CourseManagementRepository? _repository;
  int _loadRevision = 0;

  @override
  CourseManagementState build() {
    final repository = ref.watch(courseManagementRepositoryProvider);
    _repository = repository;
    _loadRevision += 1;
    if (!repository.isRemote) return const CourseManagementState();
    unawaited(_load());
    return const CourseManagementState(courses: <ManagedCourse>[]);
  }

  bool get isAlive => ref.mounted;

  bool get _remote => _repository?.isRemote ?? false;

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null || !repository.isRemote) return;
    final revision = ++_loadRevision;
    try {
      final records = await repository.loadCourses();
      if (!ref.mounted || revision != _loadRevision) return;
      state = state.copyWith(
        courses: List<ManagedCourse>.unmodifiable([
          for (final record in records)
            ManagedCourse(
              id: record.id,
              name: record.name,
              active: record.active,
              wireCourseId: record.courseId,
              revision: record.revision,
            ),
        ]),
      );
    } on ApiException {
      // Keep the current rows; the next focus/load retries the projection.
    }
  }

  /// Reloads the course rows (API mode only).
  Future<void> refresh() => _load();

  bool requestRemoval(String courseId) {
    if (state.phase != CourseRemovalPhase.idle) return false;
    final course = _course(courseId);
    if (course == null) return false;
    if (course.active) {
      state = state.copyWith(
        protectionMessage: _remote
            ? '${course.name} is your active course and cannot be removed.'
            : 'English is your active course and cannot be removed.',
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
    final repository = _repository;
    if (repository == null || !repository.isRemote) {
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
    try {
      await repository.removeCourse(_record(course));
    } catch (error) {
      if (!ref.mounted ||
          state.phase != CourseRemovalPhase.removing ||
          state.pendingCourseId != course.id) {
        return false;
      }
      state = state.copyWith(
        phase: CourseRemovalPhase.idle,
        clearPendingCourse: true,
        protectionMessage: _message(error),
      );
      return false;
    }
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

  /// Activates [courseId] on the server (mock mode marks the row locally).
  Future<bool> switchCourse(String courseId) async {
    if (!ref.mounted || state.phase != CourseRemovalPhase.idle) return false;
    final course = _course(courseId);
    if (course == null) return false;
    final repository = _repository;
    if (repository == null || !repository.isRemote) {
      state = state.copyWith(
        courses: List<ManagedCourse>.unmodifiable([
          for (final item in state.courses)
            ManagedCourse(
              id: item.id,
              name: item.name,
              active: item.id == courseId,
              wireCourseId: item.wireCourseId,
              revision: item.revision,
            ),
        ]),
        clearProtectionMessage: true,
      );
      return true;
    }
    try {
      await repository.switchCourse(_record(course));
    } catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(protectionMessage: _message(error));
      return false;
    }
    if (!ref.mounted) return false;
    await _load();
    return true;
  }

  /// Resets [courseId]'s frontier on the server (API mode only).
  Future<bool> resetCourse(String courseId) async {
    if (!ref.mounted || state.phase != CourseRemovalPhase.idle) return false;
    final course = _course(courseId);
    final repository = _repository;
    if (course == null || repository == null || !repository.isRemote) {
      return false;
    }
    try {
      await repository.resetCourse(_record(course));
    } catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(protectionMessage: _message(error));
      return false;
    }
    if (!ref.mounted) return false;
    await _load();
    return true;
  }

  static ManagedCourseRecord _record(ManagedCourse course) =>
      ManagedCourseRecord(
        id: course.id,
        name: course.name,
        courseId: course.apiId,
        revision: course.revision,
        active: course.active,
      );

  static String _message(Object error) => error is ApiException
      ? error.userMessage
      : 'We couldn’t complete that request. Please try again.';

  ManagedCourse? _course(String id) {
    for (final course in state.courses) {
      if (course.id == id) return course;
    }
    return null;
  }
}
