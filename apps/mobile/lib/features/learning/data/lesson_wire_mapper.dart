import '../../../core/api/api_contracts.dart' as wire;
import '../domain/learning_models.dart';
import 'lesson_image_catalog.g.dart';

/// Maps OpenAPI lesson exercises to the frozen UI's [Exercise] model and UI
/// answers back to wire `Answer`s. Also grades offline from the bundle's
/// grading rule (provisional; the server regrades on sync).
final class LessonWireMapper {
  LessonWireMapper(this.exercises, {List<wire.Asset> assets = const []})
    : _assetHashes = {for (final a in assets) a.fileId: a.sha256} {
    for (final exercise in exercises) {
      _register(_effective(exercise));
    }
  }

  /// Wire exercises in bundle order.
  final List<wire.Exercise> exercises;

  final Map<String, Map<String, Object?>> _byId = {};

  /// Bundle `assets`: fileId -> sha256.
  final Map<String, String> _assetHashes;

  /// Ids of exercises replaced by their non-speech alternative.
  final Set<String> substitutedIds = {};

  static const _titles = <String, String>{
    'textTranslation': 'Translate this sentence',
    'choice': 'Select the correct translation',
    'wordBank': 'Build the translation',
    'sentenceOrder': 'Put the words in order',
    'fillBlank': 'Complete the sentence',
    'matchPairs': 'Match the pairs',
    'imageChoice': 'Select the correct image',
    'listenChoice': 'Listen and choose',
    'dictation': 'Write what you hear',
    'speakRepeat': 'Speak this sentence',
    'dialogueTurn': 'Respond to the speaker',
    'storyQuestion': 'Answer the story question',
  };

  /// Speech capture is not wired to the AI assessment service yet, so speech
  /// exercises use their authored non-speech alternative when present.
  Map<String, Object?> _effective(wire.Exercise exercise) {
    final json = exercise.toJson();
    final type = json['type'];
    if ((type == 'speakRepeat' || type == 'dialogueTurn') &&
        json['nonSpeechAlternative'] is Map) {
      final alt = Map<String, Object?>.from(
        json['nonSpeechAlternative']! as Map,
      );
      substitutedIds.add(alt['id']! as String);
      return alt;
    }
    return json;
  }

  void _register(Map<String, Object?> json) {
    final id = json['id']! as String;
    _byId[id] = json;
  }

  /// `imageAssetId` (`i.<unitId>.<wordId>`, EXERCISE_FORMATS §3.7) to the
  /// bundled character art key, or `null` when the app has no art for it.
  static String? artFor(String? imageAssetId) {
    if (imageAssetId == null) return null;
    final word = imageAssetId.split('.').last.toLowerCase();
    return bundledArt.contains(word) ? word : null;
  }

  /// Picture keys `LearningArt.character` can render.
  static const bundledArt = {'boy', 'girl', 'cat', 'woman', 'man', 'bear'};

  /// The word illustration for [imageAssetId]: listed in the bundle `assets`
  /// (hash-pinned; shipped with the app or downloaded by hash) or, without a
  /// bundle entry, shipped with the app. `null` when neither.
  LessonImage? imageFor(String? imageAssetId) {
    if (imageAssetId == null) return null;
    final hash = _assetHashes[imageAssetId];
    if (hash != null) return LessonImage(imageAssetId, hash);
    return bundledLessonImages.containsKey(imageAssetId)
        ? LessonImage(imageAssetId)
        : null;
  }

  /// UI exercises in bundle order (speech replaced by alternatives).
  List<Exercise> toDomain() => [
    for (final exercise in exercises) _toDomain(_effective(exercise)),
  ];

  Map<String, Object?>? wireJson(String exerciseId) => _byId[exerciseId];

  Exercise _toDomain(Map<String, Object?> json) {
    final type = json['type']! as String;
    final content = _map(json['content']);
    final rule = _map(json['gradingRule']);
    final prompt = (_map(json['prompt'])['text'] as String?) ?? '';
    final hint = _nonEmpty(json['hint']);
    final explanation = _nonEmpty(json['explanation']);
    final accepted = _list(rule['acceptedText']).cast<String>();
    final title = _titles[type] ?? 'Answer the question';

    List<ExerciseChoice> choices(Object? raw, {bool art = false}) => [
      for (final item in _list(raw))
        () {
          final assetId = art ? _map(item)['imageAssetId'] as String? : null;
          final image = imageFor(assetId);
          return ExerciseChoice(
            id: _map(item)['id']! as String,
            text: _map(item)['text']! as String,
            art: image == null ? artFor(assetId) : null,
            image: image,
          );
        }(),
    ];

    switch (type) {
      case 'choice' || 'imageChoice' || 'listenChoice':
        final correct = rule['correctChoiceId'] as String?;
        final options = choices(content['choices'], art: type != 'choice');
        // A picture item renders as a text choice unless every option has
        // an illustration or bundled art (the picture tile has no text-only
        // state).
        final pictures =
            type == 'imageChoice' &&
            options.every((o) => o.image != null || o.art != null);
        return Exercise(
          id: json['id']! as String,
          kind: switch (type) {
            'imageChoice' when pictures => ExerciseKind.imageChoice,
            'listenChoice' => ExerciseKind.listenChoice,
            _ => ExerciseKind.choice,
          },
          title: title,
          prompt: prompt,
          choices: options,
          correctIds: [?correct],
          correctText: _choiceText(content['choices'], correct),
          hint: hint,
          meaning: explanation,
        );
      case 'storyQuestion':
        final correct = rule['correctChoiceId'] as String?;
        final passage = (content['passage'] as String?) ?? '';
        final question = (content['question'] as String?) ?? prompt;
        return Exercise(
          id: json['id']! as String,
          kind: ExerciseKind.choice,
          title: title,
          prompt: passage.isEmpty ? question : '$passage\n\n$question',
          choices: choices(content['choices']),
          correctIds: [?correct],
          correctText: _choiceText(content['choices'], correct),
          hint: hint,
          meaning: explanation,
        );
      case 'wordBank' || 'sentenceOrder':
        final tokens = choices(content['tokens']);
        final correct = _list(rule['correctTokenIds']).cast<String>();
        final byId = {for (final t in tokens) t.id: t.text};
        return Exercise(
          id: json['id']! as String,
          kind: type == 'wordBank'
              ? ExerciseKind.wordBank
              : ExerciseKind.sentenceOrder,
          title: title,
          prompt: prompt,
          tokens: tokens,
          correctIds: correct,
          correctText: correct.map((id) => byId[id] ?? '').join(' '),
          hint: hint,
          meaning: explanation,
        );
      case 'matchPairs':
        // Keyed by wire ids (texts may repeat across sides); labels carry
        // the text the tiles show.
        final pairs = <String, String>{};
        final labels = <String, String>{};
        for (final pair in _list(content['pairs'])) {
          final p = _map(pair);
          final left = _map(p['left']), right = _map(p['right']);
          final leftId = left['id']! as String,
              rightId = right['id']! as String;
          pairs[leftId] = rightId;
          labels[leftId] = left['text']! as String;
          labels[rightId] = right['text']! as String;
        }
        return Exercise(
          id: json['id']! as String,
          kind: ExerciseKind.matchPairs,
          title: title,
          prompt: prompt,
          pairs: pairs,
          pairLabels: labels,
          hint: hint,
          meaning: explanation,
        );
      default:
        final speechText = content['referenceText'] as String?;
        return Exercise(
          id: json['id']! as String,
          kind: switch (type) {
            'fillBlank' => ExerciseKind.fillBlank,
            'dictation' => ExerciseKind.dictation,
            'speakRepeat' => ExerciseKind.speakRepeat,
            'dialogueTurn' => ExerciseKind.dialogueTurn,
            _ => ExerciseKind.textTranslation,
          },
          title: title,
          prompt: prompt,
          correctText: accepted.isNotEmpty ? accepted.first : speechText ?? '',
          hint: hint,
          meaning: explanation,
        );
    }
  }

  /// Converts a UI answer to the wire `Answer` union for [exerciseId].
  wire.Answer toWireAnswer(String exerciseId, LessonAnswer answer) {
    final json = _byId[exerciseId];
    if (json == null) {
      throw ArgumentError.value(exerciseId, 'exerciseId', 'Not in bundle');
    }
    switch (json['type']) {
      case 'choice' || 'imageChoice' || 'listenChoice' || 'storyQuestion':
        return wire.ChoiceAnswer(choiceId: answer.selectedId ?? '');
      case 'wordBank' || 'sentenceOrder':
        return wire.TokenAnswer(tokenIds: List.unmodifiable(answer.tokenIds));
      case 'matchPairs':
        return wire.PairAnswer(
          matches: [
            for (final entry in answer.matchedPairs.entries)
              wire.PairAnswerMatchesItem(
                leftId: entry.key,
                rightId: entry.value,
              ),
          ],
        );
      default:
        return wire.TextAnswer(text: answer.text);
    }
  }

  /// Provisional local grade from the bundle grading rule (offline mode).
  bool gradeLocally(String exerciseId, Map<String, Object?> answer) {
    final json = _byId[exerciseId];
    if (json == null) return false;
    final rule = _map(json['gradingRule']);
    switch (answer['kind']) {
      case 'choice':
        return answer['choiceId'] == rule['correctChoiceId'];
      case 'tokens':
        final expected = _list(rule['correctTokenIds']);
        final actual = _list(answer['tokenIds']);
        if (expected.length != actual.length) return false;
        for (var i = 0; i < expected.length; i++) {
          if (expected[i] != actual[i]) return false;
        }
        return true;
      case 'pairs':
        final pairs = _list(_map(json['content'])['pairs']).map(_map);
        final valid = {
          for (final p in pairs)
            '${_map(p['left'])['id']}|${_map(p['right'])['id']}',
        };
        final matches = _list(answer['matches']).map(_map).toList();
        return matches.length == valid.length &&
            matches.every(
              (m) => valid.contains('${m['leftId']}|${m['rightId']}'),
            );
      case 'text':
        final text = answer['text'] as String? ?? '';
        final accepted = _list(rule['acceptedText']).cast<String>();
        final normalized = normalizeText(text, rule);
        return accepted.any((a) => normalizeText(a, rule) == normalized);
      default:
        return false;
    }
  }

  /// Normalization honoring `caseSensitive`, `ignorePunctuation` and
  /// `ignoreDiacritics` (NFC-insensitive for Vietnamese diacritics).
  static String normalizeText(String value, Map<String, Object?> rule) {
    var text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (rule['caseSensitive'] != true) text = text.toLowerCase();
    if (rule['ignorePunctuation'] == true) {
      text = text
          .replaceAll(RegExp(r'''[.,!?;:"“”‘’()\[\]{}…-]'''), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    text = text.replaceAll('’', "'");
    if (rule['ignoreDiacritics'] == true) text = _stripDiacritics(text);
    return text;
  }

  static String _stripDiacritics(String input) {
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer.toString();
  }

  static String _choiceText(Object? raw, String? id) {
    for (final item in _list(raw)) {
      if (_map(item)['id'] == id) return _map(item)['text']! as String;
    }
    return '';
  }

  static String? _nonEmpty(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static Map<String, Object?> _map(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : const {};

  static List<Object?> _list(Object? value) =>
      value is List ? value.cast<Object?>() : const [];
}
