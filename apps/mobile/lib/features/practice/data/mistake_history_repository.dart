import 'dart:convert';

import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../../learning/domain/learning_models.dart';

abstract interface class HistoryStorageStatus {
  String? get warning;
}

class SavedMistake {
  const SavedMistake({
    required this.id,
    required this.skill,
    required this.count,
    required this.at,
    this.exercise,
  });
  final String id, skill;
  final int count;
  final DateTime at;
  final Exercise? exercise;
  String get label => exercise?.prompt ?? 'Question to review';
  Map<String, Object?> toJson() => {
    'id': id,
    'skill': skill,
    'count': count,
    'at': at.toIso8601String(),
    'exercise': exercise == null ? null : encodeMistakeExercise(exercise!),
  };
  factory SavedMistake.fromJson(Map<String, dynamic> json) => SavedMistake(
    id: json['id'] as String,
    skill: json['skill'] as String,
    count: json['count'] as int,
    at: DateTime.parse(json['at'] as String),
    exercise: json['exercise'] == null
        ? null
        : decodeMistakeExercise(
            Map<String, dynamic>.from(json['exercise'] as Map),
          ),
  );
}

class MistakeHistory {
  const MistakeHistory(this.items, {this.offline = false, this.warning});
  final List<SavedMistake> items;
  final bool offline;
  final String? warning;
}

class MistakeEvidence {
  const MistakeEvidence(
    this.exercise, {
    required this.correct,
    required this.assisted,
  });
  final Exercise exercise;
  final bool correct, assisted;
}

/// A strict store is supplied by the application: failed local writes must
/// remain visible, never masquerade as a saved history.
class MistakeHistoryRepository {
  MistakeHistoryRepository({
    required this.store,
    this.api,
    this.course,
    bool Function()? active,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now,
       active = active ?? (() => true);
  final SnapshotStore store;
  final ApiEndpoints? api;
  final Future<String> Function()? course;
  final DateTime Function() clock;
  final bool Function() active;
  Future<void> _tail = Future.value();

  Future<Map<String, dynamic>> _read() async {
    final raw = await store.read('mistakes');
    if (raw == null) {
      return {
        'version': 1,
        'items': <dynamic>[],
        'seen': <dynamic>[],
        'exists': false,
      };
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Invalid mistake history');
    }
    return json;
  }

  List<SavedMistake> _items(Map<String, dynamic> json) =>
      (json['items'] as List)
          .map(
            (v) => SavedMistake.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList();

  Future<MistakeHistory> load() async {
    Map<String, dynamic>? cached;
    try {
      cached = await _read();
    } catch (_) {
      if (api == null) rethrow;
    }
    if (api == null) {
      return MistakeHistory(
        _items(cached!),
        warning: store is HistoryStorageStatus
            ? (store as HistoryStorageStatus).warning
            : null,
      );
    }
    String? requestedCourse;
    try {
      final courseId = await course!();
      if (!active()) throw StateError('Account changed');
      requestedCourse = courseId;
      final page = await api!.listMistakes(
        courseId: courseId,
        limit: 100,
        includeResolved: false,
      );
      final items = [
        for (final item in page.items)
          if (item.resolvedAt == null)
            SavedMistake(
              id: item.exerciseId,
              skill: item.skillId,
              count: item.mistakeCount,
              at: DateTime.parse(item.lastMistakeAt),
            ),
      ];
      if (!active()) throw StateError('Account changed');
      try {
        await store.write(
          'mistakes',
          jsonEncode({
            'version': 1,
            'courseId': courseId,
            'items': items.map((e) => e.toJson()).toList(),
            'seen': [],
          }),
        );
      } catch (_) {
        return MistakeHistory(
          items,
          warning:
              'Loaded from server, but the offline copy could not be saved.',
        );
      }
      return MistakeHistory(
        items,
        warning: store is HistoryStorageStatus
            ? (store as HistoryStorageStatus).warning
            : null,
      );
    } on ApiException catch (error) {
      if (error.isOffline &&
          cached != null &&
          cached['exists'] != false &&
          (requestedCourse == null || cached['courseId'] == requestedCourse)) {
        return MistakeHistory(_items(cached), offline: true);
      }
      rethrow;
    }
  }

  /// Demo-only first-attempt evidence. Real accounts are written by Learning
  /// in the completion transaction; never mutate a cached API result locally.
  Future<void> record(
    String eventId,
    List<MistakeEvidence> evidence, {
    required bool review,
  }) {
    if (api != null) return Future.value();
    final work = _tail.then((_) async {
      final json = await _read();
      final seen = (json['seen'] as List).cast<String>();
      if (seen.contains(eventId)) return;
      final items = {for (final item in _items(json)) item.id: item};
      for (final value in evidence) {
        final previous = items[value.exercise.id];
        if (!value.correct) {
          items[value.exercise.id] = SavedMistake(
            id: value.exercise.id,
            skill: 'Practice',
            count: (previous?.count ?? 0) + 1,
            at: clock().toUtc(),
            exercise: value.exercise,
          );
        } else if (review && !value.assisted) {
          items.remove(value.exercise.id);
        }
      }
      final ordered = items.values.toList()
        ..sort((a, b) {
          final byDate = b.at.compareTo(a.at);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      await store.write(
        'mistakes',
        jsonEncode({
          'version': 1,
          'items': ordered.take(100).map((e) => e.toJson()).toList(),
          'seen': [
            ...seen,
            eventId,
          ].reversed.take(1000).toList().reversed.toList(),
        }),
      );
    });
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }
}

Map<String, Object?> encodeMistakeExercise(Exercise e) {
  Map<String, Object?>? audio(LessonAudio? a) =>
      a == null ? null : {'id': a.fileId, 'hash': a.sha256};
  Map<String, Object?> choice(ExerciseChoice c) => {
    'id': c.id,
    'text': c.text,
    'art': c.art,
    'image': c.image == null
        ? null
        : {'id': c.image!.fileId, 'hash': c.image!.sha256},
  };
  return {
    'id': e.id,
    'kind': e.kind.name,
    'title': e.title,
    'prompt': e.prompt,
    'choices': e.choices.map(choice).toList(),
    'tokens': e.tokens.map(choice).toList(),
    'correctIds': e.correctIds,
    'correctText': e.correctText,
    'pairs': e.pairs,
    'hint': e.hint,
    'meaning': e.meaning,
    'audioPairs': e.audioPairs,
    'pairLabels': e.pairLabels,
    'audio': audio(e.audio),
    'slowAudio': audio(e.slowAudio),
    'wordAudio': e.wordAudio.map((key, value) => MapEntry(key, audio(value))),
  };
}

Exercise decodeMistakeExercise(Map<String, dynamic> j) {
  LessonAudio? audio(dynamic a) =>
      a == null ? null : LessonAudio(a['id'] as String, a['hash'] as String?);
  ExerciseChoice choice(dynamic c) => ExerciseChoice(
    id: c['id'] as String,
    text: c['text'] as String,
    art: c['art'] as String?,
    image: c['image'] == null
        ? null
        : LessonImage(
            c['image']['id'] as String,
            c['image']['hash'] as String?,
          ),
  );
  return Exercise(
    id: j['id'] as String,
    kind: ExerciseKind.values.byName(j['kind'] as String),
    title: j['title'] as String,
    prompt: j['prompt'] as String,
    choices: (j['choices'] as List).map(choice).toList(),
    tokens: (j['tokens'] as List).map(choice).toList(),
    correctIds: (j['correctIds'] as List).cast<String>(),
    correctText: j['correctText'] as String,
    pairs: Map<String, String>.from(j['pairs'] as Map),
    hint: j['hint'] as String?,
    meaning: j['meaning'] as String?,
    audioPairs: j['audioPairs'] as bool,
    pairLabels: Map<String, String>.from(j['pairLabels'] as Map),
    audio: audio(j['audio']),
    slowAudio: audio(j['slowAudio']),
    wordAudio: (j['wordAudio'] as Map).map(
      (k, v) => MapEntry(k as String, audio(v)!),
    ),
  );
}
