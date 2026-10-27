import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../learning/data/learning_repository.dart' show mockPracticeExercises;
import '../../learning/data/lesson_wire_mapper.dart';
import '../../learning/domain/learning_models.dart';

/// One due/mistake review entry from `GET /v1/review`.
class PracticeReviewItem {
  const PracticeReviewItem({
    required this.vocabularyId,
    required this.skillId,
    required this.dueAt,
    required this.stage,
    this.mastery,
  });

  final String vocabularyId;
  final String skillId;
  final String dueAt;
  final int stage;
  final num? mastery;
}

/// Content behind the practice screens.
///
/// Listen/Speak typed practice resolves the learner's current lesson bundle
/// (`GET /v1/lessons/{lessonId}/bundle`) and the review index comes from
/// `GET /v1/review`. Offline and mock mode keep the local fixtures.
abstract interface class PracticeContentRepository {
  bool get isRemote;

  Future<List<Exercise>> practiceExercises(ExerciseKind kind);

  Future<List<PracticeReviewItem>> reviewItems();
}

class MockPracticeContentRepository implements PracticeContentRepository {
  const MockPracticeContentRepository();

  @override
  bool get isRemote => false;

  @override
  Future<List<Exercise>> practiceExercises(ExerciseKind kind) async => [
    for (final exercise in mockPracticeExercises)
      if (exercise.kind == kind) exercise,
  ];

  @override
  Future<List<PracticeReviewItem>> reviewItems() async =>
      const <PracticeReviewItem>[];
}

/// Learning-service bundle for practice and the server review index.
class ApiPracticeContentRepository implements PracticeContentRepository {
  ApiPracticeContentRepository(this.api, this.course);

  final ApiEndpoints api;
  final ActiveCourse course;

  List<Exercise>? _bundle;
  Future<List<Exercise>>? _inflight;

  @override
  bool get isRemote => true;

  @override
  Future<List<Exercise>> practiceExercises(ExerciseKind kind) async {
    final exercises = await (_inflight ??= _loadBundle());
    final matching = [
      for (final exercise in exercises)
        if (exercise.kind == kind) exercise,
    ];
    if (matching.isNotEmpty) return matching;
    // The server bundle has no exercise of this kind: keep the local fixture.
    return [
      for (final exercise in mockPracticeExercises)
        if (exercise.kind == kind) exercise,
    ];
  }

  Future<List<Exercise>> _loadBundle() async {
    final cached = _bundle;
    if (cached != null) return cached;
    try {
      final courseId = await course.id();
      final path = await api.getPath(courseId, limit: 100);
      final nodes = [...path.nodes]..sort((a, b) => a.order.compareTo(b.order));
      final node =
          nodes
              .where((item) => item.state == 'current')
              .firstOrNull ??
          nodes
              .where(
                (item) => item.state == 'available' && item.lessonIds.isNotEmpty,
              )
              .firstOrNull ??
          nodes.where((item) => item.lessonIds.isNotEmpty).firstOrNull;
      if (node == null) return mockPracticeExercises;
      final lessonId = node.lessonIds.firstWhere(
        (id) => !path.enrollment.completedLessonIds.contains(id),
        orElse: () => node.lessonIds.first,
      );
      final bundle = await api.getBundle(lessonId);
      final mapper = LessonWireMapper(
        bundle.exercises,
        assets: bundle.assets,
      );
      return _bundle = mapper.toDomain();
    } on ApiException {
      // Offline or unavailable content: the local practice fixture stays.
      _inflight = null;
      return mockPracticeExercises;
    }
  }

  @override
  Future<List<PracticeReviewItem>> reviewItems() async {
    try {
      final courseId = await course.id();
      final page = await api.getReview(courseId: courseId, limit: 100);
      return List.unmodifiable([
        for (final item in page.items)
          PracticeReviewItem(
            vocabularyId: item.vocabularyId,
            skillId: item.skillId,
            dueAt: item.dueAt,
            stage: item.stage,
            mastery: item.mastery,
          ),
      ]);
    } on ApiException {
      // Offline: never invent a review index.
      return const <PracticeReviewItem>[];
    }
  }
}
