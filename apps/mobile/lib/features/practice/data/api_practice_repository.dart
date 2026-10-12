import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../domain/practice_models.dart';
import 'practice_repository.dart';

/// Words + open mistakes for the active course, cached together.
final class PracticeSnapshot {
  const PracticeSnapshot({required this.words, required this.mistakes});

  factory PracticeSnapshot.fromJson(Map<String, Object?> json) =>
      PracticeSnapshot(
        words: [for (final w in json['words']! as List) wire.Word.fromJson(w)],
        mistakes: [
          for (final m in json['mistakes']! as List) wire.Mistake.fromJson(m),
        ],
      );

  final List<wire.Word> words;
  final List<wire.Mistake> mistakes;

  Map<String, Object?> toJson() => {
    'words': [for (final w in words) w.toJson()],
    'mistakes': [for (final m in mistakes) m.toJson()],
  };
}

/// [PracticeRepository] backed by `GET /v1/words` and `GET /v1/mistakes`
/// (P7-PRACTICE-001 read, P6-REVIEW-002). Newest-reviewed words first, which
/// is the screen's default "recent" order.
class ApiPracticeRepository implements PracticeRepository, PracticeMistakes {
  ApiPracticeRepository(this.api, this.course, {SnapshotHost? host})
    : cache = SnapshotCache<PracticeSnapshot>(
        key: 'practice',
        host: host ?? SnapshotHost.detached(),
        decode: PracticeSnapshot.fromJson,
        encode: (s) => s.toJson(),
      );

  final ApiEndpoints api;
  final ActiveCourse course;
  final SnapshotCache<PracticeSnapshot> cache;

  static const _maxWords = 500;

  Future<PracticeSnapshot> _fetch() async {
    final courseId = await course.id();
    final words = <wire.Word>[];
    String? cursor;
    do {
      final page = await api.listWords(
        courseId: courseId,
        cursor: cursor,
        limit: 100,
      );
      words.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null && words.length < _maxWords);
    final mistakes = await api.listMistakes(courseId: courseId, limit: 100);
    return PracticeSnapshot(words: words, mistakes: mistakes.items);
  }

  Future<void> refresh() => cache.refresh(_fetch);

  @override
  List<PracticeWord> loadWords() {
    cache.ensureLoaded(_fetch);
    final words = [...?cache.value?.words]
      ..sort(
        (a, b) => (b.lastReviewedAt ?? b.firstSeenAt).compareTo(
          a.lastReviewedAt ?? a.firstSeenAt,
        ),
      );
    return [
      for (final w in words)
        PracticeWord(
          id: w.vocabularyId,
          term: w.term,
          meaning: w.translation ?? '',
        ),
    ];
  }

  @override
  List<PracticeMistake> loadMistakes() {
    cache.ensureLoaded(_fetch);
    return [
      for (final m in cache.value?.mistakes ?? const <wire.Mistake>[])
        if (m.resolvedAt == null)
          PracticeMistake(
            exerciseId: m.exerciseId,
            skillId: m.skillId,
            count: m.mistakeCount,
          ),
    ];
  }
}
