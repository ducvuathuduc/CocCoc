// GENERATED CODE - DO NOT EDIT BY HAND.
// Source: docs/api/openapi.yaml (sha256 72d4d87713a6d2082ef87417541c8849da5bf3a8318917d68ad11080629e8b19).
// Generator: tools/blueprint/generate-dart-contracts.mjs (models).

// ignore_for_file: prefer_const_constructors

import '../contract_validator.dart';

/// Wire DTO for `#/components/schemas/Error`.
final class Error {
  const Error({
    required this.error,
  });

  /// Validates [json] against the `Error` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Error.fromJson(Object? json) {
    ContractValidator.instance.check('Error', json);
    return Error._decode(json);
  }

  static Error _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Error(
      error: ErrorError._decode(map['error']),
    );
  }

  final ErrorError error;

  Map<String, Object?> toJson() => <String, Object?>{
        'error': error.toJson(),
      };
}

/// Inline wire object `ErrorError` (nested in a component schema).
final class ErrorError {
  const ErrorError({
    required this.code,
    required this.message,
    required this.requestId,
    required this.details,
    required this.retryable,
  });

  static ErrorError _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ErrorError(
      code: map['code'] as String,
      message: map['message'] as String,
      requestId: map['requestId'] as String,
      details: Map<String, Object?>.unmodifiable(map['details'] as Map<Object?, Object?>),
      retryable: map['retryable'] as bool,
    );
  }

  final String code;
  final String message;
  final String requestId;
  final Map<String, Object?> details;
  final bool retryable;

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code,
        'message': message,
        'requestId': requestId,
        'details': Map<String, Object?>.of(details),
        'retryable': retryable,
      };
}

/// Wire DTO for `#/components/schemas/Health`.
final class Health {
  const Health({
    required this.service,
    required this.buildId,
    required this.status,
  });

  /// Validates [json] against the `Health` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Health.fromJson(Object? json) {
    ContractValidator.instance.check('Health', json);
    return Health._decode(json);
  }

  static Health _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Health(
      service: map['service'] as String,
      buildId: map['buildId'] as String,
      status: map['status'] as String,
    );
  }

  final String service;
  final String buildId;
  final String status;

  Map<String, Object?> toJson() => <String, Object?>{
        'service': service,
        'buildId': buildId,
        'status': status,
      };
}

/// Wire DTO for `#/components/schemas/Prompt`.
final class Prompt {
  const Prompt({
    required this.text,
    required this.locale,
    this.audioAssetId = const JsonPresence<String>.absent(),
  });

  /// Validates [json] against the `Prompt` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Prompt.fromJson(Object? json) {
    ContractValidator.instance.check('Prompt', json);
    return Prompt._decode(json);
  }

  static Prompt _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Prompt(
      text: map['text'] as String,
      locale: map['locale'] as String,
      audioAssetId: map.containsKey('audioAssetId') ? JsonPresence<String>.value(map['audioAssetId'] == null ? null : map['audioAssetId'] as String) : const JsonPresence<String>.absent(),
    );
  }

  final String text;
  final String locale;
  final JsonPresence<String> audioAssetId;

  Map<String, Object?> toJson() => <String, Object?>{
        'text': text,
        'locale': locale,
        if (audioAssetId.isPresent) 'audioAssetId': audioAssetId.value,
      };
}

/// Wire DTO for `#/components/schemas/Asset`.
final class Asset {
  const Asset({
    required this.fileId,
    required this.sha256,
    required this.mime,
    required this.bytes,
    this.durationMs = const JsonPresence<int>.absent(),
    this.width = const JsonPresence<int>.absent(),
    this.height = const JsonPresence<int>.absent(),
    this.locale = const JsonPresence<String>.absent(),
    this.voice = const JsonPresence<String>.absent(),
    this.speed = const JsonPresence<num>.absent(),
    this.provider = const JsonPresence<String>.absent(),
    this.modelVersion = const JsonPresence<String>.absent(),
    required this.altText,
  });

  /// Validates [json] against the `Asset` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Asset.fromJson(Object? json) {
    ContractValidator.instance.check('Asset', json);
    return Asset._decode(json);
  }

  static Asset _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Asset(
      fileId: map['fileId'] as String,
      sha256: map['sha256'] as String,
      mime: map['mime'] as String,
      bytes: (map['bytes'] as num).toInt(),
      durationMs: map.containsKey('durationMs') ? JsonPresence<int>.value(map['durationMs'] == null ? null : (map['durationMs'] as num).toInt()) : const JsonPresence<int>.absent(),
      width: map.containsKey('width') ? JsonPresence<int>.value(map['width'] == null ? null : (map['width'] as num).toInt()) : const JsonPresence<int>.absent(),
      height: map.containsKey('height') ? JsonPresence<int>.value(map['height'] == null ? null : (map['height'] as num).toInt()) : const JsonPresence<int>.absent(),
      locale: map.containsKey('locale') ? JsonPresence<String>.value(map['locale'] == null ? null : map['locale'] as String) : const JsonPresence<String>.absent(),
      voice: map.containsKey('voice') ? JsonPresence<String>.value(map['voice'] == null ? null : map['voice'] as String) : const JsonPresence<String>.absent(),
      speed: map.containsKey('speed') ? JsonPresence<num>.value(map['speed'] == null ? null : map['speed'] as num) : const JsonPresence<num>.absent(),
      provider: map.containsKey('provider') ? JsonPresence<String>.value(map['provider'] == null ? null : map['provider'] as String) : const JsonPresence<String>.absent(),
      modelVersion: map.containsKey('modelVersion') ? JsonPresence<String>.value(map['modelVersion'] == null ? null : map['modelVersion'] as String) : const JsonPresence<String>.absent(),
      altText: map['altText'] as String,
    );
  }

  final String fileId;
  final String sha256;
  final String mime;
  final int bytes;
  final JsonPresence<int> durationMs;
  final JsonPresence<int> width;
  final JsonPresence<int> height;
  final JsonPresence<String> locale;
  final JsonPresence<String> voice;
  final JsonPresence<num> speed;
  final JsonPresence<String> provider;
  final JsonPresence<String> modelVersion;
  final String altText;

  Map<String, Object?> toJson() => <String, Object?>{
        'fileId': fileId,
        'sha256': sha256,
        'mime': mime,
        'bytes': bytes,
        if (durationMs.isPresent) 'durationMs': durationMs.value,
        if (width.isPresent) 'width': width.value,
        if (height.isPresent) 'height': height.value,
        if (locale.isPresent) 'locale': locale.value,
        if (voice.isPresent) 'voice': voice.value,
        if (speed.isPresent) 'speed': speed.value,
        if (provider.isPresent) 'provider': provider.value,
        if (modelVersion.isPresent) 'modelVersion': modelVersion.value,
        'altText': altText,
      };
}

/// Wire DTO for `#/components/schemas/Choice`.
final class Choice {
  const Choice({
    required this.id,
    required this.text,
    this.imageAssetId = const JsonPresence<String>.absent(),
    this.audioAssetId = const JsonPresence<String>.absent(),
  });

  /// Validates [json] against the `Choice` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Choice.fromJson(Object? json) {
    ContractValidator.instance.check('Choice', json);
    return Choice._decode(json);
  }

  static Choice _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Choice(
      id: map['id'] as String,
      text: map['text'] as String,
      imageAssetId: map.containsKey('imageAssetId') ? JsonPresence<String>.value(map['imageAssetId'] == null ? null : map['imageAssetId'] as String) : const JsonPresence<String>.absent(),
      audioAssetId: map.containsKey('audioAssetId') ? JsonPresence<String>.value(map['audioAssetId'] == null ? null : map['audioAssetId'] as String) : const JsonPresence<String>.absent(),
    );
  }

  final String id;
  final String text;
  final JsonPresence<String> imageAssetId;
  final JsonPresence<String> audioAssetId;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'text': text,
        if (imageAssetId.isPresent) 'imageAssetId': imageAssetId.value,
        if (audioAssetId.isPresent) 'audioAssetId': audioAssetId.value,
      };
}

/// Wire DTO for `#/components/schemas/Token`.
final class Token {
  const Token({
    required this.id,
    required this.text,
  });

  /// Validates [json] against the `Token` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Token.fromJson(Object? json) {
    ContractValidator.instance.check('Token', json);
    return Token._decode(json);
  }

  static Token _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Token(
      id: map['id'] as String,
      text: map['text'] as String,
    );
  }

  final String id;
  final String text;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'text': text,
      };
}

/// Wire DTO for `#/components/schemas/Pair`.
final class Pair {
  const Pair({
    required this.id,
    required this.left,
    required this.right,
  });

  /// Validates [json] against the `Pair` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Pair.fromJson(Object? json) {
    ContractValidator.instance.check('Pair', json);
    return Pair._decode(json);
  }

  static Pair _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Pair(
      id: map['id'] as String,
      left: Choice._decode(map['left']),
      right: Choice._decode(map['right']),
    );
  }

  final String id;
  final Choice left;
  final Choice right;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'left': left.toJson(),
        'right': right.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/TextContent`.
final class TextContent {
  const TextContent({
    required this.placeholder,
    required this.maxChars,
  });

  /// Validates [json] against the `TextContent` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TextContent.fromJson(Object? json) {
    ContractValidator.instance.check('TextContent', json);
    return TextContent._decode(json);
  }

  static TextContent _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TextContent(
      placeholder: map['placeholder'] as String,
      maxChars: (map['maxChars'] as num).toInt(),
    );
  }

  final String placeholder;
  final int maxChars;

  Map<String, Object?> toJson() => <String, Object?>{
        'placeholder': placeholder,
        'maxChars': maxChars,
      };
}

/// Wire DTO for `#/components/schemas/ChoiceContent`.
final class ChoiceContent {
  const ChoiceContent({
    required this.choices,
  });

  /// Validates [json] against the `ChoiceContent` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ChoiceContent.fromJson(Object? json) {
    ContractValidator.instance.check('ChoiceContent', json);
    return ChoiceContent._decode(json);
  }

  static ChoiceContent _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ChoiceContent(
      choices: List<Choice>.unmodifiable((map['choices'] as List<Object?>).map((Object? x) => Choice._decode(x))),
    );
  }

  final List<Choice> choices;

  Map<String, Object?> toJson() => <String, Object?>{
        'choices': choices.map((Choice x) => x.toJson()).toList(),
      };
}

/// Wire DTO for `#/components/schemas/TokenContent`.
final class TokenContent {
  const TokenContent({
    required this.tokens,
  });

  /// Validates [json] against the `TokenContent` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TokenContent.fromJson(Object? json) {
    ContractValidator.instance.check('TokenContent', json);
    return TokenContent._decode(json);
  }

  static TokenContent _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TokenContent(
      tokens: List<Token>.unmodifiable((map['tokens'] as List<Object?>).map((Object? x) => Token._decode(x))),
    );
  }

  final List<Token> tokens;

  Map<String, Object?> toJson() => <String, Object?>{
        'tokens': tokens.map((Token x) => x.toJson()).toList(),
      };
}

/// Wire DTO for `#/components/schemas/PairContent`.
final class PairContent {
  const PairContent({
    required this.pairs,
  });

  /// Validates [json] against the `PairContent` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory PairContent.fromJson(Object? json) {
    ContractValidator.instance.check('PairContent', json);
    return PairContent._decode(json);
  }

  static PairContent _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PairContent(
      pairs: List<Pair>.unmodifiable((map['pairs'] as List<Object?>).map((Object? x) => Pair._decode(x))),
    );
  }

  final List<Pair> pairs;

  Map<String, Object?> toJson() => <String, Object?>{
        'pairs': pairs.map((Pair x) => x.toJson()).toList(),
      };
}

/// Wire DTO for `#/components/schemas/SpeechContent`.
final class SpeechContent {
  const SpeechContent({
    required this.referenceText,
    required this.locale,
    required this.maxSeconds,
  });

  /// Validates [json] against the `SpeechContent` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory SpeechContent.fromJson(Object? json) {
    ContractValidator.instance.check('SpeechContent', json);
    return SpeechContent._decode(json);
  }

  static SpeechContent _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return SpeechContent(
      referenceText: map['referenceText'] as String,
      locale: map['locale'] as String,
      maxSeconds: (map['maxSeconds'] as num).toInt(),
    );
  }

  final String referenceText;
  final String locale;
  final int maxSeconds;

  Map<String, Object?> toJson() => <String, Object?>{
        'referenceText': referenceText,
        'locale': locale,
        'maxSeconds': maxSeconds,
      };
}

/// Wire DTO for `#/components/schemas/StoryContent`.
final class StoryContent {
  const StoryContent({
    required this.passage,
    required this.question,
    required this.choices,
  });

  /// Validates [json] against the `StoryContent` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory StoryContent.fromJson(Object? json) {
    ContractValidator.instance.check('StoryContent', json);
    return StoryContent._decode(json);
  }

  static StoryContent _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return StoryContent(
      passage: map['passage'] as String,
      question: map['question'] as String,
      choices: List<Choice>.unmodifiable((map['choices'] as List<Object?>).map((Object? x) => Choice._decode(x))),
    );
  }

  final String passage;
  final String question;
  final List<Choice> choices;

  Map<String, Object?> toJson() => <String, Object?>{
        'passage': passage,
        'question': question,
        'choices': choices.map((Choice x) => x.toJson()).toList(),
      };
}

/// Wire DTO for `#/components/schemas/GradingRule`.
final class GradingRule {
  const GradingRule({
    required this.caseSensitive,
    required this.ignorePunctuation,
    required this.ignoreDiacritics,
    this.acceptedText,
    this.correctChoiceId = const JsonPresence<String>.absent(),
    this.correctTokenIds,
    this.correctPairIds,
  });

  /// Validates [json] against the `GradingRule` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory GradingRule.fromJson(Object? json) {
    ContractValidator.instance.check('GradingRule', json);
    return GradingRule._decode(json);
  }

  static GradingRule _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return GradingRule(
      caseSensitive: map['caseSensitive'] as bool,
      ignorePunctuation: map['ignorePunctuation'] as bool,
      ignoreDiacritics: map['ignoreDiacritics'] as bool,
      acceptedText: map.containsKey('acceptedText') ? List<String>.unmodifiable((map['acceptedText'] as List<Object?>).map((Object? x) => x as String)) : null,
      correctChoiceId: map.containsKey('correctChoiceId') ? JsonPresence<String>.value(map['correctChoiceId'] == null ? null : map['correctChoiceId'] as String) : const JsonPresence<String>.absent(),
      correctTokenIds: map.containsKey('correctTokenIds') ? List<String>.unmodifiable((map['correctTokenIds'] as List<Object?>).map((Object? x) => x as String)) : null,
      correctPairIds: map.containsKey('correctPairIds') ? List<String>.unmodifiable((map['correctPairIds'] as List<Object?>).map((Object? x) => x as String)) : null,
    );
  }

  final bool caseSensitive;
  final bool ignorePunctuation;
  final bool ignoreDiacritics;
  final List<String>? acceptedText;
  final JsonPresence<String> correctChoiceId;
  final List<String>? correctTokenIds;
  final List<String>? correctPairIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'caseSensitive': caseSensitive,
        'ignorePunctuation': ignorePunctuation,
        'ignoreDiacritics': ignoreDiacritics,
        if (acceptedText != null) 'acceptedText': List<Object?>.of(acceptedText!),
        if (correctChoiceId.isPresent) 'correctChoiceId': correctChoiceId.value,
        if (correctTokenIds != null) 'correctTokenIds': List<Object?>.of(correctTokenIds!),
        if (correctPairIds != null) 'correctPairIds': List<Object?>.of(correctPairIds!),
      };
}

/// Wire DTO for `#/components/schemas/ExerciseBase`.
final class ExerciseBase {
  const ExerciseBase({
    required this.id,
    required this.type,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `ExerciseBase` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ExerciseBase.fromJson(Object? json) {
    ContractValidator.instance.check('ExerciseBase', json);
    return ExerciseBase._decode(json);
  }

  static ExerciseBase _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ExerciseBase(
      id: map['id'] as String,
      type: map['type'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: Map<String, Object?>.unmodifiable(map['content'] as Map<Object?, Object?>),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  final String type;
  final Prompt prompt;
  final Map<String, Object?> content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': Map<String, Object?>.of(content),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/TextTranslationExercise`.
final class TextTranslationExercise implements Exercise {
  const TextTranslationExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `TextTranslationExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TextTranslationExercise.fromJson(Object? json) {
    ContractValidator.instance.check('TextTranslationExercise', json);
    return TextTranslationExercise._decode(json);
  }

  static TextTranslationExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TextTranslationExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: TextContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'textTranslation';
  final Prompt prompt;
  final TextContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/ChoiceExercise`.
final class ChoiceExercise implements Exercise {
  const ChoiceExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `ChoiceExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ChoiceExercise.fromJson(Object? json) {
    ContractValidator.instance.check('ChoiceExercise', json);
    return ChoiceExercise._decode(json);
  }

  static ChoiceExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ChoiceExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: ChoiceContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'choice';
  final Prompt prompt;
  final ChoiceContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/WordBankExercise`.
final class WordBankExercise implements Exercise {
  const WordBankExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `WordBankExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory WordBankExercise.fromJson(Object? json) {
    ContractValidator.instance.check('WordBankExercise', json);
    return WordBankExercise._decode(json);
  }

  static WordBankExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return WordBankExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: TokenContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'wordBank';
  final Prompt prompt;
  final TokenContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/SentenceOrderExercise`.
final class SentenceOrderExercise implements Exercise {
  const SentenceOrderExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `SentenceOrderExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory SentenceOrderExercise.fromJson(Object? json) {
    ContractValidator.instance.check('SentenceOrderExercise', json);
    return SentenceOrderExercise._decode(json);
  }

  static SentenceOrderExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return SentenceOrderExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: TokenContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'sentenceOrder';
  final Prompt prompt;
  final TokenContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/FillBlankExercise`.
final class FillBlankExercise implements Exercise {
  const FillBlankExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `FillBlankExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FillBlankExercise.fromJson(Object? json) {
    ContractValidator.instance.check('FillBlankExercise', json);
    return FillBlankExercise._decode(json);
  }

  static FillBlankExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FillBlankExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: TextContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'fillBlank';
  final Prompt prompt;
  final TextContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/MatchPairsExercise`.
final class MatchPairsExercise implements Exercise {
  const MatchPairsExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `MatchPairsExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory MatchPairsExercise.fromJson(Object? json) {
    ContractValidator.instance.check('MatchPairsExercise', json);
    return MatchPairsExercise._decode(json);
  }

  static MatchPairsExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return MatchPairsExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: PairContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'matchPairs';
  final Prompt prompt;
  final PairContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/ImageChoiceExercise`.
final class ImageChoiceExercise implements Exercise {
  const ImageChoiceExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `ImageChoiceExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ImageChoiceExercise.fromJson(Object? json) {
    ContractValidator.instance.check('ImageChoiceExercise', json);
    return ImageChoiceExercise._decode(json);
  }

  static ImageChoiceExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ImageChoiceExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: ChoiceContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'imageChoice';
  final Prompt prompt;
  final ChoiceContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/ListenChoiceExercise`.
final class ListenChoiceExercise implements Exercise {
  const ListenChoiceExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `ListenChoiceExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ListenChoiceExercise.fromJson(Object? json) {
    ContractValidator.instance.check('ListenChoiceExercise', json);
    return ListenChoiceExercise._decode(json);
  }

  static ListenChoiceExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ListenChoiceExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: ChoiceContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'listenChoice';
  final Prompt prompt;
  final ChoiceContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/DictationExercise`.
final class DictationExercise implements Exercise {
  const DictationExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `DictationExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory DictationExercise.fromJson(Object? json) {
    ContractValidator.instance.check('DictationExercise', json);
    return DictationExercise._decode(json);
  }

  static DictationExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return DictationExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: TextContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'dictation';
  final Prompt prompt;
  final TextContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/SpeakRepeatExercise`.
final class SpeakRepeatExercise implements Exercise {
  const SpeakRepeatExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `SpeakRepeatExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory SpeakRepeatExercise.fromJson(Object? json) {
    ContractValidator.instance.check('SpeakRepeatExercise', json);
    return SpeakRepeatExercise._decode(json);
  }

  static SpeakRepeatExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return SpeakRepeatExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: SpeechContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'speakRepeat';
  final Prompt prompt;
  final SpeechContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/DialogueTurnExercise`.
final class DialogueTurnExercise implements Exercise {
  const DialogueTurnExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `DialogueTurnExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory DialogueTurnExercise.fromJson(Object? json) {
    ContractValidator.instance.check('DialogueTurnExercise', json);
    return DialogueTurnExercise._decode(json);
  }

  static DialogueTurnExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return DialogueTurnExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: SpeechContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'dialogueTurn';
  final Prompt prompt;
  final SpeechContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/StoryQuestionExercise`.
final class StoryQuestionExercise implements Exercise {
  const StoryQuestionExercise({
    required this.id,
    required this.prompt,
    required this.content,
    required this.gradingRule,
    required this.hint,
    required this.explanation,
    required this.skillIds,
    required this.vocabularyIds,
    this.nonAudioAlternative,
    this.nonSpeechAlternative,
  });

  /// Validates [json] against the `StoryQuestionExercise` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory StoryQuestionExercise.fromJson(Object? json) {
    ContractValidator.instance.check('StoryQuestionExercise', json);
    return StoryQuestionExercise._decode(json);
  }

  static StoryQuestionExercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return StoryQuestionExercise(
      id: map['id'] as String,
      prompt: Prompt._decode(map['prompt']),
      content: StoryContent._decode(map['content']),
      gradingRule: GradingRule._decode(map['gradingRule']),
      hint: map['hint'] as String,
      explanation: map['explanation'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      vocabularyIds: List<String>.unmodifiable((map['vocabularyIds'] as List<Object?>).map((Object? x) => x as String)),
      nonAudioAlternative: map.containsKey('nonAudioAlternative') ? Exercise._decode(map['nonAudioAlternative']) : null,
      nonSpeechAlternative: map.containsKey('nonSpeechAlternative') ? Exercise._decode(map['nonSpeechAlternative']) : null,
    );
  }

  final String id;
  @override
  String get type => 'storyQuestion';
  final Prompt prompt;
  final StoryContent content;
  final GradingRule gradingRule;
  final String hint;
  final String explanation;
  final List<String> skillIds;
  final List<String> vocabularyIds;
  final Exercise? nonAudioAlternative;
  final Exercise? nonSpeechAlternative;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'prompt': prompt.toJson(),
        'content': content.toJson(),
        'gradingRule': gradingRule.toJson(),
        'hint': hint,
        'explanation': explanation,
        'skillIds': List<Object?>.of(skillIds),
        'vocabularyIds': List<Object?>.of(vocabularyIds),
        if (nonAudioAlternative != null) 'nonAudioAlternative': nonAudioAlternative!.toJson(),
        if (nonSpeechAlternative != null) 'nonSpeechAlternative': nonSpeechAlternative!.toJson(),
      };
}

/// Wire union for `#/components/schemas/Exercise` (oneOf, discriminated by `type`).
sealed class Exercise {
  /// Validates [json] against the `Exercise` schema (exactly one variant), then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Exercise.fromJson(Object? json) {
    ContractValidator.instance.check('Exercise', json);
    return Exercise._decode(json);
  }

  static Exercise _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return switch (map['type']) {
      'textTranslation' => TextTranslationExercise._decode(map),
      'choice' => ChoiceExercise._decode(map),
      'wordBank' => WordBankExercise._decode(map),
      'sentenceOrder' => SentenceOrderExercise._decode(map),
      'fillBlank' => FillBlankExercise._decode(map),
      'matchPairs' => MatchPairsExercise._decode(map),
      'imageChoice' => ImageChoiceExercise._decode(map),
      'listenChoice' => ListenChoiceExercise._decode(map),
      'dictation' => DictationExercise._decode(map),
      'speakRepeat' => SpeakRepeatExercise._decode(map),
      'dialogueTurn' => DialogueTurnExercise._decode(map),
      'storyQuestion' => StoryQuestionExercise._decode(map),
      _ => throw StateError('Unknown Exercise.type after validation'),
    };
  }

  /// Discriminator value of this variant.
  String get type;

  Map<String, Object?> toJson();
}

/// Wire DTO for `#/components/schemas/LessonBundle`.
final class LessonBundle {
  const LessonBundle({
    required this.courseId,
    required this.courseVersion,
    required this.sectionId,
    required this.unitId,
    required this.nodeId,
    required this.order,
    required this.lessonId,
    required this.lessonVersion,
    required this.rewardIdentity,
    required this.title,
    required this.skillIds,
    this.guideText,
    required this.exercises,
    required this.assets,
    required this.gradingRulesVersion,
    required this.manifestHash,
    required this.signature,
    required this.signatureKeyId,
  });

  /// Validates [json] against the `LessonBundle` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory LessonBundle.fromJson(Object? json) {
    ContractValidator.instance.check('LessonBundle', json);
    return LessonBundle._decode(json);
  }

  static LessonBundle _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return LessonBundle(
      courseId: map['courseId'] as String,
      courseVersion: map['courseVersion'] as String,
      sectionId: map['sectionId'] as String,
      unitId: map['unitId'] as String,
      nodeId: map['nodeId'] as String,
      order: (map['order'] as num).toInt(),
      lessonId: map['lessonId'] as String,
      lessonVersion: map['lessonVersion'] as String,
      rewardIdentity: map['rewardIdentity'] as String,
      title: map['title'] as String,
      skillIds: List<String>.unmodifiable((map['skillIds'] as List<Object?>).map((Object? x) => x as String)),
      guideText: map.containsKey('guideText') ? map['guideText'] as String : null,
      exercises: List<Exercise>.unmodifiable((map['exercises'] as List<Object?>).map((Object? x) => Exercise._decode(x))),
      assets: List<Asset>.unmodifiable((map['assets'] as List<Object?>).map((Object? x) => Asset._decode(x))),
      gradingRulesVersion: map['gradingRulesVersion'] as String,
      manifestHash: map['manifestHash'] as String,
      signature: map['signature'] as String,
      signatureKeyId: map['signatureKeyId'] as String,
    );
  }

  int get schemaVersion => 1;
  final String courseId;
  final String courseVersion;
  final String sectionId;
  final String unitId;
  final String nodeId;
  final int order;
  final String lessonId;
  final String lessonVersion;
  final String rewardIdentity;
  final String title;
  final List<String> skillIds;
  final String? guideText;
  final List<Exercise> exercises;
  final List<Asset> assets;
  final String gradingRulesVersion;
  final String manifestHash;
  final String signature;
  final String signatureKeyId;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'courseId': courseId,
        'courseVersion': courseVersion,
        'sectionId': sectionId,
        'unitId': unitId,
        'nodeId': nodeId,
        'order': order,
        'lessonId': lessonId,
        'lessonVersion': lessonVersion,
        'rewardIdentity': rewardIdentity,
        'title': title,
        'skillIds': List<Object?>.of(skillIds),
        'guideText': ?guideText,
        'exercises': exercises.map((Exercise x) => x.toJson()).toList(),
        'assets': assets.map((Asset x) => x.toJson()).toList(),
        'gradingRulesVersion': gradingRulesVersion,
        'manifestHash': manifestHash,
        'signature': signature,
        'signatureKeyId': signatureKeyId,
      };
}

/// Wire DTO for `#/components/schemas/Course`.
final class Course {
  const Course({
    required this.courseId,
    required this.title,
    required this.sourceLocale,
    required this.targetLocale,
    required this.publishedVersion,
    required this.available,
  });

  /// Validates [json] against the `Course` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Course.fromJson(Object? json) {
    ContractValidator.instance.check('Course', json);
    return Course._decode(json);
  }

  static Course _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Course(
      courseId: map['courseId'] as String,
      title: map['title'] as String,
      sourceLocale: map['sourceLocale'] as String,
      targetLocale: map['targetLocale'] as String,
      publishedVersion: map['publishedVersion'] as String,
      available: map['available'] as bool,
    );
  }

  final String courseId;
  final String title;
  final String sourceLocale;
  final String targetLocale;
  final String publishedVersion;
  final bool available;

  Map<String, Object?> toJson() => <String, Object?>{
        'courseId': courseId,
        'title': title,
        'sourceLocale': sourceLocale,
        'targetLocale': targetLocale,
        'publishedVersion': publishedVersion,
        'available': available,
      };
}

/// Wire DTO for `#/components/schemas/Enrollment`.
final class Enrollment {
  const Enrollment({
    required this.courseId,
    required this.courseVersion,
    required this.frontierNodeOrder,
    required this.completedLessonIds,
    required this.masteredNodeIds,
    required this.revision,
  });

  /// Validates [json] against the `Enrollment` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Enrollment.fromJson(Object? json) {
    ContractValidator.instance.check('Enrollment', json);
    return Enrollment._decode(json);
  }

  static Enrollment _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Enrollment(
      courseId: map['courseId'] as String,
      courseVersion: map['courseVersion'] as String,
      frontierNodeOrder: (map['frontierNodeOrder'] as num).toInt(),
      completedLessonIds: List<String>.unmodifiable((map['completedLessonIds'] as List<Object?>).map((Object? x) => x as String)),
      masteredNodeIds: List<String>.unmodifiable((map['masteredNodeIds'] as List<Object?>).map((Object? x) => x as String)),
      revision: (map['revision'] as num).toInt(),
    );
  }

  final String courseId;
  final String courseVersion;
  final int frontierNodeOrder;
  final List<String> completedLessonIds;
  final List<String> masteredNodeIds;
  final int revision;

  Map<String, Object?> toJson() => <String, Object?>{
        'courseId': courseId,
        'courseVersion': courseVersion,
        'frontierNodeOrder': frontierNodeOrder,
        'completedLessonIds': List<Object?>.of(completedLessonIds),
        'masteredNodeIds': List<Object?>.of(masteredNodeIds),
        'revision': revision,
      };
}

/// Wire DTO for `#/components/schemas/Node`.
final class Node {
  const Node({
    required this.nodeId,
    required this.unitId,
    required this.sectionId,
    required this.order,
    required this.title,
    required this.kind,
    required this.state,
    required this.lessonIds,
  });

  /// Validates [json] against the `Node` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Node.fromJson(Object? json) {
    ContractValidator.instance.check('Node', json);
    return Node._decode(json);
  }

  static Node _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Node(
      nodeId: map['nodeId'] as String,
      unitId: map['unitId'] as String,
      sectionId: map['sectionId'] as String,
      order: (map['order'] as num).toInt(),
      title: map['title'] as String,
      kind: map['kind'] as String,
      state: map['state'] as String,
      lessonIds: List<String>.unmodifiable((map['lessonIds'] as List<Object?>).map((Object? x) => x as String)),
    );
  }

  final String nodeId;
  final String unitId;
  final String sectionId;
  final int order;
  final String title;
  final String kind;
  final String state;
  final List<String> lessonIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'nodeId': nodeId,
        'unitId': unitId,
        'sectionId': sectionId,
        'order': order,
        'title': title,
        'kind': kind,
        'state': state,
        'lessonIds': List<Object?>.of(lessonIds),
      };
}

/// Wire DTO for `#/components/schemas/Path`.
final class Path {
  const Path({
    required this.enrollment,
    required this.nodes,
    required this.asOf,
    required this.nextCursor,
  });

  /// Validates [json] against the `Path` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Path.fromJson(Object? json) {
    ContractValidator.instance.check('Path', json);
    return Path._decode(json);
  }

  static Path _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Path(
      enrollment: Enrollment._decode(map['enrollment']),
      nodes: List<Node>.unmodifiable((map['nodes'] as List<Object?>).map((Object? x) => Node._decode(x))),
      asOf: map['asOf'] as String,
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
    );
  }

  final Enrollment enrollment;
  final List<Node> nodes;
  final String asOf;
  final String? nextCursor;

  Map<String, Object?> toJson() => <String, Object?>{
        'enrollment': enrollment.toJson(),
        'nodes': nodes.map((Node x) => x.toJson()).toList(),
        'asOf': asOf,
        'nextCursor': nextCursor,
      };
}

/// Wire DTO for `#/components/schemas/ContentNode`.
final class ContentNode {
  const ContentNode({
    required this.nodeId,
    required this.unitId,
    required this.sectionId,
    required this.order,
    required this.title,
    required this.kind,
    required this.lessonIds,
  });

  /// Validates [json] against the `ContentNode` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ContentNode.fromJson(Object? json) {
    ContractValidator.instance.check('ContentNode', json);
    return ContentNode._decode(json);
  }

  static ContentNode _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ContentNode(
      nodeId: map['nodeId'] as String,
      unitId: map['unitId'] as String,
      sectionId: map['sectionId'] as String,
      order: (map['order'] as num).toInt(),
      title: map['title'] as String,
      kind: map['kind'] as String,
      lessonIds: List<String>.unmodifiable((map['lessonIds'] as List<Object?>).map((Object? x) => x as String)),
    );
  }

  final String nodeId;
  final String unitId;
  final String sectionId;
  final int order;
  final String title;
  final String kind;
  final List<String> lessonIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'nodeId': nodeId,
        'unitId': unitId,
        'sectionId': sectionId,
        'order': order,
        'title': title,
        'kind': kind,
        'lessonIds': List<Object?>.of(lessonIds),
      };
}

/// Wire DTO for `#/components/schemas/ContentSection`.
final class ContentSection {
  const ContentSection({
    required this.sectionId,
    required this.title,
    required this.unitIds,
  });

  /// Validates [json] against the `ContentSection` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ContentSection.fromJson(Object? json) {
    ContractValidator.instance.check('ContentSection', json);
    return ContentSection._decode(json);
  }

  static ContentSection _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ContentSection(
      sectionId: map['sectionId'] as String,
      title: map['title'] as String,
      unitIds: List<String>.unmodifiable((map['unitIds'] as List<Object?>).map((Object? x) => x as String)),
    );
  }

  final String sectionId;
  final String title;
  final List<String> unitIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'sectionId': sectionId,
        'title': title,
        'unitIds': List<Object?>.of(unitIds),
      };
}

/// Wire DTO for `#/components/schemas/ContentUnit`.
final class ContentUnit {
  const ContentUnit({
    required this.unitId,
    required this.sectionId,
    required this.title,
    required this.guideText,
    required this.nodeIds,
  });

  /// Validates [json] against the `ContentUnit` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ContentUnit.fromJson(Object? json) {
    ContractValidator.instance.check('ContentUnit', json);
    return ContentUnit._decode(json);
  }

  static ContentUnit _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ContentUnit(
      unitId: map['unitId'] as String,
      sectionId: map['sectionId'] as String,
      title: map['title'] as String,
      guideText: map['guideText'] as String,
      nodeIds: List<String>.unmodifiable((map['nodeIds'] as List<Object?>).map((Object? x) => x as String)),
    );
  }

  final String unitId;
  final String sectionId;
  final String title;
  final String guideText;
  final List<String> nodeIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'unitId': unitId,
        'sectionId': sectionId,
        'title': title,
        'guideText': guideText,
        'nodeIds': List<Object?>.of(nodeIds),
      };
}

/// Wire DTO for `#/components/schemas/BundleIndex`.
final class BundleIndex {
  const BundleIndex({
    required this.lessonId,
    required this.lessonVersion,
    required this.rewardIdentity,
    required this.fileId,
    required this.sha256,
  });

  /// Validates [json] against the `BundleIndex` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory BundleIndex.fromJson(Object? json) {
    ContractValidator.instance.check('BundleIndex', json);
    return BundleIndex._decode(json);
  }

  static BundleIndex _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BundleIndex(
      lessonId: map['lessonId'] as String,
      lessonVersion: map['lessonVersion'] as String,
      rewardIdentity: map['rewardIdentity'] as String,
      fileId: map['fileId'] as String,
      sha256: map['sha256'] as String,
    );
  }

  final String lessonId;
  final String lessonVersion;
  final String rewardIdentity;
  final String fileId;
  final String sha256;

  Map<String, Object?> toJson() => <String, Object?>{
        'lessonId': lessonId,
        'lessonVersion': lessonVersion,
        'rewardIdentity': rewardIdentity,
        'fileId': fileId,
        'sha256': sha256,
      };
}

/// Wire DTO for `#/components/schemas/CourseManifest`.
final class CourseManifest {
  const CourseManifest({
    required this.courseId,
    required this.courseVersion,
    required this.sourceLocale,
    required this.targetLocale,
    required this.title,
    required this.sections,
    required this.units,
    required this.nodes,
    required this.bundles,
    required this.placementBundle,
    required this.manifestHash,
    required this.signatureKeyId,
    required this.signature,
  });

  /// Validates [json] against the `CourseManifest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory CourseManifest.fromJson(Object? json) {
    ContractValidator.instance.check('CourseManifest', json);
    return CourseManifest._decode(json);
  }

  static CourseManifest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return CourseManifest(
      courseId: map['courseId'] as String,
      courseVersion: map['courseVersion'] as String,
      sourceLocale: map['sourceLocale'] as String,
      targetLocale: map['targetLocale'] as String,
      title: map['title'] as String,
      sections: List<ContentSection>.unmodifiable((map['sections'] as List<Object?>).map((Object? x) => ContentSection._decode(x))),
      units: List<ContentUnit>.unmodifiable((map['units'] as List<Object?>).map((Object? x) => ContentUnit._decode(x))),
      nodes: List<ContentNode>.unmodifiable((map['nodes'] as List<Object?>).map((Object? x) => ContentNode._decode(x))),
      bundles: List<BundleIndex>.unmodifiable((map['bundles'] as List<Object?>).map((Object? x) => BundleIndex._decode(x))),
      placementBundle: BundleIndex._decode(map['placementBundle']),
      manifestHash: map['manifestHash'] as String,
      signatureKeyId: map['signatureKeyId'] as String,
      signature: map['signature'] as String,
    );
  }

  int get schemaVersion => 1;
  final String courseId;
  final String courseVersion;
  final String sourceLocale;
  final String targetLocale;
  final String title;
  final List<ContentSection> sections;
  final List<ContentUnit> units;
  final List<ContentNode> nodes;
  final List<BundleIndex> bundles;
  final BundleIndex placementBundle;
  final String manifestHash;
  final String signatureKeyId;
  final String signature;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'courseId': courseId,
        'courseVersion': courseVersion,
        'sourceLocale': sourceLocale,
        'targetLocale': targetLocale,
        'title': title,
        'sections': sections.map((ContentSection x) => x.toJson()).toList(),
        'units': units.map((ContentUnit x) => x.toJson()).toList(),
        'nodes': nodes.map((ContentNode x) => x.toJson()).toList(),
        'bundles': bundles.map((BundleIndex x) => x.toJson()).toList(),
        'placementBundle': placementBundle.toJson(),
        'manifestHash': manifestHash,
        'signatureKeyId': signatureKeyId,
        'signature': signature,
      };
}

/// Wire DTO for `#/components/schemas/EnrollRequest`.
final class EnrollRequest {
  const EnrollRequest({
    required this.courseId,
    required this.startPoint,
    this.placementSessionId = const JsonPresence<String>.absent(),
  });

  /// Validates [json] against the `EnrollRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory EnrollRequest.fromJson(Object? json) {
    ContractValidator.instance.check('EnrollRequest', json);
    return EnrollRequest._decode(json);
  }

  static EnrollRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return EnrollRequest(
      courseId: map['courseId'] as String,
      startPoint: map['startPoint'] as String,
      placementSessionId: map.containsKey('placementSessionId') ? JsonPresence<String>.value(map['placementSessionId'] == null ? null : map['placementSessionId'] as String) : const JsonPresence<String>.absent(),
    );
  }

  final String courseId;
  final String startPoint;
  final JsonPresence<String> placementSessionId;

  Map<String, Object?> toJson() => <String, Object?>{
        'courseId': courseId,
        'startPoint': startPoint,
        if (placementSessionId.isPresent) 'placementSessionId': placementSessionId.value,
      };
}

/// Wire DTO for `#/components/schemas/SessionRequest`.
final class SessionRequest {
  const SessionRequest({
    required this.courseId,
    required this.lessonId,
    required this.mode,
    required this.expectedEnrollmentRevision,
  });

  /// Validates [json] against the `SessionRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory SessionRequest.fromJson(Object? json) {
    ContractValidator.instance.check('SessionRequest', json);
    return SessionRequest._decode(json);
  }

  static SessionRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return SessionRequest(
      courseId: map['courseId'] as String,
      lessonId: map['lessonId'] as String,
      mode: map['mode'] as String,
      expectedEnrollmentRevision: (map['expectedEnrollmentRevision'] as num).toInt(),
    );
  }

  final String courseId;
  final String lessonId;
  final String mode;
  final int expectedEnrollmentRevision;

  Map<String, Object?> toJson() => <String, Object?>{
        'courseId': courseId,
        'lessonId': lessonId,
        'mode': mode,
        'expectedEnrollmentRevision': expectedEnrollmentRevision,
      };
}

/// Wire DTO for `#/components/schemas/Session`.
final class Session {
  const Session({
    required this.sessionId,
    required this.courseId,
    required this.lessonId,
    required this.lessonVersion,
    required this.status,
    required this.mode,
    required this.revision,
    required this.nextOriginalOrdinal,
    required this.retryPass,
    required this.expiresAt,
    required this.bundle,
    required this.answerHistory,
    required this.lastFeedback,
  });

  /// Validates [json] against the `Session` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Session.fromJson(Object? json) {
    ContractValidator.instance.check('Session', json);
    return Session._decode(json);
  }

  static Session _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Session(
      sessionId: map['sessionId'] as String,
      courseId: map['courseId'] as String,
      lessonId: map['lessonId'] as String,
      lessonVersion: map['lessonVersion'] as String,
      status: map['status'] as String,
      mode: map['mode'] as String,
      revision: (map['revision'] as num).toInt(),
      nextOriginalOrdinal: (map['nextOriginalOrdinal'] as num).toInt(),
      retryPass: (map['retryPass'] as num).toInt(),
      expiresAt: map['expiresAt'] as String,
      bundle: LessonBundle._decode(map['bundle']),
      answerHistory: List<OfflineAnswer>.unmodifiable((map['answerHistory'] as List<Object?>).map((Object? x) => OfflineAnswer._decode(x))),
      lastFeedback: map['lastFeedback'] == null ? null : AnswerResult._decode(map['lastFeedback']),
    );
  }

  final String sessionId;
  final String courseId;
  final String lessonId;
  final String lessonVersion;
  final String status;
  final String mode;
  final int revision;
  final int nextOriginalOrdinal;
  final int retryPass;
  final String expiresAt;
  final LessonBundle bundle;
  final List<OfflineAnswer> answerHistory;
  final AnswerResult? lastFeedback;

  Map<String, Object?> toJson() => <String, Object?>{
        'sessionId': sessionId,
        'courseId': courseId,
        'lessonId': lessonId,
        'lessonVersion': lessonVersion,
        'status': status,
        'mode': mode,
        'revision': revision,
        'nextOriginalOrdinal': nextOriginalOrdinal,
        'retryPass': retryPass,
        'expiresAt': expiresAt,
        'bundle': bundle.toJson(),
        'answerHistory': answerHistory.map((OfflineAnswer x) => x.toJson()).toList(),
        'lastFeedback': lastFeedback?.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/TextAnswer`.
final class TextAnswer implements Answer {
  const TextAnswer({
    required this.text,
  });

  /// Validates [json] against the `TextAnswer` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TextAnswer.fromJson(Object? json) {
    ContractValidator.instance.check('TextAnswer', json);
    return TextAnswer._decode(json);
  }

  static TextAnswer _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TextAnswer(
      text: map['text'] as String,
    );
  }

  @override
  String get kind => 'text';
  final String text;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'text': text,
      };
}

/// Wire DTO for `#/components/schemas/ChoiceAnswer`.
final class ChoiceAnswer implements Answer {
  const ChoiceAnswer({
    required this.choiceId,
  });

  /// Validates [json] against the `ChoiceAnswer` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ChoiceAnswer.fromJson(Object? json) {
    ContractValidator.instance.check('ChoiceAnswer', json);
    return ChoiceAnswer._decode(json);
  }

  static ChoiceAnswer _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ChoiceAnswer(
      choiceId: map['choiceId'] as String,
    );
  }

  @override
  String get kind => 'choice';
  final String choiceId;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'choiceId': choiceId,
      };
}

/// Wire DTO for `#/components/schemas/TokenAnswer`.
final class TokenAnswer implements Answer {
  const TokenAnswer({
    required this.tokenIds,
  });

  /// Validates [json] against the `TokenAnswer` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TokenAnswer.fromJson(Object? json) {
    ContractValidator.instance.check('TokenAnswer', json);
    return TokenAnswer._decode(json);
  }

  static TokenAnswer _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TokenAnswer(
      tokenIds: List<String>.unmodifiable((map['tokenIds'] as List<Object?>).map((Object? x) => x as String)),
    );
  }

  @override
  String get kind => 'tokens';
  final List<String> tokenIds;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'tokenIds': List<Object?>.of(tokenIds),
      };
}

/// Wire DTO for `#/components/schemas/PairAnswer`.
final class PairAnswer implements Answer {
  const PairAnswer({
    required this.matches,
  });

  /// Validates [json] against the `PairAnswer` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory PairAnswer.fromJson(Object? json) {
    ContractValidator.instance.check('PairAnswer', json);
    return PairAnswer._decode(json);
  }

  static PairAnswer _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PairAnswer(
      matches: List<PairAnswerMatchesItem>.unmodifiable((map['matches'] as List<Object?>).map((Object? x) => PairAnswerMatchesItem._decode(x))),
    );
  }

  @override
  String get kind => 'pairs';
  final List<PairAnswerMatchesItem> matches;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'matches': matches.map((PairAnswerMatchesItem x) => x.toJson()).toList(),
      };
}

/// Inline wire object `PairAnswerMatchesItem` (nested in a component schema).
final class PairAnswerMatchesItem {
  const PairAnswerMatchesItem({
    required this.leftId,
    required this.rightId,
  });

  static PairAnswerMatchesItem _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PairAnswerMatchesItem(
      leftId: map['leftId'] as String,
      rightId: map['rightId'] as String,
    );
  }

  final String leftId;
  final String rightId;

  Map<String, Object?> toJson() => <String, Object?>{
        'leftId': leftId,
        'rightId': rightId,
      };
}

/// Wire DTO for `#/components/schemas/SpeechAnswer`.
final class SpeechAnswer implements Answer {
  const SpeechAnswer({
    required this.assessmentJobId,
  });

  /// Validates [json] against the `SpeechAnswer` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory SpeechAnswer.fromJson(Object? json) {
    ContractValidator.instance.check('SpeechAnswer', json);
    return SpeechAnswer._decode(json);
  }

  static SpeechAnswer _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return SpeechAnswer(
      assessmentJobId: map['assessmentJobId'] as String,
    );
  }

  @override
  String get kind => 'speech';
  final String assessmentJobId;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'assessmentJobId': assessmentJobId,
      };
}

/// Wire union for `#/components/schemas/Answer` (oneOf, discriminated by `kind`).
sealed class Answer {
  /// Validates [json] against the `Answer` schema (exactly one variant), then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Answer.fromJson(Object? json) {
    ContractValidator.instance.check('Answer', json);
    return Answer._decode(json);
  }

  static Answer _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return switch (map['kind']) {
      'text' => TextAnswer._decode(map),
      'choice' => ChoiceAnswer._decode(map),
      'tokens' => TokenAnswer._decode(map),
      'pairs' => PairAnswer._decode(map),
      'speech' => SpeechAnswer._decode(map),
      _ => throw StateError('Unknown Answer.kind after validation'),
    };
  }

  /// Discriminator value of this variant.
  String get kind;

  Map<String, Object?> toJson();
}

/// Wire DTO for `#/components/schemas/AnswerRequest`.
final class AnswerRequest {
  const AnswerRequest({
    required this.exerciseId,
    required this.attemptOrdinal,
    required this.answer,
    required this.assisted,
    required this.substituted,
    required this.expectedRevision,
  });

  /// Validates [json] against the `AnswerRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory AnswerRequest.fromJson(Object? json) {
    ContractValidator.instance.check('AnswerRequest', json);
    return AnswerRequest._decode(json);
  }

  static AnswerRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return AnswerRequest(
      exerciseId: map['exerciseId'] as String,
      attemptOrdinal: (map['attemptOrdinal'] as num).toInt(),
      answer: Answer._decode(map['answer']),
      assisted: map['assisted'] as bool,
      substituted: map['substituted'] as bool,
      expectedRevision: (map['expectedRevision'] as num).toInt(),
    );
  }

  final String exerciseId;
  final int attemptOrdinal;
  final Answer answer;
  final bool assisted;
  final bool substituted;
  final int expectedRevision;

  Map<String, Object?> toJson() => <String, Object?>{
        'exerciseId': exerciseId,
        'attemptOrdinal': attemptOrdinal,
        'answer': answer.toJson(),
        'assisted': assisted,
        'substituted': substituted,
        'expectedRevision': expectedRevision,
      };
}

/// Wire DTO for `#/components/schemas/AnswerResult`.
final class AnswerResult {
  const AnswerResult({
    required this.exerciseId,
    required this.correct,
    required this.explanation,
    required this.acceptedAnswer,
    required this.nextOriginalOrdinal,
    required this.retryPass,
    required this.sessionRevision,
    required this.provisional,
  });

  /// Validates [json] against the `AnswerResult` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory AnswerResult.fromJson(Object? json) {
    ContractValidator.instance.check('AnswerResult', json);
    return AnswerResult._decode(json);
  }

  static AnswerResult _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return AnswerResult(
      exerciseId: map['exerciseId'] as String,
      correct: map['correct'] as bool,
      explanation: map['explanation'] as String,
      acceptedAnswer: map['acceptedAnswer'] as String,
      nextOriginalOrdinal: (map['nextOriginalOrdinal'] as num).toInt(),
      retryPass: (map['retryPass'] as num).toInt(),
      sessionRevision: (map['sessionRevision'] as num).toInt(),
      provisional: map['provisional'] as bool,
    );
  }

  final String exerciseId;
  final bool correct;
  final String explanation;
  final String acceptedAnswer;
  final int nextOriginalOrdinal;
  final int retryPass;
  final int sessionRevision;
  final bool provisional;

  Map<String, Object?> toJson() => <String, Object?>{
        'exerciseId': exerciseId,
        'correct': correct,
        'explanation': explanation,
        'acceptedAnswer': acceptedAnswer,
        'nextOriginalOrdinal': nextOriginalOrdinal,
        'retryPass': retryPass,
        'sessionRevision': sessionRevision,
        'provisional': provisional,
      };
}

/// Wire DTO for `#/components/schemas/CompleteRequest`.
final class CompleteRequest {
  const CompleteRequest({
    required this.expectedRevision,
  });

  /// Validates [json] against the `CompleteRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory CompleteRequest.fromJson(Object? json) {
    ContractValidator.instance.check('CompleteRequest', json);
    return CompleteRequest._decode(json);
  }

  static CompleteRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return CompleteRequest(
      expectedRevision: (map['expectedRevision'] as num).toInt(),
    );
  }

  final int expectedRevision;

  Map<String, Object?> toJson() => <String, Object?>{
        'expectedRevision': expectedRevision,
      };
}

/// Wire DTO for `#/components/schemas/Completion`.
final class Completion {
  const Completion({
    required this.completionId,
    required this.sessionId,
    required this.originalCount,
    required this.originalCorrect,
    required this.assisted,
    required this.source,
    required this.mode,
    required this.completedAt,
    required this.enrollmentRevision,
    required this.rewardStatus,
    required this.needsReviewIds,
  });

  /// Validates [json] against the `Completion` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Completion.fromJson(Object? json) {
    ContractValidator.instance.check('Completion', json);
    return Completion._decode(json);
  }

  static Completion _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Completion(
      completionId: map['completionId'] as String,
      sessionId: map['sessionId'] as String,
      originalCount: (map['originalCount'] as num).toInt(),
      originalCorrect: (map['originalCorrect'] as num).toInt(),
      assisted: map['assisted'] as bool,
      source: map['source'] as String,
      mode: map['mode'] as String,
      completedAt: map['completedAt'] as String,
      enrollmentRevision: (map['enrollmentRevision'] as num).toInt(),
      rewardStatus: map['rewardStatus'] as String,
      needsReviewIds: List<String>.unmodifiable((map['needsReviewIds'] as List<Object?>).map((Object? x) => x as String)),
    );
  }

  final String completionId;
  final String sessionId;
  final int originalCount;
  final int originalCorrect;
  final bool assisted;
  final String source;
  final String mode;
  final String completedAt;
  final int enrollmentRevision;
  final String rewardStatus;
  final List<String> needsReviewIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'completionId': completionId,
        'sessionId': sessionId,
        'originalCount': originalCount,
        'originalCorrect': originalCorrect,
        'assisted': assisted,
        'source': source,
        'mode': mode,
        'completedAt': completedAt,
        'enrollmentRevision': enrollmentRevision,
        'rewardStatus': rewardStatus,
        'needsReviewIds': List<Object?>.of(needsReviewIds),
      };
}

/// Wire DTO for `#/components/schemas/OfflineAnswer`.
final class OfflineAnswer {
  const OfflineAnswer({
    required this.exerciseId,
    required this.attemptOrdinal,
    required this.answer,
    required this.assisted,
    required this.substituted,
  });

  /// Validates [json] against the `OfflineAnswer` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory OfflineAnswer.fromJson(Object? json) {
    ContractValidator.instance.check('OfflineAnswer', json);
    return OfflineAnswer._decode(json);
  }

  static OfflineAnswer _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return OfflineAnswer(
      exerciseId: map['exerciseId'] as String,
      attemptOrdinal: (map['attemptOrdinal'] as num).toInt(),
      answer: Answer._decode(map['answer']),
      assisted: map['assisted'] as bool,
      substituted: map['substituted'] as bool,
    );
  }

  final String exerciseId;
  final int attemptOrdinal;
  final Answer answer;
  final bool assisted;
  final bool substituted;

  Map<String, Object?> toJson() => <String, Object?>{
        'exerciseId': exerciseId,
        'attemptOrdinal': attemptOrdinal,
        'answer': answer.toJson(),
        'assisted': assisted,
        'substituted': substituted,
      };
}

/// Wire DTO for `#/components/schemas/OfflineCompletionRequest`.
final class OfflineCompletionRequest {
  const OfflineCompletionRequest({
    required this.operationId,
    required this.localCompletionId,
    required this.courseId,
    required this.lessonId,
    required this.lessonVersion,
    required this.bundleHash,
    required this.expectedEnrollmentRevision,
    required this.answers,
  });

  /// Validates [json] against the `OfflineCompletionRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory OfflineCompletionRequest.fromJson(Object? json) {
    ContractValidator.instance.check('OfflineCompletionRequest', json);
    return OfflineCompletionRequest._decode(json);
  }

  static OfflineCompletionRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return OfflineCompletionRequest(
      operationId: map['operationId'] as String,
      localCompletionId: map['localCompletionId'] as String,
      courseId: map['courseId'] as String,
      lessonId: map['lessonId'] as String,
      lessonVersion: map['lessonVersion'] as String,
      bundleHash: map['bundleHash'] as String,
      expectedEnrollmentRevision: (map['expectedEnrollmentRevision'] as num).toInt(),
      answers: List<OfflineAnswer>.unmodifiable((map['answers'] as List<Object?>).map((Object? x) => OfflineAnswer._decode(x))),
    );
  }

  final String operationId;
  final String localCompletionId;
  final String courseId;
  final String lessonId;
  final String lessonVersion;
  final String bundleHash;
  final int expectedEnrollmentRevision;
  final List<OfflineAnswer> answers;

  Map<String, Object?> toJson() => <String, Object?>{
        'operationId': operationId,
        'localCompletionId': localCompletionId,
        'courseId': courseId,
        'lessonId': lessonId,
        'lessonVersion': lessonVersion,
        'bundleHash': bundleHash,
        'expectedEnrollmentRevision': expectedEnrollmentRevision,
        'answers': answers.map((OfflineAnswer x) => x.toJson()).toList(),
      };
}

/// Wire DTO for `#/components/schemas/ReportRequest`.
final class ReportRequest {
  const ReportRequest({
    required this.exerciseId,
    required this.lessonVersion,
    required this.category,
    this.note,
  });

  /// Validates [json] against the `ReportRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ReportRequest.fromJson(Object? json) {
    ContractValidator.instance.check('ReportRequest', json);
    return ReportRequest._decode(json);
  }

  static ReportRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ReportRequest(
      exerciseId: map['exerciseId'] as String,
      lessonVersion: map['lessonVersion'] as String,
      category: map['category'] as String,
      note: map.containsKey('note') ? map['note'] as String : null,
    );
  }

  final String exerciseId;
  final String lessonVersion;
  final String category;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
        'exerciseId': exerciseId,
        'lessonVersion': lessonVersion,
        'category': category,
        'note': ?note,
      };
}

/// Wire DTO for `#/components/schemas/Receipt`.
final class Receipt {
  const Receipt({
    required this.operationId,
    required this.status,
    required this.requestId,
  });

  /// Validates [json] against the `Receipt` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Receipt.fromJson(Object? json) {
    ContractValidator.instance.check('Receipt', json);
    return Receipt._decode(json);
  }

  static Receipt _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Receipt(
      operationId: map['operationId'] as String,
      status: map['status'] as String,
      requestId: map['requestId'] as String,
    );
  }

  final String operationId;
  final String status;
  final String requestId;

  Map<String, Object?> toJson() => <String, Object?>{
        'operationId': operationId,
        'status': status,
        'requestId': requestId,
      };
}

/// Wire DTO for `#/components/schemas/ReviewItem`.
final class ReviewItem {
  const ReviewItem({
    required this.vocabularyId,
    required this.skillId,
    required this.dueAt,
    required this.stage,
    required this.mastery,
  });

  /// Validates [json] against the `ReviewItem` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ReviewItem.fromJson(Object? json) {
    ContractValidator.instance.check('ReviewItem', json);
    return ReviewItem._decode(json);
  }

  static ReviewItem _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ReviewItem(
      vocabularyId: map['vocabularyId'] as String,
      skillId: map['skillId'] as String,
      dueAt: map['dueAt'] as String,
      stage: (map['stage'] as num).toInt(),
      mastery: map['mastery'] == null ? null : map['mastery'] as num,
    );
  }

  final String vocabularyId;
  final String skillId;
  final String dueAt;
  final int stage;
  final num? mastery;

  Map<String, Object?> toJson() => <String, Object?>{
        'vocabularyId': vocabularyId,
        'skillId': skillId,
        'dueAt': dueAt,
        'stage': stage,
        'mastery': mastery,
      };
}

/// Wire DTO for `#/components/schemas/PublishRequest`.
final class PublishRequest {
  const PublishRequest({
    required this.courseId,
    required this.versionId,
    required this.manifestFileId,
    required this.manifestSha256,
    required this.expectedPublishedVersion,
  });

  /// Validates [json] against the `PublishRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory PublishRequest.fromJson(Object? json) {
    ContractValidator.instance.check('PublishRequest', json);
    return PublishRequest._decode(json);
  }

  static PublishRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PublishRequest(
      courseId: map['courseId'] as String,
      versionId: map['versionId'] as String,
      manifestFileId: map['manifestFileId'] as String,
      manifestSha256: map['manifestSha256'] as String,
      expectedPublishedVersion: map['expectedPublishedVersion'] == null ? null : map['expectedPublishedVersion'] as String,
    );
  }

  final String courseId;
  final String versionId;
  final String manifestFileId;
  final String manifestSha256;
  final String? expectedPublishedVersion;

  Map<String, Object?> toJson() => <String, Object?>{
        'courseId': courseId,
        'versionId': versionId,
        'manifestFileId': manifestFileId,
        'manifestSha256': manifestSha256,
        'expectedPublishedVersion': expectedPublishedVersion,
      };
}

/// Wire DTO for `#/components/schemas/Profile`.
final class Profile {
  const Profile({
    required this.userId,
    required this.nickname,
    required this.avatarId,
    required this.publicOptIn,
    required this.dailyGoal,
    required this.learningZone,
    required this.pendingZone,
    required this.zoneEffectiveAt,
    required this.revision,
    required this.achievementIds,
  });

  /// Validates [json] against the `Profile` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Profile.fromJson(Object? json) {
    ContractValidator.instance.check('Profile', json);
    return Profile._decode(json);
  }

  static Profile _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Profile(
      userId: map['userId'] as String,
      nickname: map['nickname'] as String,
      avatarId: map['avatarId'] == null ? null : map['avatarId'] as String,
      publicOptIn: map['publicOptIn'] as bool,
      dailyGoal: (map['dailyGoal'] as num).toInt(),
      learningZone: map['learningZone'] as String,
      pendingZone: map['pendingZone'] == null ? null : map['pendingZone'] as String,
      zoneEffectiveAt: map['zoneEffectiveAt'] == null ? null : map['zoneEffectiveAt'] as String,
      revision: (map['revision'] as num).toInt(),
      achievementIds: List<String>.unmodifiable((map['achievementIds'] as List<Object?>).map((Object? x) => x as String)),
    );
  }

  final String userId;
  final String nickname;
  final String? avatarId;
  final bool publicOptIn;
  final int dailyGoal;
  final String learningZone;
  final String? pendingZone;
  final String? zoneEffectiveAt;
  final int revision;
  final List<String> achievementIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'nickname': nickname,
        'avatarId': avatarId,
        'publicOptIn': publicOptIn,
        'dailyGoal': dailyGoal,
        'learningZone': learningZone,
        'pendingZone': pendingZone,
        'zoneEffectiveAt': zoneEffectiveAt,
        'revision': revision,
        'achievementIds': List<Object?>.of(achievementIds),
      };
}

/// Wire DTO for `#/components/schemas/ProfilePatch`.
final class ProfilePatch {
  const ProfilePatch({
    this.nickname,
    this.avatarId = const JsonPresence<String>.absent(),
    this.publicOptIn,
    this.dailyGoal,
    this.learningZone,
    required this.expectedRevision,
  });

  /// Validates [json] against the `ProfilePatch` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ProfilePatch.fromJson(Object? json) {
    ContractValidator.instance.check('ProfilePatch', json);
    return ProfilePatch._decode(json);
  }

  static ProfilePatch _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ProfilePatch(
      nickname: map.containsKey('nickname') ? map['nickname'] as String : null,
      avatarId: map.containsKey('avatarId') ? JsonPresence<String>.value(map['avatarId'] == null ? null : map['avatarId'] as String) : const JsonPresence<String>.absent(),
      publicOptIn: map.containsKey('publicOptIn') ? map['publicOptIn'] as bool : null,
      dailyGoal: map.containsKey('dailyGoal') ? (map['dailyGoal'] as num).toInt() : null,
      learningZone: map.containsKey('learningZone') ? map['learningZone'] as String : null,
      expectedRevision: (map['expectedRevision'] as num).toInt(),
    );
  }

  final String? nickname;
  final JsonPresence<String> avatarId;
  final bool? publicOptIn;
  final int? dailyGoal;
  final String? learningZone;
  final int expectedRevision;

  Map<String, Object?> toJson() => <String, Object?>{
        'nickname': ?nickname,
        if (avatarId.isPresent) 'avatarId': avatarId.value,
        'publicOptIn': ?publicOptIn,
        'dailyGoal': ?dailyGoal,
        'learningZone': ?learningZone,
        'expectedRevision': expectedRevision,
      };
}

/// Wire DTO for `#/components/schemas/PublicProfile`.
final class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.nickname,
    required this.avatarId,
    required this.studyXp,
    required this.streak,
    required this.achievementIds,
    required this.followStatus,
  });

  /// Validates [json] against the `PublicProfile` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory PublicProfile.fromJson(Object? json) {
    ContractValidator.instance.check('PublicProfile', json);
    return PublicProfile._decode(json);
  }

  static PublicProfile _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PublicProfile(
      userId: map['userId'] as String,
      nickname: map['nickname'] as String,
      avatarId: map['avatarId'] == null ? null : map['avatarId'] as String,
      studyXp: (map['studyXp'] as num).toInt(),
      streak: (map['streak'] as num).toInt(),
      achievementIds: List<String>.unmodifiable((map['achievementIds'] as List<Object?>).map((Object? x) => x as String)),
      followStatus: map['followStatus'] as String,
    );
  }

  final String userId;
  final String nickname;
  final String? avatarId;
  final int studyXp;
  final int streak;
  final List<String> achievementIds;
  final String followStatus;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'nickname': nickname,
        'avatarId': avatarId,
        'studyXp': studyXp,
        'streak': streak,
        'achievementIds': List<Object?>.of(achievementIds),
        'followStatus': followStatus,
      };
}

/// Wire DTO for `#/components/schemas/Rewards`.
final class Rewards {
  const Rewards({
    required this.completionId,
    required this.status,
    required this.studyXp,
    required this.leagueXp,
    required this.gems,
    required this.freezeSlots,
    required this.currentStreak,
    required this.awardXp,
    required this.revision,
    required this.asOf,
  });

  /// Validates [json] against the `Rewards` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Rewards.fromJson(Object? json) {
    ContractValidator.instance.check('Rewards', json);
    return Rewards._decode(json);
  }

  static Rewards _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Rewards(
      completionId: map['completionId'] == null ? null : map['completionId'] as String,
      status: map['status'] as String,
      studyXp: (map['studyXp'] as num).toInt(),
      leagueXp: (map['leagueXp'] as num).toInt(),
      gems: (map['gems'] as num).toInt(),
      freezeSlots: (map['freezeSlots'] as num).toInt(),
      currentStreak: (map['currentStreak'] as num).toInt(),
      awardXp: map['awardXp'] == null ? null : (map['awardXp'] as num).toInt(),
      revision: (map['revision'] as num).toInt(),
      asOf: map['asOf'] as String,
    );
  }

  final String? completionId;
  final String status;
  final int studyXp;
  final int leagueXp;
  final int gems;
  final int freezeSlots;
  final int currentStreak;
  final int? awardXp;
  final int revision;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'completionId': completionId,
        'status': status,
        'studyXp': studyXp,
        'leagueXp': leagueXp,
        'gems': gems,
        'freezeSlots': freezeSlots,
        'currentStreak': currentStreak,
        'awardXp': awardXp,
        'revision': revision,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/Quest`.
final class Quest {
  const Quest({
    required this.questId,
    required this.period,
    required this.periodKey,
    required this.target,
    required this.metricValue,
    required this.claimed,
    required this.rewardGems,
  });

  /// Validates [json] against the `Quest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Quest.fromJson(Object? json) {
    ContractValidator.instance.check('Quest', json);
    return Quest._decode(json);
  }

  static Quest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Quest(
      questId: map['questId'] as String,
      period: map['period'] as String,
      periodKey: map['periodKey'] as String,
      target: (map['target'] as num).toInt(),
      metricValue: (map['metricValue'] as num).toInt(),
      claimed: map['claimed'] as bool,
      rewardGems: (map['rewardGems'] as num).toInt(),
    );
  }

  final String questId;
  final String period;
  final String periodKey;
  final int target;
  final int metricValue;
  final bool claimed;
  final int rewardGems;

  Map<String, Object?> toJson() => <String, Object?>{
        'questId': questId,
        'period': period,
        'periodKey': periodKey,
        'target': target,
        'metricValue': metricValue,
        'claimed': claimed,
        'rewardGems': rewardGems,
      };
}

/// Wire DTO for `#/components/schemas/QuestClaimRequest`.
final class QuestClaimRequest {
  const QuestClaimRequest({
    required this.periodKey,
  });

  /// Validates [json] against the `QuestClaimRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory QuestClaimRequest.fromJson(Object? json) {
    ContractValidator.instance.check('QuestClaimRequest', json);
    return QuestClaimRequest._decode(json);
  }

  static QuestClaimRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return QuestClaimRequest(
      periodKey: map['periodKey'] as String,
    );
  }

  final String periodKey;

  Map<String, Object?> toJson() => <String, Object?>{
        'periodKey': periodKey,
      };
}

/// Wire DTO for `#/components/schemas/FollowRequest`.
final class FollowRequest {
  const FollowRequest({
    required this.targetUserId,
  });

  /// Validates [json] against the `FollowRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FollowRequest.fromJson(Object? json) {
    ContractValidator.instance.check('FollowRequest', json);
    return FollowRequest._decode(json);
  }

  static FollowRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FollowRequest(
      targetUserId: map['targetUserId'] as String,
    );
  }

  final String targetUserId;

  Map<String, Object?> toJson() => <String, Object?>{
        'targetUserId': targetUserId,
      };
}

/// Wire DTO for `#/components/schemas/LeagueMember`.
final class LeagueMember {
  const LeagueMember({
    required this.userId,
    required this.nickname,
    required this.eligibleXp,
    required this.rank,
    required this.lastXpAt,
  });

  /// Validates [json] against the `LeagueMember` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory LeagueMember.fromJson(Object? json) {
    ContractValidator.instance.check('LeagueMember', json);
    return LeagueMember._decode(json);
  }

  static LeagueMember _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return LeagueMember(
      userId: map['userId'] as String,
      nickname: map['nickname'] as String,
      eligibleXp: (map['eligibleXp'] as num).toInt(),
      rank: (map['rank'] as num).toInt(),
      lastXpAt: map['lastXpAt'] == null ? null : map['lastXpAt'] as String,
    );
  }

  final String userId;
  final String nickname;
  final int eligibleXp;
  final int rank;
  final String? lastXpAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'nickname': nickname,
        'eligibleXp': eligibleXp,
        'rank': rank,
        'lastXpAt': lastXpAt,
      };
}

/// Wire DTO for `#/components/schemas/League`.
final class League {
  const League({
    required this.weekId,
    required this.cohortId,
    required this.tier,
    required this.status,
    required this.members,
    required this.asOf,
    required this.nextCursor,
  });

  /// Validates [json] against the `League` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory League.fromJson(Object? json) {
    ContractValidator.instance.check('League', json);
    return League._decode(json);
  }

  static League _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return League(
      weekId: map['weekId'] as String,
      cohortId: map['cohortId'] as String,
      tier: (map['tier'] as num).toInt(),
      status: map['status'] as String,
      members: List<LeagueMember>.unmodifiable((map['members'] as List<Object?>).map((Object? x) => LeagueMember._decode(x))),
      asOf: map['asOf'] as String,
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
    );
  }

  final String weekId;
  final String cohortId;
  final int tier;
  final String status;
  final List<LeagueMember> members;
  final String asOf;
  final String? nextCursor;

  Map<String, Object?> toJson() => <String, Object?>{
        'weekId': weekId,
        'cohortId': cohortId,
        'tier': tier,
        'status': status,
        'members': members.map((LeagueMember x) => x.toJson()).toList(),
        'asOf': asOf,
        'nextCursor': nextCursor,
      };
}

/// Wire DTO for `#/components/schemas/Activity`.
final class Activity {
  const Activity({
    required this.eventId,
    required this.userId,
    required this.kind,
    required this.summary,
    required this.createdAt,
  });

  /// Validates [json] against the `Activity` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Activity.fromJson(Object? json) {
    ContractValidator.instance.check('Activity', json);
    return Activity._decode(json);
  }

  static Activity _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Activity(
      eventId: map['eventId'] as String,
      userId: map['userId'] as String,
      kind: map['kind'] as String,
      summary: map['summary'] as String,
      createdAt: map['createdAt'] as String,
    );
  }

  final String eventId;
  final String userId;
  final String kind;
  final String summary;
  final String createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'userId': userId,
        'kind': kind,
        'summary': summary,
        'createdAt': createdAt,
      };
}

/// Wire DTO for `#/components/schemas/DeletionReceipt`.
final class DeletionReceipt {
  const DeletionReceipt({
    required this.requestId,
    required this.status,
    required this.requestedAt,
  });

  /// Validates [json] against the `DeletionReceipt` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory DeletionReceipt.fromJson(Object? json) {
    ContractValidator.instance.check('DeletionReceipt', json);
    return DeletionReceipt._decode(json);
  }

  static DeletionReceipt _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return DeletionReceipt(
      requestId: map['requestId'] as String,
      status: map['status'] as String,
      requestedAt: map['requestedAt'] as String,
    );
  }

  final String requestId;
  final String status;
  final String requestedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'requestId': requestId,
        'status': status,
        'requestedAt': requestedAt,
      };
}

/// Wire DTO for `#/components/schemas/DeletionRequest`.
final class DeletionRequest {
  const DeletionRequest();

  /// Validates [json] against the `DeletionRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory DeletionRequest.fromJson(Object? json) {
    ContractValidator.instance.check('DeletionRequest', json);
    return DeletionRequest._decode(json);
  }

  static DeletionRequest _decode(Object? json) {
    json as Map<Object?, Object?>;
    return const DeletionRequest();
  }

  String get confirmation => 'DELETE';

  Map<String, Object?> toJson() => <String, Object?>{
        'confirmation': confirmation,
      };
}

/// Wire DTO for `#/components/schemas/Capabilities`.
final class Capabilities {
  const Capabilities({
    required this.configVersion,
    required this.textTutor,
    required this.nativeLive,
    required this.turnSpeech,
    required this.pronunciation,
    required this.nativeLiveReason,
    required this.pronunciationReason,
    required this.liveUiMaxSeconds,
    required this.dailyLiveSessionLimit,
  });

  /// Validates [json] against the `Capabilities` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Capabilities.fromJson(Object? json) {
    ContractValidator.instance.check('Capabilities', json);
    return Capabilities._decode(json);
  }

  static Capabilities _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Capabilities(
      configVersion: map['configVersion'] as String,
      textTutor: map['textTutor'] as bool,
      nativeLive: map['nativeLive'] as bool,
      turnSpeech: map['turnSpeech'] as bool,
      pronunciation: map['pronunciation'] as bool,
      nativeLiveReason: map['nativeLiveReason'] == null ? null : map['nativeLiveReason'] as String,
      pronunciationReason: map['pronunciationReason'] == null ? null : map['pronunciationReason'] as String,
      liveUiMaxSeconds: (map['liveUiMaxSeconds'] as num).toInt(),
      dailyLiveSessionLimit: (map['dailyLiveSessionLimit'] as num).toInt(),
    );
  }

  final String configVersion;
  final bool textTutor;
  final bool nativeLive;
  final bool turnSpeech;
  final bool pronunciation;
  bool get offlineShadowing => true;
  final String? nativeLiveReason;
  final String? pronunciationReason;
  final int liveUiMaxSeconds;
  final int dailyLiveSessionLimit;

  Map<String, Object?> toJson() => <String, Object?>{
        'configVersion': configVersion,
        'textTutor': textTutor,
        'nativeLive': nativeLive,
        'turnSpeech': turnSpeech,
        'pronunciation': pronunciation,
        'offlineShadowing': offlineShadowing,
        'nativeLiveReason': nativeLiveReason,
        'pronunciationReason': pronunciationReason,
        'liveUiMaxSeconds': liveUiMaxSeconds,
        'dailyLiveSessionLimit': dailyLiveSessionLimit,
      };
}

/// Wire DTO for `#/components/schemas/TutorRequest`.
final class TutorRequest {
  const TutorRequest({
    required this.requestId,
    this.exerciseId = const JsonPresence<String>.absent(),
    this.lessonVersion = const JsonPresence<String>.absent(),
    this.scenarioId = const JsonPresence<String>.absent(),
    required this.learnerText,
    required this.level,
    required this.locale,
    required this.feedbackLocale,
  });

  /// Validates [json] against the `TutorRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TutorRequest.fromJson(Object? json) {
    ContractValidator.instance.check('TutorRequest', json);
    return TutorRequest._decode(json);
  }

  static TutorRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TutorRequest(
      requestId: map['requestId'] as String,
      exerciseId: map.containsKey('exerciseId') ? JsonPresence<String>.value(map['exerciseId'] == null ? null : map['exerciseId'] as String) : const JsonPresence<String>.absent(),
      lessonVersion: map.containsKey('lessonVersion') ? JsonPresence<String>.value(map['lessonVersion'] == null ? null : map['lessonVersion'] as String) : const JsonPresence<String>.absent(),
      scenarioId: map.containsKey('scenarioId') ? JsonPresence<String>.value(map['scenarioId'] == null ? null : map['scenarioId'] as String) : const JsonPresence<String>.absent(),
      learnerText: map['learnerText'] as String,
      level: map['level'] as String,
      locale: map['locale'] as String,
      feedbackLocale: map['feedbackLocale'] as String,
    );
  }

  final String requestId;
  final JsonPresence<String> exerciseId;
  final JsonPresence<String> lessonVersion;
  final JsonPresence<String> scenarioId;
  final String learnerText;
  final String level;
  final String locale;
  final String feedbackLocale;

  Map<String, Object?> toJson() => <String, Object?>{
        'requestId': requestId,
        if (exerciseId.isPresent) 'exerciseId': exerciseId.value,
        if (lessonVersion.isPresent) 'lessonVersion': lessonVersion.value,
        if (scenarioId.isPresent) 'scenarioId': scenarioId.value,
        'learnerText': learnerText,
        'level': level,
        'locale': locale,
        'feedbackLocale': feedbackLocale,
      };
}

/// Wire DTO for `#/components/schemas/TutorResult`.
final class TutorResult {
  const TutorResult({
    required this.requestId,
    required this.tutorText,
    required this.correction,
    required this.explanation,
    required this.source,
  });

  /// Validates [json] against the `TutorResult` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TutorResult.fromJson(Object? json) {
    ContractValidator.instance.check('TutorResult', json);
    return TutorResult._decode(json);
  }

  static TutorResult _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TutorResult(
      requestId: map['requestId'] as String,
      tutorText: map['tutorText'] as String,
      correction: map['correction'] == null ? null : map['correction'] as String,
      explanation: map['explanation'] as String,
      source: map['source'] as String,
    );
  }

  final String requestId;
  final String tutorText;
  final String? correction;
  final String explanation;
  final String source;
  bool get assessedPronunciation => false;

  Map<String, Object?> toJson() => <String, Object?>{
        'requestId': requestId,
        'tutorText': tutorText,
        'correction': correction,
        'explanation': explanation,
        'source': source,
        'assessedPronunciation': assessedPronunciation,
      };
}

/// Wire DTO for `#/components/schemas/VoiceRequest`.
final class VoiceRequest {
  const VoiceRequest({
    required this.sessionId,
    required this.scenarioId,
    required this.mode,
    required this.level,
  });

  /// Validates [json] against the `VoiceRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory VoiceRequest.fromJson(Object? json) {
    ContractValidator.instance.check('VoiceRequest', json);
    return VoiceRequest._decode(json);
  }

  static VoiceRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return VoiceRequest(
      sessionId: map['sessionId'] as String,
      scenarioId: map['scenarioId'] as String,
      mode: map['mode'] as String,
      level: map['level'] as String,
    );
  }

  final String sessionId;
  final String scenarioId;
  final String mode;
  final String level;

  Map<String, Object?> toJson() => <String, Object?>{
        'sessionId': sessionId,
        'scenarioId': scenarioId,
        'mode': mode,
        'level': level,
      };
}

/// Wire union for `#/components/schemas/VoiceLease` (oneOf, discriminated by `mode`).
sealed class VoiceLease {
  /// Validates [json] against the `VoiceLease` schema (exactly one variant), then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory VoiceLease.fromJson(Object? json) {
    ContractValidator.instance.check('VoiceLease', json);
    return VoiceLease._decode(json);
  }

  static VoiceLease _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return switch (map['mode']) {
      'LIVE' => LiveVoiceLease._decode(map),
      'TURN' => TurnVoiceLease._decode(map),
      _ => throw StateError('Unknown VoiceLease.mode after validation'),
    };
  }

  /// Discriminator value of this variant.
  String get mode;

  Map<String, Object?> toJson();
}

/// Wire DTO for `#/components/schemas/LiveVoiceLease`.
final class LiveVoiceLease implements VoiceLease {
  const LiveVoiceLease({
    required this.sessionId,
    required this.providerAlias,
    required this.model,
    required this.ephemeralToken,
    required this.connectExpiresAt,
    required this.sessionExpiresAt,
    required this.epoch,
    required this.configVersion,
  });

  /// Validates [json] against the `LiveVoiceLease` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory LiveVoiceLease.fromJson(Object? json) {
    ContractValidator.instance.check('LiveVoiceLease', json);
    return LiveVoiceLease._decode(json);
  }

  static LiveVoiceLease _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return LiveVoiceLease(
      sessionId: map['sessionId'] as String,
      providerAlias: map['providerAlias'] as String,
      model: map['model'] as String,
      ephemeralToken: map['ephemeralToken'] as String,
      connectExpiresAt: map['connectExpiresAt'] as String,
      sessionExpiresAt: map['sessionExpiresAt'] as String,
      epoch: (map['epoch'] as num).toInt(),
      configVersion: map['configVersion'] as String,
    );
  }

  final String sessionId;
  @override
  String get mode => 'LIVE';
  final String providerAlias;
  final String model;
  final String ephemeralToken;
  final String connectExpiresAt;
  final String sessionExpiresAt;
  final int epoch;
  int get inputSampleRate => 16000;
  int get outputSampleRate => 24000;
  final String configVersion;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'sessionId': sessionId,
        'mode': mode,
        'providerAlias': providerAlias,
        'model': model,
        'ephemeralToken': ephemeralToken,
        'connectExpiresAt': connectExpiresAt,
        'sessionExpiresAt': sessionExpiresAt,
        'epoch': epoch,
        'inputSampleRate': inputSampleRate,
        'outputSampleRate': outputSampleRate,
        'configVersion': configVersion,
      };
}

/// Wire DTO for `#/components/schemas/TurnVoiceLease`.
final class TurnVoiceLease implements VoiceLease {
  const TurnVoiceLease({
    required this.sessionId,
    required this.providerAlias,
    required this.model,
    required this.ephemeralToken,
    required this.connectExpiresAt,
    required this.sessionExpiresAt,
    required this.epoch,
    required this.configVersion,
  });

  /// Validates [json] against the `TurnVoiceLease` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TurnVoiceLease.fromJson(Object? json) {
    ContractValidator.instance.check('TurnVoiceLease', json);
    return TurnVoiceLease._decode(json);
  }

  static TurnVoiceLease _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TurnVoiceLease(
      sessionId: map['sessionId'] as String,
      providerAlias: map['providerAlias'] as String,
      model: map['model'] as String,
      ephemeralToken: map['ephemeralToken'],
      connectExpiresAt: map['connectExpiresAt'],
      sessionExpiresAt: map['sessionExpiresAt'] as String,
      epoch: (map['epoch'] as num).toInt(),
      configVersion: map['configVersion'] as String,
    );
  }

  final String sessionId;
  @override
  String get mode => 'TURN';
  final String providerAlias;
  final String model;
  final Object? ephemeralToken;
  final Object? connectExpiresAt;
  final String sessionExpiresAt;
  final int epoch;
  int get inputSampleRate => 16000;
  int get outputSampleRate => 24000;
  final String configVersion;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'sessionId': sessionId,
        'mode': mode,
        'providerAlias': providerAlias,
        'model': model,
        'ephemeralToken': ephemeralToken,
        'connectExpiresAt': connectExpiresAt,
        'sessionExpiresAt': sessionExpiresAt,
        'epoch': epoch,
        'inputSampleRate': inputSampleRate,
        'outputSampleRate': outputSampleRate,
        'configVersion': configVersion,
      };
}

/// Wire DTO for `#/components/schemas/VoiceHeartbeat`.
final class VoiceHeartbeat {
  const VoiceHeartbeat({
    required this.epoch,
    required this.elapsedSeconds,
    required this.turnCount,
  });

  /// Validates [json] against the `VoiceHeartbeat` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory VoiceHeartbeat.fromJson(Object? json) {
    ContractValidator.instance.check('VoiceHeartbeat', json);
    return VoiceHeartbeat._decode(json);
  }

  static VoiceHeartbeat _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return VoiceHeartbeat(
      epoch: (map['epoch'] as num).toInt(),
      elapsedSeconds: (map['elapsedSeconds'] as num).toInt(),
      turnCount: (map['turnCount'] as num).toInt(),
    );
  }

  final int epoch;
  final int elapsedSeconds;
  final int turnCount;

  Map<String, Object?> toJson() => <String, Object?>{
        'epoch': epoch,
        'elapsedSeconds': elapsedSeconds,
        'turnCount': turnCount,
      };
}

/// Wire DTO for `#/components/schemas/VoiceState`.
final class VoiceState {
  const VoiceState({
    required this.sessionId,
    required this.status,
    required this.epoch,
    required this.accountedSeconds,
  });

  /// Validates [json] against the `VoiceState` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory VoiceState.fromJson(Object? json) {
    ContractValidator.instance.check('VoiceState', json);
    return VoiceState._decode(json);
  }

  static VoiceState _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return VoiceState(
      sessionId: map['sessionId'] as String,
      status: map['status'] as String,
      epoch: (map['epoch'] as num).toInt(),
      accountedSeconds: (map['accountedSeconds'] as num).toInt(),
    );
  }

  final String sessionId;
  final String status;
  final int epoch;
  final int accountedSeconds;

  Map<String, Object?> toJson() => <String, Object?>{
        'sessionId': sessionId,
        'status': status,
        'epoch': epoch,
        'accountedSeconds': accountedSeconds,
      };
}

/// Wire DTO for `#/components/schemas/AssessmentRequest`.
final class AssessmentRequest {
  const AssessmentRequest({
    required this.jobId,
    required this.referenceExerciseId,
    required this.lessonVersion,
    required this.locale,
    required this.wavBase64,
    required this.audioSha256,
  });

  /// Validates [json] against the `AssessmentRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory AssessmentRequest.fromJson(Object? json) {
    ContractValidator.instance.check('AssessmentRequest', json);
    return AssessmentRequest._decode(json);
  }

  static AssessmentRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return AssessmentRequest(
      jobId: map['jobId'] as String,
      referenceExerciseId: map['referenceExerciseId'] as String,
      lessonVersion: map['lessonVersion'] as String,
      locale: map['locale'] as String,
      wavBase64: map['wavBase64'] as String,
      audioSha256: map['audioSha256'] as String,
    );
  }

  final String jobId;
  final String referenceExerciseId;
  final String lessonVersion;
  final String locale;
  final String wavBase64;
  final String audioSha256;

  Map<String, Object?> toJson() => <String, Object?>{
        'jobId': jobId,
        'referenceExerciseId': referenceExerciseId,
        'lessonVersion': lessonVersion,
        'locale': locale,
        'wavBase64': wavBase64,
        'audioSha256': audioSha256,
      };
}

/// Wire DTO for `#/components/schemas/WordScore`.
final class WordScore {
  const WordScore({
    required this.word,
    required this.accuracy,
    required this.errorType,
    required this.phonemes,
  });

  /// Validates [json] against the `WordScore` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory WordScore.fromJson(Object? json) {
    ContractValidator.instance.check('WordScore', json);
    return WordScore._decode(json);
  }

  static WordScore _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return WordScore(
      word: map['word'] as String,
      accuracy: map['accuracy'] == null ? null : map['accuracy'] as num,
      errorType: map['errorType'] == null ? null : map['errorType'] as String,
      phonemes: List<WordScorePhonemesItem>.unmodifiable((map['phonemes'] as List<Object?>).map((Object? x) => WordScorePhonemesItem._decode(x))),
    );
  }

  final String word;
  final num? accuracy;
  final String? errorType;
  final List<WordScorePhonemesItem> phonemes;

  Map<String, Object?> toJson() => <String, Object?>{
        'word': word,
        'accuracy': accuracy,
        'errorType': errorType,
        'phonemes': phonemes.map((WordScorePhonemesItem x) => x.toJson()).toList(),
      };
}

/// Inline wire object `WordScorePhonemesItem` (nested in a component schema).
final class WordScorePhonemesItem {
  const WordScorePhonemesItem({
    required this.phoneme,
    required this.accuracy,
  });

  static WordScorePhonemesItem _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return WordScorePhonemesItem(
      phoneme: map['phoneme'] as String,
      accuracy: map['accuracy'] == null ? null : map['accuracy'] as num,
    );
  }

  final String phoneme;
  final num? accuracy;

  Map<String, Object?> toJson() => <String, Object?>{
        'phoneme': phoneme,
        'accuracy': accuracy,
      };
}

/// Wire DTO for `#/components/schemas/Assessment`.
final class Assessment {
  const Assessment({
    required this.jobId,
    required this.status,
    required this.transcript,
    required this.accuracy,
    required this.fluency,
    required this.completeness,
    required this.prosody,
    required this.words,
    required this.scorer,
    required this.scoreVersion,
    required this.unavailableReason,
    required this.expiresAt,
    required this.scoreState,
    required this.locale,
    required this.referenceHash,
    required this.provider,
    required this.modelVersion,
    required this.miscues,
  });

  /// Validates [json] against the `Assessment` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Assessment.fromJson(Object? json) {
    ContractValidator.instance.check('Assessment', json);
    return Assessment._decode(json);
  }

  static Assessment _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Assessment(
      jobId: map['jobId'] as String,
      status: map['status'] as String,
      transcript: map['transcript'] == null ? null : map['transcript'] as String,
      accuracy: map['accuracy'] == null ? null : map['accuracy'] as num,
      fluency: map['fluency'] == null ? null : map['fluency'] as num,
      completeness: map['completeness'] == null ? null : map['completeness'] as num,
      prosody: map['prosody'] == null ? null : map['prosody'] as num,
      words: List<WordScore>.unmodifiable((map['words'] as List<Object?>).map((Object? x) => WordScore._decode(x))),
      scorer: map['scorer'] == null ? null : map['scorer'] as String,
      scoreVersion: map['scoreVersion'] == null ? null : map['scoreVersion'] as String,
      unavailableReason: map['unavailableReason'] == null ? null : map['unavailableReason'] as String,
      expiresAt: map['expiresAt'] as String,
      scoreState: map['scoreState'] as String,
      locale: map['locale'] as String,
      referenceHash: map['referenceHash'] as String,
      provider: map['provider'] == null ? null : map['provider'] as String,
      modelVersion: map['modelVersion'] == null ? null : map['modelVersion'] as String,
      miscues: List<AssessmentMiscuesItem>.unmodifiable((map['miscues'] as List<Object?>).map((Object? x) => AssessmentMiscuesItem._decode(x))),
    );
  }

  final String jobId;
  final String status;
  final String? transcript;
  final num? accuracy;
  final num? fluency;
  final num? completeness;
  final num? prosody;
  final List<WordScore> words;
  final String? scorer;
  final String? scoreVersion;
  final String? unavailableReason;
  final String expiresAt;
  final String scoreState;
  final String locale;
  final String referenceHash;
  final String? provider;
  final String? modelVersion;
  final List<AssessmentMiscuesItem> miscues;

  Map<String, Object?> toJson() => <String, Object?>{
        'jobId': jobId,
        'status': status,
        'transcript': transcript,
        'accuracy': accuracy,
        'fluency': fluency,
        'completeness': completeness,
        'prosody': prosody,
        'words': words.map((WordScore x) => x.toJson()).toList(),
        'scorer': scorer,
        'scoreVersion': scoreVersion,
        'unavailableReason': unavailableReason,
        'expiresAt': expiresAt,
        'scoreState': scoreState,
        'locale': locale,
        'referenceHash': referenceHash,
        'provider': provider,
        'modelVersion': modelVersion,
        'miscues': miscues.map((AssessmentMiscuesItem x) => x.toJson()).toList(),
      };
}

/// Inline wire object `AssessmentMiscuesItem` (nested in a component schema).
final class AssessmentMiscuesItem {
  const AssessmentMiscuesItem({
    required this.word,
    required this.kind,
  });

  static AssessmentMiscuesItem _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return AssessmentMiscuesItem(
      word: map['word'] as String,
      kind: map['kind'] as String,
    );
  }

  final String word;
  final String kind;

  Map<String, Object?> toJson() => <String, Object?>{
        'word': word,
        'kind': kind,
      };
}

/// Wire DTO for `#/components/schemas/LessonEventPayload`.
final class LessonEventPayload {
  const LessonEventPayload({
    required this.completionId,
    required this.userId,
    required this.courseId,
    required this.lessonVersion,
    required this.rewardIdentity,
    required this.source,
    required this.mode,
    required this.originalCount,
    required this.originalCorrect,
    required this.assisted,
  });

  /// Validates [json] against the `LessonEventPayload` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory LessonEventPayload.fromJson(Object? json) {
    ContractValidator.instance.check('LessonEventPayload', json);
    return LessonEventPayload._decode(json);
  }

  static LessonEventPayload _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return LessonEventPayload(
      completionId: map['completionId'] as String,
      userId: map['userId'] as String,
      courseId: map['courseId'] as String,
      lessonVersion: map['lessonVersion'] as String,
      rewardIdentity: map['rewardIdentity'] as String,
      source: map['source'] as String,
      mode: map['mode'] as String,
      originalCount: (map['originalCount'] as num).toInt(),
      originalCorrect: (map['originalCorrect'] as num).toInt(),
      assisted: map['assisted'] as bool,
    );
  }

  final String completionId;
  final String userId;
  final String courseId;
  final String lessonVersion;
  final String rewardIdentity;
  final String source;
  final String mode;
  final int originalCount;
  final int originalCorrect;
  final bool assisted;

  Map<String, Object?> toJson() => <String, Object?>{
        'completionId': completionId,
        'userId': userId,
        'courseId': courseId,
        'lessonVersion': lessonVersion,
        'rewardIdentity': rewardIdentity,
        'source': source,
        'mode': mode,
        'originalCount': originalCount,
        'originalCorrect': originalCorrect,
        'assisted': assisted,
      };
}

/// Wire DTO for `#/components/schemas/DeletionEventPayload`.
final class DeletionEventPayload {
  const DeletionEventPayload({
    required this.userId,
    required this.requestId,
  });

  /// Validates [json] against the `DeletionEventPayload` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory DeletionEventPayload.fromJson(Object? json) {
    ContractValidator.instance.check('DeletionEventPayload', json);
    return DeletionEventPayload._decode(json);
  }

  static DeletionEventPayload _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return DeletionEventPayload(
      userId: map['userId'] as String,
      requestId: map['requestId'] as String,
    );
  }

  final String userId;
  final String requestId;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'requestId': requestId,
      };
}

/// Wire DTO for `#/components/schemas/PurgeEventPayload`.
final class PurgeEventPayload {
  const PurgeEventPayload({
    required this.userId,
    required this.requestId,
    required this.owner,
  });

  /// Validates [json] against the `PurgeEventPayload` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory PurgeEventPayload.fromJson(Object? json) {
    ContractValidator.instance.check('PurgeEventPayload', json);
    return PurgeEventPayload._decode(json);
  }

  static PurgeEventPayload _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PurgeEventPayload(
      userId: map['userId'] as String,
      requestId: map['requestId'] as String,
      owner: map['owner'] as String,
    );
  }

  final String userId;
  final String requestId;
  final String owner;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'requestId': requestId,
        'owner': owner,
      };
}

/// Wire DTO for `#/components/schemas/ZoneEventPayload`.
final class ZoneEventPayload {
  const ZoneEventPayload({
    required this.userId,
    required this.zone,
    required this.effectiveAt,
  });

  /// Validates [json] against the `ZoneEventPayload` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ZoneEventPayload.fromJson(Object? json) {
    ContractValidator.instance.check('ZoneEventPayload', json);
    return ZoneEventPayload._decode(json);
  }

  static ZoneEventPayload _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ZoneEventPayload(
      userId: map['userId'] as String,
      zone: map['zone'] as String,
      effectiveAt: map['effectiveAt'] as String,
    );
  }

  final String userId;
  final String zone;
  final String effectiveAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'zone': zone,
        'effectiveAt': effectiveAt,
      };
}

/// Inline wire object `BusinessEventLessonCompletedV1` (nested in a component schema).
final class BusinessEventLessonCompletedV1 implements BusinessEvent {
  const BusinessEventLessonCompletedV1({
    required this.eventId,
    required this.aggregateId,
    required this.occurredAt,
    required this.requestId,
    required this.payload,
  });

  static BusinessEventLessonCompletedV1 _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BusinessEventLessonCompletedV1(
      eventId: map['eventId'] as String,
      aggregateId: map['aggregateId'] as String,
      occurredAt: map['occurredAt'] as String,
      requestId: map['requestId'] as String,
      payload: LessonEventPayload._decode(map['payload']),
    );
  }

  final String eventId;
  @override
  String get type => 'lesson.completed.v1';
  int get schemaVersion => 1;
  String get producer => 'learning';
  final String aggregateId;
  final String occurredAt;
  final String requestId;
  final LessonEventPayload payload;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'type': type,
        'schemaVersion': schemaVersion,
        'producer': producer,
        'aggregateId': aggregateId,
        'occurredAt': occurredAt,
        'requestId': requestId,
        'payload': payload.toJson(),
      };
}

/// Inline wire object `BusinessEventAccountDeletedV1` (nested in a component schema).
final class BusinessEventAccountDeletedV1 implements BusinessEvent {
  const BusinessEventAccountDeletedV1({
    required this.eventId,
    required this.aggregateId,
    required this.occurredAt,
    required this.requestId,
    required this.payload,
  });

  static BusinessEventAccountDeletedV1 _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BusinessEventAccountDeletedV1(
      eventId: map['eventId'] as String,
      aggregateId: map['aggregateId'] as String,
      occurredAt: map['occurredAt'] as String,
      requestId: map['requestId'] as String,
      payload: DeletionEventPayload._decode(map['payload']),
    );
  }

  final String eventId;
  @override
  String get type => 'account.deleted.v1';
  int get schemaVersion => 1;
  String get producer => 'progress';
  final String aggregateId;
  final String occurredAt;
  final String requestId;
  final DeletionEventPayload payload;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'type': type,
        'schemaVersion': schemaVersion,
        'producer': producer,
        'aggregateId': aggregateId,
        'occurredAt': occurredAt,
        'requestId': requestId,
        'payload': payload.toJson(),
      };
}

/// Inline wire object `BusinessEventAccountPurgedV1` (nested in a component schema).
final class BusinessEventAccountPurgedV1 implements BusinessEvent {
  const BusinessEventAccountPurgedV1({
    required this.eventId,
    required this.producer,
    required this.aggregateId,
    required this.occurredAt,
    required this.requestId,
    required this.payload,
  });

  static BusinessEventAccountPurgedV1 _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BusinessEventAccountPurgedV1(
      eventId: map['eventId'] as String,
      producer: map['producer'] as String,
      aggregateId: map['aggregateId'] as String,
      occurredAt: map['occurredAt'] as String,
      requestId: map['requestId'] as String,
      payload: PurgeEventPayload._decode(map['payload']),
    );
  }

  final String eventId;
  @override
  String get type => 'account.purged.v1';
  int get schemaVersion => 1;
  final String producer;
  final String aggregateId;
  final String occurredAt;
  final String requestId;
  final PurgeEventPayload payload;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'type': type,
        'schemaVersion': schemaVersion,
        'producer': producer,
        'aggregateId': aggregateId,
        'occurredAt': occurredAt,
        'requestId': requestId,
        'payload': payload.toJson(),
      };
}

/// Inline wire object `BusinessEventZoneChangedV1` (nested in a component schema).
final class BusinessEventZoneChangedV1 implements BusinessEvent {
  const BusinessEventZoneChangedV1({
    required this.eventId,
    required this.aggregateId,
    required this.occurredAt,
    required this.requestId,
    required this.payload,
  });

  static BusinessEventZoneChangedV1 _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BusinessEventZoneChangedV1(
      eventId: map['eventId'] as String,
      aggregateId: map['aggregateId'] as String,
      occurredAt: map['occurredAt'] as String,
      requestId: map['requestId'] as String,
      payload: ZoneEventPayload._decode(map['payload']),
    );
  }

  final String eventId;
  @override
  String get type => 'zone.changed.v1';
  int get schemaVersion => 1;
  String get producer => 'progress';
  final String aggregateId;
  final String occurredAt;
  final String requestId;
  final ZoneEventPayload payload;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'type': type,
        'schemaVersion': schemaVersion,
        'producer': producer,
        'aggregateId': aggregateId,
        'occurredAt': occurredAt,
        'requestId': requestId,
        'payload': payload.toJson(),
      };
}

/// Inline wire object `BusinessEventAiPracticeCompletedV1` (nested in a component schema).
final class BusinessEventAiPracticeCompletedV1 implements BusinessEvent {
  const BusinessEventAiPracticeCompletedV1({
    required this.eventId,
    required this.aggregateId,
    required this.occurredAt,
    required this.requestId,
    required this.payload,
  });

  static BusinessEventAiPracticeCompletedV1 _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BusinessEventAiPracticeCompletedV1(
      eventId: map['eventId'] as String,
      aggregateId: map['aggregateId'] as String,
      occurredAt: map['occurredAt'] as String,
      requestId: map['requestId'] as String,
      payload: AiPracticeEventPayload._decode(map['payload']),
    );
  }

  final String eventId;
  @override
  String get type => 'ai.practice.completed.v1';
  int get schemaVersion => 1;
  String get producer => 'ai';
  final String aggregateId;
  final String occurredAt;
  final String requestId;
  final AiPracticeEventPayload payload;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'type': type,
        'schemaVersion': schemaVersion,
        'producer': producer,
        'aggregateId': aggregateId,
        'occurredAt': occurredAt,
        'requestId': requestId,
        'payload': payload.toJson(),
      };
}

/// Inline wire object `BusinessEventEntitlementChangedV1` (nested in a component schema).
final class BusinessEventEntitlementChangedV1 implements BusinessEvent {
  const BusinessEventEntitlementChangedV1({
    required this.eventId,
    required this.aggregateId,
    required this.occurredAt,
    required this.requestId,
    required this.payload,
  });

  static BusinessEventEntitlementChangedV1 _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BusinessEventEntitlementChangedV1(
      eventId: map['eventId'] as String,
      aggregateId: map['aggregateId'] as String,
      occurredAt: map['occurredAt'] as String,
      requestId: map['requestId'] as String,
      payload: EntitlementEventPayload._decode(map['payload']),
    );
  }

  final String eventId;
  @override
  String get type => 'entitlement.changed.v1';
  int get schemaVersion => 1;
  String get producer => 'progress';
  final String aggregateId;
  final String occurredAt;
  final String requestId;
  final EntitlementEventPayload payload;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'type': type,
        'schemaVersion': schemaVersion,
        'producer': producer,
        'aggregateId': aggregateId,
        'occurredAt': occurredAt,
        'requestId': requestId,
        'payload': payload.toJson(),
      };
}

/// Inline wire object `BusinessEventEnergyGrantedV1` (nested in a component schema).
final class BusinessEventEnergyGrantedV1 implements BusinessEvent {
  const BusinessEventEnergyGrantedV1({
    required this.eventId,
    required this.aggregateId,
    required this.occurredAt,
    required this.requestId,
    required this.payload,
  });

  static BusinessEventEnergyGrantedV1 _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BusinessEventEnergyGrantedV1(
      eventId: map['eventId'] as String,
      aggregateId: map['aggregateId'] as String,
      occurredAt: map['occurredAt'] as String,
      requestId: map['requestId'] as String,
      payload: EnergyGrantedEventPayload._decode(map['payload']),
    );
  }

  final String eventId;
  @override
  String get type => 'energy.granted.v1';
  int get schemaVersion => 1;
  String get producer => 'progress';
  final String aggregateId;
  final String occurredAt;
  final String requestId;
  final EnergyGrantedEventPayload payload;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'type': type,
        'schemaVersion': schemaVersion,
        'producer': producer,
        'aggregateId': aggregateId,
        'occurredAt': occurredAt,
        'requestId': requestId,
        'payload': payload.toJson(),
      };
}

/// Wire union for `#/components/schemas/BusinessEvent` (oneOf, discriminated by `type`).
sealed class BusinessEvent {
  /// Validates [json] against the `BusinessEvent` schema (exactly one variant), then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory BusinessEvent.fromJson(Object? json) {
    ContractValidator.instance.check('BusinessEvent', json);
    return BusinessEvent._decode(json);
  }

  static BusinessEvent _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return switch (map['type']) {
      'lesson.completed.v1' => BusinessEventLessonCompletedV1._decode(map),
      'account.deleted.v1' => BusinessEventAccountDeletedV1._decode(map),
      'account.purged.v1' => BusinessEventAccountPurgedV1._decode(map),
      'zone.changed.v1' => BusinessEventZoneChangedV1._decode(map),
      'ai.practice.completed.v1' => BusinessEventAiPracticeCompletedV1._decode(map),
      'entitlement.changed.v1' => BusinessEventEntitlementChangedV1._decode(map),
      'energy.granted.v1' => BusinessEventEnergyGrantedV1._decode(map),
      _ => throw StateError('Unknown BusinessEvent.type after validation'),
    };
  }

  /// Discriminator value of this variant.
  String get type;

  Map<String, Object?> toJson();
}

/// Wire DTO for `#/components/schemas/Watermark`.
final class Watermark {
  const Watermark({
    required this.before,
    required this.oldestUndeliveredAt,
    required this.pendingBefore,
  });

  /// Validates [json] against the `Watermark` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Watermark.fromJson(Object? json) {
    ContractValidator.instance.check('Watermark', json);
    return Watermark._decode(json);
  }

  static Watermark _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Watermark(
      before: map['before'] as String,
      oldestUndeliveredAt: map['oldestUndeliveredAt'] == null ? null : map['oldestUndeliveredAt'] as String,
      pendingBefore: (map['pendingBefore'] as num).toInt(),
    );
  }

  final String before;
  final String? oldestUndeliveredAt;
  final int pendingBefore;

  Map<String, Object?> toJson() => <String, Object?>{
        'before': before,
        'oldestUndeliveredAt': oldestUndeliveredAt,
        'pendingBefore': pendingBefore,
      };
}

/// Wire DTO for `#/components/schemas/TurnRequest`.
final class TurnRequest {
  const TurnRequest({
    required this.turnId,
    required this.epoch,
    required this.wavBase64,
    required this.audioSha256,
  });

  /// Validates [json] against the `TurnRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TurnRequest.fromJson(Object? json) {
    ContractValidator.instance.check('TurnRequest', json);
    return TurnRequest._decode(json);
  }

  static TurnRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TurnRequest(
      turnId: map['turnId'] as String,
      epoch: (map['epoch'] as num).toInt(),
      wavBase64: map['wavBase64'] as String,
      audioSha256: map['audioSha256'] as String,
    );
  }

  final String turnId;
  final int epoch;
  final String wavBase64;
  final String audioSha256;

  Map<String, Object?> toJson() => <String, Object?>{
        'turnId': turnId,
        'epoch': epoch,
        'wavBase64': wavBase64,
        'audioSha256': audioSha256,
      };
}

/// Wire DTO for `#/components/schemas/TurnResult`.
final class TurnResult {
  const TurnResult({
    required this.turnId,
    required this.epoch,
    required this.transcript,
    required this.tutor,
    required this.audioAssetId,
    required this.score,
  });

  /// Validates [json] against the `TurnResult` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory TurnResult.fromJson(Object? json) {
    ContractValidator.instance.check('TurnResult', json);
    return TurnResult._decode(json);
  }

  static TurnResult _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return TurnResult(
      turnId: map['turnId'] as String,
      epoch: (map['epoch'] as num).toInt(),
      transcript: map['transcript'] as String,
      tutor: TutorResult._decode(map['tutor']),
      audioAssetId: map['audioAssetId'] == null ? null : map['audioAssetId'] as String,
      score: map['score'],
    );
  }

  final String turnId;
  final int epoch;
  final String transcript;
  final TutorResult tutor;
  final String? audioAssetId;
  final Object? score;
  String get mode => 'TURN';

  Map<String, Object?> toJson() => <String, Object?>{
        'turnId': turnId,
        'epoch': epoch,
        'transcript': transcript,
        'tutor': tutor.toJson(),
        'audioAssetId': audioAssetId,
        'score': score,
        'mode': mode,
      };
}

/// Wire DTO for `#/components/schemas/CoursePage`.
final class CoursePage {
  const CoursePage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `CoursePage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory CoursePage.fromJson(Object? json) {
    ContractValidator.instance.check('CoursePage', json);
    return CoursePage._decode(json);
  }

  static CoursePage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return CoursePage(
      items: List<Course>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => Course._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<Course> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((Course x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/ReviewPage`.
final class ReviewPage {
  const ReviewPage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `ReviewPage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ReviewPage.fromJson(Object? json) {
    ContractValidator.instance.check('ReviewPage', json);
    return ReviewPage._decode(json);
  }

  static ReviewPage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ReviewPage(
      items: List<ReviewItem>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => ReviewItem._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<ReviewItem> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((ReviewItem x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/QuestPage`.
final class QuestPage {
  const QuestPage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `QuestPage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory QuestPage.fromJson(Object? json) {
    ContractValidator.instance.check('QuestPage', json);
    return QuestPage._decode(json);
  }

  static QuestPage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return QuestPage(
      items: List<Quest>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => Quest._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<Quest> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((Quest x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/ProfilePage`.
final class ProfilePage {
  const ProfilePage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `ProfilePage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ProfilePage.fromJson(Object? json) {
    ContractValidator.instance.check('ProfilePage', json);
    return ProfilePage._decode(json);
  }

  static ProfilePage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ProfilePage(
      items: List<PublicProfile>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => PublicProfile._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<PublicProfile> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((PublicProfile x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/ActivityPage`.
final class ActivityPage {
  const ActivityPage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `ActivityPage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ActivityPage.fromJson(Object? json) {
    ContractValidator.instance.check('ActivityPage', json);
    return ActivityPage._decode(json);
  }

  static ActivityPage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ActivityPage(
      items: List<Activity>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => Activity._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<Activity> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((Activity x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/Energy`.
final class Energy {
  const Energy({
    required this.mode,
    required this.balance,
    required this.capacity,
    required this.nextUnitAt,
    required this.fullAt,
    required this.revision,
    required this.asOf,
  });

  /// Validates [json] against the `Energy` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Energy.fromJson(Object? json) {
    ContractValidator.instance.check('Energy', json);
    return Energy._decode(json);
  }

  static Energy _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Energy(
      mode: map['mode'] as String,
      balance: (map['balance'] as num).toInt(),
      capacity: (map['capacity'] as num).toInt(),
      nextUnitAt: map['nextUnitAt'] == null ? null : map['nextUnitAt'] as String,
      fullAt: map['fullAt'] == null ? null : map['fullAt'] as String,
      revision: (map['revision'] as num).toInt(),
      asOf: map['asOf'] as String,
    );
  }

  final String mode;
  final int balance;
  final int capacity;
  final String? nextUnitAt;
  final String? fullAt;
  final int revision;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'mode': mode,
        'balance': balance,
        'capacity': capacity,
        'nextUnitAt': nextUnitAt,
        'fullAt': fullAt,
        'revision': revision,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/EnrollmentCommandRequest`.
final class EnrollmentCommandRequest {
  const EnrollmentCommandRequest({
    required this.expectedRevision,
  });

  /// Validates [json] against the `EnrollmentCommandRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory EnrollmentCommandRequest.fromJson(Object? json) {
    ContractValidator.instance.check('EnrollmentCommandRequest', json);
    return EnrollmentCommandRequest._decode(json);
  }

  static EnrollmentCommandRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return EnrollmentCommandRequest(
      expectedRevision: (map['expectedRevision'] as num).toInt(),
    );
  }

  final int expectedRevision;

  Map<String, Object?> toJson() => <String, Object?>{
        'expectedRevision': expectedRevision,
      };
}

/// Wire DTO for `#/components/schemas/Mistake`.
final class Mistake {
  const Mistake({
    required this.courseId,
    required this.exerciseId,
    required this.lessonVersion,
    required this.skillId,
    required this.mistakeCount,
    required this.lastMistakeAt,
    required this.resolvedAt,
  });

  /// Validates [json] against the `Mistake` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Mistake.fromJson(Object? json) {
    ContractValidator.instance.check('Mistake', json);
    return Mistake._decode(json);
  }

  static Mistake _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Mistake(
      courseId: map['courseId'] as String,
      exerciseId: map['exerciseId'] as String,
      lessonVersion: map['lessonVersion'] as String,
      skillId: map['skillId'] as String,
      mistakeCount: (map['mistakeCount'] as num).toInt(),
      lastMistakeAt: map['lastMistakeAt'] as String,
      resolvedAt: map['resolvedAt'] == null ? null : map['resolvedAt'] as String,
    );
  }

  final String courseId;
  final String exerciseId;
  final String lessonVersion;
  final String skillId;
  final int mistakeCount;
  final String lastMistakeAt;
  final String? resolvedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'courseId': courseId,
        'exerciseId': exerciseId,
        'lessonVersion': lessonVersion,
        'skillId': skillId,
        'mistakeCount': mistakeCount,
        'lastMistakeAt': lastMistakeAt,
        'resolvedAt': resolvedAt,
      };
}

/// Wire DTO for `#/components/schemas/MistakePage`.
final class MistakePage {
  const MistakePage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `MistakePage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory MistakePage.fromJson(Object? json) {
    ContractValidator.instance.check('MistakePage', json);
    return MistakePage._decode(json);
  }

  static MistakePage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return MistakePage(
      items: List<Mistake>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => Mistake._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<Mistake> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((Mistake x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/Word`.
final class Word {
  const Word({
    required this.courseId,
    required this.vocabularyId,
    required this.skillId,
    required this.term,
    required this.translation,
    required this.stage,
    required this.strength,
    required this.halfLifeHours,
    required this.correctCount,
    required this.incorrectCount,
    required this.firstSeenAt,
    required this.lastReviewedAt,
    required this.dueAt,
  });

  /// Validates [json] against the `Word` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Word.fromJson(Object? json) {
    ContractValidator.instance.check('Word', json);
    return Word._decode(json);
  }

  static Word _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Word(
      courseId: map['courseId'] as String,
      vocabularyId: map['vocabularyId'] as String,
      skillId: map['skillId'] as String,
      term: map['term'] as String,
      translation: map['translation'] == null ? null : map['translation'] as String,
      stage: (map['stage'] as num).toInt(),
      strength: (map['strength'] as num).toInt(),
      halfLifeHours: (map['halfLifeHours'] as num).toInt(),
      correctCount: (map['correctCount'] as num).toInt(),
      incorrectCount: (map['incorrectCount'] as num).toInt(),
      firstSeenAt: map['firstSeenAt'] as String,
      lastReviewedAt: map['lastReviewedAt'] == null ? null : map['lastReviewedAt'] as String,
      dueAt: map['dueAt'] as String,
    );
  }

  final String courseId;
  final String vocabularyId;
  final String skillId;
  final String term;
  final String? translation;
  final int stage;
  final int strength;
  final int halfLifeHours;
  final int correctCount;
  final int incorrectCount;
  final String firstSeenAt;
  final String? lastReviewedAt;
  final String dueAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'courseId': courseId,
        'vocabularyId': vocabularyId,
        'skillId': skillId,
        'term': term,
        'translation': translation,
        'stage': stage,
        'strength': strength,
        'halfLifeHours': halfLifeHours,
        'correctCount': correctCount,
        'incorrectCount': incorrectCount,
        'firstSeenAt': firstSeenAt,
        'lastReviewedAt': lastReviewedAt,
        'dueAt': dueAt,
      };
}

/// Wire DTO for `#/components/schemas/WordPage`.
final class WordPage {
  const WordPage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `WordPage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory WordPage.fromJson(Object? json) {
    ContractValidator.instance.check('WordPage', json);
    return WordPage._decode(json);
  }

  static WordPage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return WordPage(
      items: List<Word>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => Word._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<Word> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((Word x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/ActivityProgress`.
final class ActivityProgress {
  const ActivityProgress({
    required this.courseId,
    required this.kind,
    required this.activityId,
    required this.completions,
    required this.bestScore,
    required this.stars,
    required this.firstCompletedAt,
    required this.lastCompletedAt,
  });

  /// Validates [json] against the `ActivityProgress` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ActivityProgress.fromJson(Object? json) {
    ContractValidator.instance.check('ActivityProgress', json);
    return ActivityProgress._decode(json);
  }

  static ActivityProgress _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ActivityProgress(
      courseId: map['courseId'] as String,
      kind: map['kind'] as String,
      activityId: map['activityId'] as String,
      completions: (map['completions'] as num).toInt(),
      bestScore: (map['bestScore'] as num).toInt(),
      stars: (map['stars'] as num).toInt(),
      firstCompletedAt: map['firstCompletedAt'] == null ? null : map['firstCompletedAt'] as String,
      lastCompletedAt: map['lastCompletedAt'] == null ? null : map['lastCompletedAt'] as String,
    );
  }

  final String courseId;
  final String kind;
  final String activityId;
  final int completions;
  final int bestScore;
  final int stars;
  final String? firstCompletedAt;
  final String? lastCompletedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'courseId': courseId,
        'kind': kind,
        'activityId': activityId,
        'completions': completions,
        'bestScore': bestScore,
        'stars': stars,
        'firstCompletedAt': firstCompletedAt,
        'lastCompletedAt': lastCompletedAt,
      };
}

/// Wire DTO for `#/components/schemas/ActivityProgressPage`.
final class ActivityProgressPage {
  const ActivityProgressPage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `ActivityProgressPage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ActivityProgressPage.fromJson(Object? json) {
    ContractValidator.instance.check('ActivityProgressPage', json);
    return ActivityProgressPage._decode(json);
  }

  static ActivityProgressPage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ActivityProgressPage(
      items: List<ActivityProgress>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => ActivityProgress._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<ActivityProgress> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((ActivityProgress x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/Preferences`.
final class Preferences {
  const Preferences({
    required this.notificationsOff,
    required this.smartScheduling,
    required this.reminderMinute,
    required this.soundEffects,
    required this.haptics,
    required this.motivationalMessages,
    required this.listeningExercises,
    required this.speakingExercises,
    required this.friendStreakInvites,
    required this.revision,
    required this.asOf,
  });

  /// Validates [json] against the `Preferences` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Preferences.fromJson(Object? json) {
    ContractValidator.instance.check('Preferences', json);
    return Preferences._decode(json);
  }

  static Preferences _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Preferences(
      notificationsOff: List<String>.unmodifiable((map['notificationsOff'] as List<Object?>).map((Object? x) => x as String)),
      smartScheduling: map['smartScheduling'] as bool,
      reminderMinute: (map['reminderMinute'] as num).toInt(),
      soundEffects: map['soundEffects'] as bool,
      haptics: map['haptics'] as bool,
      motivationalMessages: map['motivationalMessages'] as bool,
      listeningExercises: map['listeningExercises'] as bool,
      speakingExercises: map['speakingExercises'] as bool,
      friendStreakInvites: map['friendStreakInvites'] as bool,
      revision: (map['revision'] as num).toInt(),
      asOf: map['asOf'] as String,
    );
  }

  final List<String> notificationsOff;
  final bool smartScheduling;
  final int reminderMinute;
  final bool soundEffects;
  final bool haptics;
  final bool motivationalMessages;
  final bool listeningExercises;
  final bool speakingExercises;
  final bool friendStreakInvites;
  final int revision;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'notificationsOff': List<Object?>.of(notificationsOff),
        'smartScheduling': smartScheduling,
        'reminderMinute': reminderMinute,
        'soundEffects': soundEffects,
        'haptics': haptics,
        'motivationalMessages': motivationalMessages,
        'listeningExercises': listeningExercises,
        'speakingExercises': speakingExercises,
        'friendStreakInvites': friendStreakInvites,
        'revision': revision,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/PreferencesPatch`.
final class PreferencesPatch {
  const PreferencesPatch({
    this.notificationsOff,
    this.smartScheduling,
    this.reminderMinute,
    this.soundEffects,
    this.haptics,
    this.motivationalMessages,
    this.listeningExercises,
    this.speakingExercises,
    this.friendStreakInvites,
    required this.expectedRevision,
  });

  /// Validates [json] against the `PreferencesPatch` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory PreferencesPatch.fromJson(Object? json) {
    ContractValidator.instance.check('PreferencesPatch', json);
    return PreferencesPatch._decode(json);
  }

  static PreferencesPatch _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PreferencesPatch(
      notificationsOff: map.containsKey('notificationsOff') ? List<String>.unmodifiable((map['notificationsOff'] as List<Object?>).map((Object? x) => x as String)) : null,
      smartScheduling: map.containsKey('smartScheduling') ? map['smartScheduling'] as bool : null,
      reminderMinute: map.containsKey('reminderMinute') ? (map['reminderMinute'] as num).toInt() : null,
      soundEffects: map.containsKey('soundEffects') ? map['soundEffects'] as bool : null,
      haptics: map.containsKey('haptics') ? map['haptics'] as bool : null,
      motivationalMessages: map.containsKey('motivationalMessages') ? map['motivationalMessages'] as bool : null,
      listeningExercises: map.containsKey('listeningExercises') ? map['listeningExercises'] as bool : null,
      speakingExercises: map.containsKey('speakingExercises') ? map['speakingExercises'] as bool : null,
      friendStreakInvites: map.containsKey('friendStreakInvites') ? map['friendStreakInvites'] as bool : null,
      expectedRevision: (map['expectedRevision'] as num).toInt(),
    );
  }

  final List<String>? notificationsOff;
  final bool? smartScheduling;
  final int? reminderMinute;
  final bool? soundEffects;
  final bool? haptics;
  final bool? motivationalMessages;
  final bool? listeningExercises;
  final bool? speakingExercises;
  final bool? friendStreakInvites;
  final int expectedRevision;

  Map<String, Object?> toJson() => <String, Object?>{
        if (notificationsOff != null) 'notificationsOff': List<Object?>.of(notificationsOff!),
        'smartScheduling': ?smartScheduling,
        'reminderMinute': ?reminderMinute,
        'soundEffects': ?soundEffects,
        'haptics': ?haptics,
        'motivationalMessages': ?motivationalMessages,
        'listeningExercises': ?listeningExercises,
        'speakingExercises': ?speakingExercises,
        'friendStreakInvites': ?friendStreakInvites,
        'expectedRevision': expectedRevision,
      };
}

/// Wire DTO for `#/components/schemas/FeedbackRequest`.
final class FeedbackRequest {
  const FeedbackRequest({
    required this.topic,
    required this.message,
    required this.appVersion,
    required this.platform,
  });

  /// Validates [json] against the `FeedbackRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FeedbackRequest.fromJson(Object? json) {
    ContractValidator.instance.check('FeedbackRequest', json);
    return FeedbackRequest._decode(json);
  }

  static FeedbackRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FeedbackRequest(
      topic: map['topic'] as String,
      message: map['message'] as String,
      appVersion: map['appVersion'] as String,
      platform: map['platform'] as String,
    );
  }

  final String topic;
  final String message;
  final String appVersion;
  final String platform;

  Map<String, Object?> toJson() => <String, Object?>{
        'topic': topic,
        'message': message,
        'appVersion': appVersion,
        'platform': platform,
      };
}

/// Wire DTO for `#/components/schemas/InventoryItem`.
final class InventoryItem {
  const InventoryItem({
    required this.itemId,
    required this.quantity,
    required this.expiresAt,
  });

  /// Validates [json] against the `InventoryItem` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory InventoryItem.fromJson(Object? json) {
    ContractValidator.instance.check('InventoryItem', json);
    return InventoryItem._decode(json);
  }

  static InventoryItem _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return InventoryItem(
      itemId: map['itemId'] as String,
      quantity: (map['quantity'] as num).toInt(),
      expiresAt: map['expiresAt'] == null ? null : map['expiresAt'] as String,
    );
  }

  final String itemId;
  final int quantity;
  final String? expiresAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'itemId': itemId,
        'quantity': quantity,
        'expiresAt': expiresAt,
      };
}

/// Wire DTO for `#/components/schemas/ShopItem`.
final class ShopItem {
  const ShopItem({
    required this.itemId,
    required this.kind,
    required this.priceGems,
    required this.maxOwned,
    required this.owned,
    required this.durationMinutes,
    required this.available,
  });

  /// Validates [json] against the `ShopItem` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ShopItem.fromJson(Object? json) {
    ContractValidator.instance.check('ShopItem', json);
    return ShopItem._decode(json);
  }

  static ShopItem _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ShopItem(
      itemId: map['itemId'] as String,
      kind: map['kind'] as String,
      priceGems: (map['priceGems'] as num).toInt(),
      maxOwned: (map['maxOwned'] as num).toInt(),
      owned: (map['owned'] as num).toInt(),
      durationMinutes: map['durationMinutes'] == null ? null : (map['durationMinutes'] as num).toInt(),
      available: map['available'] as bool,
    );
  }

  final String itemId;
  final String kind;
  final int priceGems;
  final int maxOwned;
  final int owned;
  final int? durationMinutes;
  final bool available;

  Map<String, Object?> toJson() => <String, Object?>{
        'itemId': itemId,
        'kind': kind,
        'priceGems': priceGems,
        'maxOwned': maxOwned,
        'owned': owned,
        'durationMinutes': durationMinutes,
        'available': available,
      };
}

/// Wire DTO for `#/components/schemas/Shop`.
final class Shop {
  const Shop({
    required this.catalogVersion,
    required this.gems,
    required this.freezeSlots,
    required this.items,
    required this.inventory,
    required this.asOf,
  });

  /// Validates [json] against the `Shop` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Shop.fromJson(Object? json) {
    ContractValidator.instance.check('Shop', json);
    return Shop._decode(json);
  }

  static Shop _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Shop(
      catalogVersion: map['catalogVersion'] as String,
      gems: (map['gems'] as num).toInt(),
      freezeSlots: (map['freezeSlots'] as num).toInt(),
      items: List<ShopItem>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => ShopItem._decode(x))),
      inventory: List<InventoryItem>.unmodifiable((map['inventory'] as List<Object?>).map((Object? x) => InventoryItem._decode(x))),
      asOf: map['asOf'] as String,
    );
  }

  final String catalogVersion;
  final int gems;
  final int freezeSlots;
  final List<ShopItem> items;
  final List<InventoryItem> inventory;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'catalogVersion': catalogVersion,
        'gems': gems,
        'freezeSlots': freezeSlots,
        'items': items.map((ShopItem x) => x.toJson()).toList(),
        'inventory': inventory.map((InventoryItem x) => x.toJson()).toList(),
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/ShopPurchaseRequest`.
final class ShopPurchaseRequest {
  const ShopPurchaseRequest({
    required this.itemId,
    required this.quantity,
    required this.catalogVersion,
  });

  /// Validates [json] against the `ShopPurchaseRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ShopPurchaseRequest.fromJson(Object? json) {
    ContractValidator.instance.check('ShopPurchaseRequest', json);
    return ShopPurchaseRequest._decode(json);
  }

  static ShopPurchaseRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ShopPurchaseRequest(
      itemId: map['itemId'] as String,
      quantity: (map['quantity'] as num).toInt(),
      catalogVersion: map['catalogVersion'] as String,
    );
  }

  final String itemId;
  final int quantity;
  final String catalogVersion;

  Map<String, Object?> toJson() => <String, Object?>{
        'itemId': itemId,
        'quantity': quantity,
        'catalogVersion': catalogVersion,
      };
}

/// Wire DTO for `#/components/schemas/ShopPurchase`.
final class ShopPurchase {
  const ShopPurchase({
    required this.operationId,
    required this.itemId,
    required this.quantity,
    required this.gemsSpent,
    required this.gems,
    required this.freezeSlots,
    required this.inventory,
    required this.energyGrantPending,
    required this.asOf,
  });

  /// Validates [json] against the `ShopPurchase` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ShopPurchase.fromJson(Object? json) {
    ContractValidator.instance.check('ShopPurchase', json);
    return ShopPurchase._decode(json);
  }

  static ShopPurchase _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ShopPurchase(
      operationId: map['operationId'] as String,
      itemId: map['itemId'] as String,
      quantity: (map['quantity'] as num).toInt(),
      gemsSpent: (map['gemsSpent'] as num).toInt(),
      gems: (map['gems'] as num).toInt(),
      freezeSlots: (map['freezeSlots'] as num).toInt(),
      inventory: map['inventory'] == null ? null : InventoryItem._decode(map['inventory']),
      energyGrantPending: map['energyGrantPending'] as bool,
      asOf: map['asOf'] as String,
    );
  }

  final String operationId;
  final String itemId;
  final int quantity;
  final int gemsSpent;
  final int gems;
  final int freezeSlots;
  final InventoryItem? inventory;
  final bool energyGrantPending;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'operationId': operationId,
        'itemId': itemId,
        'quantity': quantity,
        'gemsSpent': gemsSpent,
        'gems': gems,
        'freezeSlots': freezeSlots,
        'inventory': inventory?.toJson(),
        'energyGrantPending': energyGrantPending,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/BoostRequest`.
final class BoostRequest {
  const BoostRequest({
    required this.itemId,
  });

  /// Validates [json] against the `BoostRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory BoostRequest.fromJson(Object? json) {
    ContractValidator.instance.check('BoostRequest', json);
    return BoostRequest._decode(json);
  }

  static BoostRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BoostRequest(
      itemId: map['itemId'] as String,
    );
  }

  final String itemId;

  Map<String, Object?> toJson() => <String, Object?>{
        'itemId': itemId,
      };
}

/// Wire DTO for `#/components/schemas/Boost`.
final class Boost {
  const Boost({
    required this.boostId,
    required this.kind,
    required this.multiplier,
    required this.startsAt,
    required this.endsAt,
    required this.inventory,
  });

  /// Validates [json] against the `Boost` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Boost.fromJson(Object? json) {
    ContractValidator.instance.check('Boost', json);
    return Boost._decode(json);
  }

  static Boost _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Boost(
      boostId: map['boostId'] as String,
      kind: map['kind'] as String,
      multiplier: (map['multiplier'] as num).toInt(),
      startsAt: map['startsAt'] as String,
      endsAt: map['endsAt'] as String,
      inventory: map['inventory'] == null ? null : InventoryItem._decode(map['inventory']),
    );
  }

  final String boostId;
  final String kind;
  final int multiplier;
  final String startsAt;
  final String endsAt;
  final InventoryItem? inventory;

  Map<String, Object?> toJson() => <String, Object?>{
        'boostId': boostId,
        'kind': kind,
        'multiplier': multiplier,
        'startsAt': startsAt,
        'endsAt': endsAt,
        'inventory': inventory?.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/StreakRepairRequest`.
final class StreakRepairRequest {
  const StreakRepairRequest({
    required this.lostStreakDay,
    required this.payWith,
  });

  /// Validates [json] against the `StreakRepairRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory StreakRepairRequest.fromJson(Object? json) {
    ContractValidator.instance.check('StreakRepairRequest', json);
    return StreakRepairRequest._decode(json);
  }

  static StreakRepairRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return StreakRepairRequest(
      lostStreakDay: map['lostStreakDay'] as String,
      payWith: map['payWith'] as String,
    );
  }

  final String lostStreakDay;
  final String payWith;

  Map<String, Object?> toJson() => <String, Object?>{
        'lostStreakDay': lostStreakDay,
        'payWith': payWith,
      };
}

/// Wire DTO for `#/components/schemas/FriendStreak`.
final class FriendStreak {
  const FriendStreak({
    required this.pairId,
    required this.friendUserId,
    required this.friendNickname,
    required this.inviterId,
    required this.status,
    required this.length,
    required this.startDay,
    required this.lastExtendedDay,
    required this.extendedToday,
  });

  /// Validates [json] against the `FriendStreak` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FriendStreak.fromJson(Object? json) {
    ContractValidator.instance.check('FriendStreak', json);
    return FriendStreak._decode(json);
  }

  static FriendStreak _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FriendStreak(
      pairId: map['pairId'] as String,
      friendUserId: map['friendUserId'] as String,
      friendNickname: map['friendNickname'] as String,
      inviterId: map['inviterId'] as String,
      status: map['status'] as String,
      length: (map['length'] as num).toInt(),
      startDay: map['startDay'] == null ? null : map['startDay'] as String,
      lastExtendedDay: map['lastExtendedDay'] == null ? null : map['lastExtendedDay'] as String,
      extendedToday: map['extendedToday'] as bool,
    );
  }

  final String pairId;
  final String friendUserId;
  final String friendNickname;
  final String inviterId;
  final String status;
  final int length;
  final String? startDay;
  final String? lastExtendedDay;
  final bool extendedToday;

  Map<String, Object?> toJson() => <String, Object?>{
        'pairId': pairId,
        'friendUserId': friendUserId,
        'friendNickname': friendNickname,
        'inviterId': inviterId,
        'status': status,
        'length': length,
        'startDay': startDay,
        'lastExtendedDay': lastExtendedDay,
        'extendedToday': extendedToday,
      };
}

/// Wire DTO for `#/components/schemas/FriendStreakPage`.
final class FriendStreakPage {
  const FriendStreakPage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `FriendStreakPage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FriendStreakPage.fromJson(Object? json) {
    ContractValidator.instance.check('FriendStreakPage', json);
    return FriendStreakPage._decode(json);
  }

  static FriendStreakPage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FriendStreakPage(
      items: List<FriendStreak>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => FriendStreak._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<FriendStreak> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((FriendStreak x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/FriendStreakInviteRequest`.
final class FriendStreakInviteRequest {
  const FriendStreakInviteRequest({
    required this.targetUserId,
  });

  /// Validates [json] against the `FriendStreakInviteRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FriendStreakInviteRequest.fromJson(Object? json) {
    ContractValidator.instance.check('FriendStreakInviteRequest', json);
    return FriendStreakInviteRequest._decode(json);
  }

  static FriendStreakInviteRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FriendStreakInviteRequest(
      targetUserId: map['targetUserId'] as String,
    );
  }

  final String targetUserId;

  Map<String, Object?> toJson() => <String, Object?>{
        'targetUserId': targetUserId,
      };
}

/// Wire DTO for `#/components/schemas/FriendStreakResponseRequest`.
final class FriendStreakResponseRequest {
  const FriendStreakResponseRequest({
    required this.accept,
  });

  /// Validates [json] against the `FriendStreakResponseRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FriendStreakResponseRequest.fromJson(Object? json) {
    ContractValidator.instance.check('FriendStreakResponseRequest', json);
    return FriendStreakResponseRequest._decode(json);
  }

  static FriendStreakResponseRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FriendStreakResponseRequest(
      accept: map['accept'] as bool,
    );
  }

  final bool accept;

  Map<String, Object?> toJson() => <String, Object?>{
        'accept': accept,
      };
}

/// Wire DTO for `#/components/schemas/InteractionRequest`.
final class InteractionRequest {
  const InteractionRequest({
    required this.targetUserId,
    required this.kind,
    required this.contextId,
    required this.messageKey,
  });

  /// Validates [json] against the `InteractionRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory InteractionRequest.fromJson(Object? json) {
    ContractValidator.instance.check('InteractionRequest', json);
    return InteractionRequest._decode(json);
  }

  static InteractionRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return InteractionRequest(
      targetUserId: map['targetUserId'] as String,
      kind: map['kind'] as String,
      contextId: map['contextId'] as String,
      messageKey: map['messageKey'] as String,
    );
  }

  final String targetUserId;
  final String kind;
  final String contextId;
  final String messageKey;

  Map<String, Object?> toJson() => <String, Object?>{
        'targetUserId': targetUserId,
        'kind': kind,
        'contextId': contextId,
        'messageKey': messageKey,
      };
}

/// Wire DTO for `#/components/schemas/Interaction`.
final class Interaction {
  const Interaction({
    required this.operationId,
    required this.toUserId,
    required this.kind,
    required this.contextId,
    required this.day,
    required this.gemsCost,
    required this.gems,
  });

  /// Validates [json] against the `Interaction` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Interaction.fromJson(Object? json) {
    ContractValidator.instance.check('Interaction', json);
    return Interaction._decode(json);
  }

  static Interaction _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Interaction(
      operationId: map['operationId'] as String,
      toUserId: map['toUserId'] as String,
      kind: map['kind'] as String,
      contextId: map['contextId'] as String,
      day: map['day'] as String,
      gemsCost: (map['gemsCost'] as num).toInt(),
      gems: (map['gems'] as num).toInt(),
    );
  }

  final String operationId;
  final String toUserId;
  final String kind;
  final String contextId;
  final String day;
  final int gemsCost;
  final int gems;

  Map<String, Object?> toJson() => <String, Object?>{
        'operationId': operationId,
        'toUserId': toUserId,
        'kind': kind,
        'contextId': contextId,
        'day': day,
        'gemsCost': gemsCost,
        'gems': gems,
      };
}

/// Wire DTO for `#/components/schemas/BlockRequest`.
final class BlockRequest {
  const BlockRequest({
    required this.targetUserId,
  });

  /// Validates [json] against the `BlockRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory BlockRequest.fromJson(Object? json) {
    ContractValidator.instance.check('BlockRequest', json);
    return BlockRequest._decode(json);
  }

  static BlockRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BlockRequest(
      targetUserId: map['targetUserId'] as String,
    );
  }

  final String targetUserId;

  Map<String, Object?> toJson() => <String, Object?>{
        'targetUserId': targetUserId,
      };
}

/// Wire DTO for `#/components/schemas/UserReportRequest`.
final class UserReportRequest {
  const UserReportRequest({
    required this.targetUserId,
    required this.reason,
    required this.note,
  });

  /// Validates [json] against the `UserReportRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory UserReportRequest.fromJson(Object? json) {
    ContractValidator.instance.check('UserReportRequest', json);
    return UserReportRequest._decode(json);
  }

  static UserReportRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return UserReportRequest(
      targetUserId: map['targetUserId'] as String,
      reason: map['reason'] as String,
      note: map['note'] == null ? null : map['note'] as String,
    );
  }

  final String targetUserId;
  final String reason;
  final String? note;

  Map<String, Object?> toJson() => <String, Object?>{
        'targetUserId': targetUserId,
        'reason': reason,
        'note': note,
      };
}

/// Wire DTO for `#/components/schemas/ClassroomJoinRequest`.
final class ClassroomJoinRequest {
  const ClassroomJoinRequest({
    required this.joinCode,
  });

  /// Validates [json] against the `ClassroomJoinRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ClassroomJoinRequest.fromJson(Object? json) {
    ContractValidator.instance.check('ClassroomJoinRequest', json);
    return ClassroomJoinRequest._decode(json);
  }

  static ClassroomJoinRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ClassroomJoinRequest(
      joinCode: map['joinCode'] as String,
    );
  }

  final String joinCode;

  Map<String, Object?> toJson() => <String, Object?>{
        'joinCode': joinCode,
      };
}

/// Wire DTO for `#/components/schemas/ClassroomMembership`.
final class ClassroomMembership {
  const ClassroomMembership({
    required this.classroomId,
    required this.name,
    required this.courseId,
    required this.status,
    required this.joinedAt,
  });

  /// Validates [json] against the `ClassroomMembership` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ClassroomMembership.fromJson(Object? json) {
    ContractValidator.instance.check('ClassroomMembership', json);
    return ClassroomMembership._decode(json);
  }

  static ClassroomMembership _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ClassroomMembership(
      classroomId: map['classroomId'] as String,
      name: map['name'] as String,
      courseId: map['courseId'] as String,
      status: map['status'] as String,
      joinedAt: map['joinedAt'] as String,
    );
  }

  final String classroomId;
  final String name;
  final String courseId;
  final String status;
  final String joinedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'classroomId': classroomId,
        'name': name,
        'courseId': courseId,
        'status': status,
        'joinedAt': joinedAt,
      };
}

/// Wire DTO for `#/components/schemas/YearReview`.
final class YearReview {
  const YearReview({
    required this.year,
    required this.generatedAt,
    required this.totalXp,
    required this.activeDays,
    required this.longestStreak,
    required this.lessonsCompleted,
    required this.wordsLearned,
    required this.minutesSpent,
    required this.achievementsEarned,
    required this.topLeagueTier,
    required this.courseIds,
  });

  /// Validates [json] against the `YearReview` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory YearReview.fromJson(Object? json) {
    ContractValidator.instance.check('YearReview', json);
    return YearReview._decode(json);
  }

  static YearReview _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return YearReview(
      year: (map['year'] as num).toInt(),
      generatedAt: map['generatedAt'] as String,
      totalXp: (map['totalXp'] as num).toInt(),
      activeDays: (map['activeDays'] as num).toInt(),
      longestStreak: (map['longestStreak'] as num).toInt(),
      lessonsCompleted: (map['lessonsCompleted'] as num).toInt(),
      wordsLearned: (map['wordsLearned'] as num).toInt(),
      minutesSpent: (map['minutesSpent'] as num).toInt(),
      achievementsEarned: (map['achievementsEarned'] as num).toInt(),
      topLeagueTier: map['topLeagueTier'] == null ? null : (map['topLeagueTier'] as num).toInt(),
      courseIds: List<String>.unmodifiable((map['courseIds'] as List<Object?>).map((Object? x) => x as String)),
    );
  }

  final int year;
  final String generatedAt;
  final int totalXp;
  final int activeDays;
  final int longestStreak;
  final int lessonsCompleted;
  final int wordsLearned;
  final int minutesSpent;
  final int achievementsEarned;
  final int? topLeagueTier;
  final List<String> courseIds;

  Map<String, Object?> toJson() => <String, Object?>{
        'year': year,
        'generatedAt': generatedAt,
        'totalXp': totalXp,
        'activeDays': activeDays,
        'longestStreak': longestStreak,
        'lessonsCompleted': lessonsCompleted,
        'wordsLearned': wordsLearned,
        'minutesSpent': minutesSpent,
        'achievementsEarned': achievementsEarned,
        'topLeagueTier': topLeagueTier,
        'courseIds': List<Object?>.of(courseIds),
      };
}

/// Wire DTO for `#/components/schemas/LeagueWeekResult`.
final class LeagueWeekResult {
  const LeagueWeekResult({
    required this.weekId,
    required this.previousTier,
    required this.tier,
    required this.stage,
    required this.rank,
    required this.outcome,
    required this.gemsAwarded,
  });

  /// Validates [json] against the `LeagueWeekResult` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory LeagueWeekResult.fromJson(Object? json) {
    ContractValidator.instance.check('LeagueWeekResult', json);
    return LeagueWeekResult._decode(json);
  }

  static LeagueWeekResult _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return LeagueWeekResult(
      weekId: map['weekId'] as String,
      previousTier: (map['previousTier'] as num).toInt(),
      tier: (map['tier'] as num).toInt(),
      stage: map['stage'] as String,
      rank: map['rank'] == null ? null : (map['rank'] as num).toInt(),
      outcome: map['outcome'] as String,
      gemsAwarded: (map['gemsAwarded'] as num).toInt(),
    );
  }

  final String weekId;
  final int previousTier;
  final int tier;
  final String stage;
  final int? rank;
  final String outcome;
  final int gemsAwarded;

  Map<String, Object?> toJson() => <String, Object?>{
        'weekId': weekId,
        'previousTier': previousTier,
        'tier': tier,
        'stage': stage,
        'rank': rank,
        'outcome': outcome,
        'gemsAwarded': gemsAwarded,
      };
}

/// Wire DTO for `#/components/schemas/LeagueResult`.
final class LeagueResult {
  const LeagueResult({
    required this.tier,
    required this.stage,
    required this.weeksParticipated,
    required this.topThreeFinishes,
    required this.diamondWeeks,
    required this.lastResult,
    required this.unseen,
    required this.asOf,
  });

  /// Validates [json] against the `LeagueResult` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory LeagueResult.fromJson(Object? json) {
    ContractValidator.instance.check('LeagueResult', json);
    return LeagueResult._decode(json);
  }

  static LeagueResult _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return LeagueResult(
      tier: (map['tier'] as num).toInt(),
      stage: map['stage'] as String,
      weeksParticipated: (map['weeksParticipated'] as num).toInt(),
      topThreeFinishes: (map['topThreeFinishes'] as num).toInt(),
      diamondWeeks: (map['diamondWeeks'] as num).toInt(),
      lastResult: map['lastResult'] == null ? null : LeagueWeekResult._decode(map['lastResult']),
      unseen: map['unseen'] as bool,
      asOf: map['asOf'] as String,
    );
  }

  final int tier;
  final String stage;
  final int weeksParticipated;
  final int topThreeFinishes;
  final int diamondWeeks;
  final LeagueWeekResult? lastResult;
  final bool unseen;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'tier': tier,
        'stage': stage,
        'weeksParticipated': weeksParticipated,
        'topThreeFinishes': topThreeFinishes,
        'diamondWeeks': diamondWeeks,
        'lastResult': lastResult?.toJson(),
        'unseen': unseen,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/LeagueResultSeenRequest`.
final class LeagueResultSeenRequest {
  const LeagueResultSeenRequest({
    required this.weekId,
  });

  /// Validates [json] against the `LeagueResultSeenRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory LeagueResultSeenRequest.fromJson(Object? json) {
    ContractValidator.instance.check('LeagueResultSeenRequest', json);
    return LeagueResultSeenRequest._decode(json);
  }

  static LeagueResultSeenRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return LeagueResultSeenRequest(
      weekId: map['weekId'] as String,
    );
  }

  final String weekId;

  Map<String, Object?> toJson() => <String, Object?>{
        'weekId': weekId,
      };
}

/// Wire DTO for `#/components/schemas/Entitlement`.
final class Entitlement {
  const Entitlement({
    required this.plan,
    required this.source,
    required this.status,
    required this.expiresAt,
    required this.autoRenew,
    required this.familyGroupId,
    required this.unlimitedEnergy,
    required this.adFree,
    required this.conversations,
    required this.revision,
    required this.asOf,
  });

  /// Validates [json] against the `Entitlement` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Entitlement.fromJson(Object? json) {
    ContractValidator.instance.check('Entitlement', json);
    return Entitlement._decode(json);
  }

  static Entitlement _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Entitlement(
      plan: map['plan'] as String,
      source: map['source'] as String,
      status: map['status'] as String,
      expiresAt: map['expiresAt'] == null ? null : map['expiresAt'] as String,
      autoRenew: map['autoRenew'] as bool,
      familyGroupId: map['familyGroupId'] == null ? null : map['familyGroupId'] as String,
      unlimitedEnergy: map['unlimitedEnergy'] as bool,
      adFree: map['adFree'] as bool,
      conversations: map['conversations'] as bool,
      revision: (map['revision'] as num).toInt(),
      asOf: map['asOf'] as String,
    );
  }

  final String plan;
  final String source;
  final String status;
  final String? expiresAt;
  final bool autoRenew;
  final String? familyGroupId;
  final bool unlimitedEnergy;
  final bool adFree;
  final bool conversations;
  final int revision;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'plan': plan,
        'source': source,
        'status': status,
        'expiresAt': expiresAt,
        'autoRenew': autoRenew,
        'familyGroupId': familyGroupId,
        'unlimitedEnergy': unlimitedEnergy,
        'adFree': adFree,
        'conversations': conversations,
        'revision': revision,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/PurchaseRequest`.
final class PurchaseRequest {
  const PurchaseRequest({
    required this.productId,
    required this.kind,
    required this.simulationOutcome,
  });

  /// Validates [json] against the `PurchaseRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory PurchaseRequest.fromJson(Object? json) {
    ContractValidator.instance.check('PurchaseRequest', json);
    return PurchaseRequest._decode(json);
  }

  static PurchaseRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PurchaseRequest(
      productId: map['productId'] as String,
      kind: map['kind'] as String,
      simulationOutcome: map['simulationOutcome'] as String,
    );
  }

  final String productId;
  final String kind;
  String get platform => 'SIMULATION';
  final String simulationOutcome;

  Map<String, Object?> toJson() => <String, Object?>{
        'productId': productId,
        'kind': kind,
        'platform': platform,
        'simulationOutcome': simulationOutcome,
      };
}

/// Wire DTO for `#/components/schemas/Purchase`.
final class Purchase {
  const Purchase({
    required this.purchaseId,
    required this.productId,
    required this.kind,
    required this.state,
    required this.verifiedAt,
    required this.gems,
    required this.entitlement,
  });

  /// Validates [json] against the `Purchase` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Purchase.fromJson(Object? json) {
    ContractValidator.instance.check('Purchase', json);
    return Purchase._decode(json);
  }

  static Purchase _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Purchase(
      purchaseId: map['purchaseId'] as String,
      productId: map['productId'] as String,
      kind: map['kind'] as String,
      state: map['state'] as String,
      verifiedAt: map['verifiedAt'] == null ? null : map['verifiedAt'] as String,
      gems: map['gems'] == null ? null : (map['gems'] as num).toInt(),
      entitlement: Entitlement._decode(map['entitlement']),
    );
  }

  final String purchaseId;
  final String productId;
  final String kind;
  String get platform => 'SIMULATION';
  final String state;
  final String? verifiedAt;
  final int? gems;
  final Entitlement entitlement;

  Map<String, Object?> toJson() => <String, Object?>{
        'purchaseId': purchaseId,
        'productId': productId,
        'kind': kind,
        'platform': platform,
        'state': state,
        'verifiedAt': verifiedAt,
        'gems': gems,
        'entitlement': entitlement.toJson(),
      };
}

/// Wire DTO for `#/components/schemas/BillingNotification`.
final class BillingNotification {
  const BillingNotification({
    required this.notificationId,
    required this.purchaseId,
    required this.state,
    required this.occurredAt,
  });

  /// Validates [json] against the `BillingNotification` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory BillingNotification.fromJson(Object? json) {
    ContractValidator.instance.check('BillingNotification', json);
    return BillingNotification._decode(json);
  }

  static BillingNotification _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return BillingNotification(
      notificationId: map['notificationId'] as String,
      purchaseId: map['purchaseId'] as String,
      state: map['state'] as String,
      occurredAt: map['occurredAt'] as String,
    );
  }

  final String notificationId;
  final String purchaseId;
  String get platform => 'SIMULATION';
  final String state;
  final String occurredAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'notificationId': notificationId,
        'purchaseId': purchaseId,
        'platform': platform,
        'state': state,
        'occurredAt': occurredAt,
      };
}

/// Wire DTO for `#/components/schemas/FamilyMember`.
final class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.nickname,
    required this.role,
    required this.joinedAt,
  });

  /// Validates [json] against the `FamilyMember` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FamilyMember.fromJson(Object? json) {
    ContractValidator.instance.check('FamilyMember', json);
    return FamilyMember._decode(json);
  }

  static FamilyMember _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FamilyMember(
      userId: map['userId'] as String,
      nickname: map['nickname'] as String,
      role: map['role'] as String,
      joinedAt: map['joinedAt'] as String,
    );
  }

  final String userId;
  final String nickname;
  final String role;
  final String joinedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'nickname': nickname,
        'role': role,
        'joinedAt': joinedAt,
      };
}

/// Wire DTO for `#/components/schemas/FamilyGroup`.
final class FamilyGroup {
  const FamilyGroup({
    required this.groupId,
    required this.ownerUserId,
    required this.plan,
    required this.status,
    required this.members,
    required this.inviteCode,
    required this.revision,
  });

  /// Validates [json] against the `FamilyGroup` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FamilyGroup.fromJson(Object? json) {
    ContractValidator.instance.check('FamilyGroup', json);
    return FamilyGroup._decode(json);
  }

  static FamilyGroup _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FamilyGroup(
      groupId: map['groupId'] as String,
      ownerUserId: map['ownerUserId'] as String,
      plan: map['plan'] as String,
      status: map['status'] as String,
      members: List<FamilyMember>.unmodifiable((map['members'] as List<Object?>).map((Object? x) => FamilyMember._decode(x))),
      inviteCode: map['inviteCode'] == null ? null : map['inviteCode'] as String,
      revision: (map['revision'] as num).toInt(),
    );
  }

  final String groupId;
  final String ownerUserId;
  final String plan;
  final String status;
  final List<FamilyMember> members;
  final String? inviteCode;
  final int revision;

  Map<String, Object?> toJson() => <String, Object?>{
        'groupId': groupId,
        'ownerUserId': ownerUserId,
        'plan': plan,
        'status': status,
        'members': members.map((FamilyMember x) => x.toJson()).toList(),
        'inviteCode': inviteCode,
        'revision': revision,
      };
}

/// Wire DTO for `#/components/schemas/FamilyCreateRequest`.
final class FamilyCreateRequest {
  const FamilyCreateRequest({
    required this.plan,
  });

  /// Validates [json] against the `FamilyCreateRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FamilyCreateRequest.fromJson(Object? json) {
    ContractValidator.instance.check('FamilyCreateRequest', json);
    return FamilyCreateRequest._decode(json);
  }

  static FamilyCreateRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FamilyCreateRequest(
      plan: map['plan'] as String,
    );
  }

  final String plan;

  Map<String, Object?> toJson() => <String, Object?>{
        'plan': plan,
      };
}

/// Wire DTO for `#/components/schemas/FamilyJoinRequest`.
final class FamilyJoinRequest {
  const FamilyJoinRequest({
    required this.inviteCode,
  });

  /// Validates [json] against the `FamilyJoinRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory FamilyJoinRequest.fromJson(Object? json) {
    ContractValidator.instance.check('FamilyJoinRequest', json);
    return FamilyJoinRequest._decode(json);
  }

  static FamilyJoinRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return FamilyJoinRequest(
      inviteCode: map['inviteCode'] as String,
    );
  }

  final String inviteCode;

  Map<String, Object?> toJson() => <String, Object?>{
        'inviteCode': inviteCode,
      };
}

/// Wire DTO for `#/components/schemas/GiftRequest`.
final class GiftRequest {
  const GiftRequest({
    required this.recipientUserId,
    required this.plan,
    required this.durationDays,
    required this.note,
    required this.simulationOutcome,
  });

  /// Validates [json] against the `GiftRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory GiftRequest.fromJson(Object? json) {
    ContractValidator.instance.check('GiftRequest', json);
    return GiftRequest._decode(json);
  }

  static GiftRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return GiftRequest(
      recipientUserId: map['recipientUserId'] as String,
      plan: map['plan'] as String,
      durationDays: (map['durationDays'] as num).toInt(),
      note: map['note'] == null ? null : map['note'] as String,
      simulationOutcome: map['simulationOutcome'] as String,
    );
  }

  final String recipientUserId;
  final String plan;
  final int durationDays;
  final String? note;
  final String simulationOutcome;

  Map<String, Object?> toJson() => <String, Object?>{
        'recipientUserId': recipientUserId,
        'plan': plan,
        'durationDays': durationDays,
        'note': note,
        'simulationOutcome': simulationOutcome,
      };
}

/// Wire DTO for `#/components/schemas/Gift`.
final class Gift {
  const Gift({
    required this.giftId,
    required this.senderId,
    required this.recipientId,
    required this.plan,
    required this.durationDays,
    required this.note,
    required this.status,
    required this.deliveredAt,
  });

  /// Validates [json] against the `Gift` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Gift.fromJson(Object? json) {
    ContractValidator.instance.check('Gift', json);
    return Gift._decode(json);
  }

  static Gift _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Gift(
      giftId: map['giftId'] as String,
      senderId: map['senderId'] as String,
      recipientId: map['recipientId'] as String,
      plan: map['plan'] as String,
      durationDays: (map['durationDays'] as num).toInt(),
      note: map['note'] == null ? null : map['note'] as String,
      status: map['status'] as String,
      deliveredAt: map['deliveredAt'] == null ? null : map['deliveredAt'] as String,
    );
  }

  final String giftId;
  final String senderId;
  final String recipientId;
  final String plan;
  final int durationDays;
  final String? note;
  final String status;
  final String? deliveredAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'giftId': giftId,
        'senderId': senderId,
        'recipientId': recipientId,
        'plan': plan,
        'durationDays': durationDays,
        'note': note,
        'status': status,
        'deliveredAt': deliveredAt,
      };
}

/// Wire DTO for `#/components/schemas/Referral`.
final class Referral {
  const Referral({
    required this.code,
    required this.accepted,
    required this.qualified,
    required this.rewarded,
    required this.asOf,
  });

  /// Validates [json] against the `Referral` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Referral.fromJson(Object? json) {
    ContractValidator.instance.check('Referral', json);
    return Referral._decode(json);
  }

  static Referral _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Referral(
      code: map['code'] as String,
      accepted: (map['accepted'] as num).toInt(),
      qualified: (map['qualified'] as num).toInt(),
      rewarded: (map['rewarded'] as num).toInt(),
      asOf: map['asOf'] as String,
    );
  }

  final String code;
  final int accepted;
  final int qualified;
  final int rewarded;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code,
        'accepted': accepted,
        'qualified': qualified,
        'rewarded': rewarded,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/ReferralRedeemRequest`.
final class ReferralRedeemRequest {
  const ReferralRedeemRequest({
    required this.code,
  });

  /// Validates [json] against the `ReferralRedeemRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ReferralRedeemRequest.fromJson(Object? json) {
    ContractValidator.instance.check('ReferralRedeemRequest', json);
    return ReferralRedeemRequest._decode(json);
  }

  static ReferralRedeemRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ReferralRedeemRequest(
      code: map['code'] as String,
    );
  }

  final String code;

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code,
      };
}

/// Wire DTO for `#/components/schemas/PromoRedeemRequest`.
final class PromoRedeemRequest {
  const PromoRedeemRequest({
    required this.code,
  });

  /// Validates [json] against the `PromoRedeemRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory PromoRedeemRequest.fromJson(Object? json) {
    ContractValidator.instance.check('PromoRedeemRequest', json);
    return PromoRedeemRequest._decode(json);
  }

  static PromoRedeemRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PromoRedeemRequest(
      code: map['code'] as String,
    );
  }

  final String code;

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code,
      };
}

/// Wire DTO for `#/components/schemas/PromoRedemption`.
final class PromoRedemption {
  const PromoRedemption({
    required this.redemptionId,
    required this.promoId,
    required this.rewardType,
    required this.superDays,
    required this.gems,
    required this.itemId,
    required this.itemQuantity,
    required this.entitlement,
    required this.redeemedAt,
  });

  /// Validates [json] against the `PromoRedemption` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory PromoRedemption.fromJson(Object? json) {
    ContractValidator.instance.check('PromoRedemption', json);
    return PromoRedemption._decode(json);
  }

  static PromoRedemption _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return PromoRedemption(
      redemptionId: map['redemptionId'] as String,
      promoId: map['promoId'] as String,
      rewardType: map['rewardType'] as String,
      superDays: map['superDays'] == null ? null : (map['superDays'] as num).toInt(),
      gems: map['gems'] == null ? null : (map['gems'] as num).toInt(),
      itemId: map['itemId'] == null ? null : map['itemId'] as String,
      itemQuantity: map['itemQuantity'] == null ? null : (map['itemQuantity'] as num).toInt(),
      entitlement: map['entitlement'] == null ? null : Entitlement._decode(map['entitlement']),
      redeemedAt: map['redeemedAt'] as String,
    );
  }

  final String redemptionId;
  final String promoId;
  final String rewardType;
  final int? superDays;
  final int? gems;
  final String? itemId;
  final int? itemQuantity;
  final Entitlement? entitlement;
  final String redeemedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'redemptionId': redemptionId,
        'promoId': promoId,
        'rewardType': rewardType,
        'superDays': superDays,
        'gems': gems,
        'itemId': itemId,
        'itemQuantity': itemQuantity,
        'entitlement': entitlement?.toJson(),
        'redeemedAt': redeemedAt,
      };
}

/// Wire DTO for `#/components/schemas/AdEventRequest`.
final class AdEventRequest {
  const AdEventRequest({
    required this.adEventId,
    required this.placement,
    required this.kind,
  });

  /// Validates [json] against the `AdEventRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory AdEventRequest.fromJson(Object? json) {
    ContractValidator.instance.check('AdEventRequest', json);
    return AdEventRequest._decode(json);
  }

  static AdEventRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return AdEventRequest(
      adEventId: map['adEventId'] as String,
      placement: map['placement'] as String,
      kind: map['kind'] as String,
    );
  }

  final String adEventId;
  final String placement;
  final String kind;

  Map<String, Object?> toJson() => <String, Object?>{
        'adEventId': adEventId,
        'placement': placement,
        'kind': kind,
      };
}

/// Wire DTO for `#/components/schemas/AdEvent`.
final class AdEvent {
  const AdEvent({
    required this.adEventId,
    required this.placement,
    required this.kind,
    required this.learningDay,
    required this.dailyIndex,
    required this.remainingToday,
    required this.rewardGems,
    required this.rewardEnergy,
    required this.gems,
    required this.energyGrantPending,
  });

  /// Validates [json] against the `AdEvent` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory AdEvent.fromJson(Object? json) {
    ContractValidator.instance.check('AdEvent', json);
    return AdEvent._decode(json);
  }

  static AdEvent _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return AdEvent(
      adEventId: map['adEventId'] as String,
      placement: map['placement'] as String,
      kind: map['kind'] as String,
      learningDay: map['learningDay'] as String,
      dailyIndex: (map['dailyIndex'] as num).toInt(),
      remainingToday: (map['remainingToday'] as num).toInt(),
      rewardGems: (map['rewardGems'] as num).toInt(),
      rewardEnergy: (map['rewardEnergy'] as num).toInt(),
      gems: (map['gems'] as num).toInt(),
      energyGrantPending: map['energyGrantPending'] as bool,
    );
  }

  final String adEventId;
  final String placement;
  final String kind;
  final String learningDay;
  final int dailyIndex;
  final int remainingToday;
  final int rewardGems;
  final int rewardEnergy;
  final int gems;
  final bool energyGrantPending;

  Map<String, Object?> toJson() => <String, Object?>{
        'adEventId': adEventId,
        'placement': placement,
        'kind': kind,
        'learningDay': learningDay,
        'dailyIndex': dailyIndex,
        'remainingToday': remainingToday,
        'rewardGems': rewardGems,
        'rewardEnergy': rewardEnergy,
        'gems': gems,
        'energyGrantPending': energyGrantPending,
      };
}

/// Wire DTO for `#/components/schemas/ConversationFeedback`.
final class ConversationFeedback {
  const ConversationFeedback({
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.usedWords,
  });

  /// Validates [json] against the `ConversationFeedback` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ConversationFeedback.fromJson(Object? json) {
    ContractValidator.instance.check('ConversationFeedback', json);
    return ConversationFeedback._decode(json);
  }

  static ConversationFeedback _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ConversationFeedback(
      summary: map['summary'] as String,
      strengths: List<String>.unmodifiable((map['strengths'] as List<Object?>).map((Object? x) => x as String)),
      improvements: List<String>.unmodifiable((map['improvements'] as List<Object?>).map((Object? x) => x as String)),
      usedWords: List<String>.unmodifiable((map['usedWords'] as List<Object?>).map((Object? x) => x as String)),
    );
  }

  final String summary;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> usedWords;

  Map<String, Object?> toJson() => <String, Object?>{
        'summary': summary,
        'strengths': List<Object?>.of(strengths),
        'improvements': List<Object?>.of(improvements),
        'usedWords': List<Object?>.of(usedWords),
      };
}

/// Wire DTO for `#/components/schemas/Conversation`.
final class Conversation {
  const Conversation({
    required this.conversationId,
    required this.kind,
    required this.courseId,
    required this.scenarioId,
    required this.voiceSessionId,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    required this.turnCount,
    required this.wordsUsed,
    required this.stars,
    required this.xpAwarded,
    required this.feedback,
    required this.expiresAt,
  });

  /// Validates [json] against the `Conversation` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory Conversation.fromJson(Object? json) {
    ContractValidator.instance.check('Conversation', json);
    return Conversation._decode(json);
  }

  static Conversation _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return Conversation(
      conversationId: map['conversationId'] as String,
      kind: map['kind'] as String,
      courseId: map['courseId'] as String,
      scenarioId: map['scenarioId'] as String,
      voiceSessionId: map['voiceSessionId'] == null ? null : map['voiceSessionId'] as String,
      status: map['status'] as String,
      startedAt: map['startedAt'] as String,
      completedAt: map['completedAt'] == null ? null : map['completedAt'] as String,
      turnCount: (map['turnCount'] as num).toInt(),
      wordsUsed: (map['wordsUsed'] as num).toInt(),
      stars: (map['stars'] as num).toInt(),
      xpAwarded: (map['xpAwarded'] as num).toInt(),
      feedback: map['feedback'] == null ? null : ConversationFeedback._decode(map['feedback']),
      expiresAt: map['expiresAt'] as String,
    );
  }

  final String conversationId;
  final String kind;
  final String courseId;
  final String scenarioId;
  final String? voiceSessionId;
  final String status;
  final String startedAt;
  final String? completedAt;
  final int turnCount;
  final int wordsUsed;
  final int stars;
  final int xpAwarded;
  final ConversationFeedback? feedback;
  final String expiresAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'conversationId': conversationId,
        'kind': kind,
        'courseId': courseId,
        'scenarioId': scenarioId,
        'voiceSessionId': voiceSessionId,
        'status': status,
        'startedAt': startedAt,
        'completedAt': completedAt,
        'turnCount': turnCount,
        'wordsUsed': wordsUsed,
        'stars': stars,
        'xpAwarded': xpAwarded,
        'feedback': feedback?.toJson(),
        'expiresAt': expiresAt,
      };
}

/// Wire DTO for `#/components/schemas/ConversationPage`.
final class ConversationPage {
  const ConversationPage({
    required this.items,
    required this.nextCursor,
    required this.asOf,
  });

  /// Validates [json] against the `ConversationPage` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ConversationPage.fromJson(Object? json) {
    ContractValidator.instance.check('ConversationPage', json);
    return ConversationPage._decode(json);
  }

  static ConversationPage _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ConversationPage(
      items: List<Conversation>.unmodifiable((map['items'] as List<Object?>).map((Object? x) => Conversation._decode(x))),
      nextCursor: map['nextCursor'] == null ? null : map['nextCursor'] as String,
      asOf: map['asOf'] as String,
    );
  }

  final List<Conversation> items;
  final String? nextCursor;
  final String asOf;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((Conversation x) => x.toJson()).toList(),
        'nextCursor': nextCursor,
        'asOf': asOf,
      };
}

/// Wire DTO for `#/components/schemas/ConversationStartRequest`.
final class ConversationStartRequest {
  const ConversationStartRequest({
    required this.kind,
    required this.courseId,
    required this.scenarioId,
    required this.voiceSessionId,
  });

  /// Validates [json] against the `ConversationStartRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ConversationStartRequest.fromJson(Object? json) {
    ContractValidator.instance.check('ConversationStartRequest', json);
    return ConversationStartRequest._decode(json);
  }

  static ConversationStartRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ConversationStartRequest(
      kind: map['kind'] as String,
      courseId: map['courseId'] as String,
      scenarioId: map['scenarioId'] as String,
      voiceSessionId: map['voiceSessionId'] == null ? null : map['voiceSessionId'] as String,
    );
  }

  final String kind;
  final String courseId;
  final String scenarioId;
  final String? voiceSessionId;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'courseId': courseId,
        'scenarioId': scenarioId,
        'voiceSessionId': voiceSessionId,
      };
}

/// Wire DTO for `#/components/schemas/ConversationCompleteRequest`.
final class ConversationCompleteRequest {
  const ConversationCompleteRequest({
    required this.endReason,
  });

  /// Validates [json] against the `ConversationCompleteRequest` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory ConversationCompleteRequest.fromJson(Object? json) {
    ContractValidator.instance.check('ConversationCompleteRequest', json);
    return ConversationCompleteRequest._decode(json);
  }

  static ConversationCompleteRequest _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return ConversationCompleteRequest(
      endReason: map['endReason'] as String,
    );
  }

  final String endReason;

  Map<String, Object?> toJson() => <String, Object?>{
        'endReason': endReason,
      };
}

/// Wire DTO for `#/components/schemas/AiPracticeEventPayload`.
final class AiPracticeEventPayload {
  const AiPracticeEventPayload({
    required this.completionId,
    required this.userId,
    required this.kind,
    required this.courseId,
    required this.scenarioId,
    required this.xp,
    required this.wordsUsed,
    required this.stars,
  });

  /// Validates [json] against the `AiPracticeEventPayload` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory AiPracticeEventPayload.fromJson(Object? json) {
    ContractValidator.instance.check('AiPracticeEventPayload', json);
    return AiPracticeEventPayload._decode(json);
  }

  static AiPracticeEventPayload _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return AiPracticeEventPayload(
      completionId: map['completionId'] as String,
      userId: map['userId'] as String,
      kind: map['kind'] as String,
      courseId: map['courseId'] as String,
      scenarioId: map['scenarioId'] as String,
      xp: (map['xp'] as num).toInt(),
      wordsUsed: (map['wordsUsed'] as num).toInt(),
      stars: (map['stars'] as num).toInt(),
    );
  }

  final String completionId;
  final String userId;
  final String kind;
  final String courseId;
  final String scenarioId;
  final int xp;
  final int wordsUsed;
  final int stars;

  Map<String, Object?> toJson() => <String, Object?>{
        'completionId': completionId,
        'userId': userId,
        'kind': kind,
        'courseId': courseId,
        'scenarioId': scenarioId,
        'xp': xp,
        'wordsUsed': wordsUsed,
        'stars': stars,
      };
}

/// Wire DTO for `#/components/schemas/EntitlementEventPayload`.
final class EntitlementEventPayload {
  const EntitlementEventPayload({
    required this.userId,
    required this.plan,
    required this.status,
    required this.expiresAt,
    required this.entitlementRevision,
  });

  /// Validates [json] against the `EntitlementEventPayload` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory EntitlementEventPayload.fromJson(Object? json) {
    ContractValidator.instance.check('EntitlementEventPayload', json);
    return EntitlementEventPayload._decode(json);
  }

  static EntitlementEventPayload _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return EntitlementEventPayload(
      userId: map['userId'] as String,
      plan: map['plan'] as String,
      status: map['status'] as String,
      expiresAt: map['expiresAt'] == null ? null : map['expiresAt'] as String,
      entitlementRevision: (map['entitlementRevision'] as num).toInt(),
    );
  }

  final String userId;
  final String plan;
  final String status;
  final String? expiresAt;
  final int entitlementRevision;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'plan': plan,
        'status': status,
        'expiresAt': expiresAt,
        'entitlementRevision': entitlementRevision,
      };
}

/// Wire DTO for `#/components/schemas/EnergyGrantedEventPayload`.
final class EnergyGrantedEventPayload {
  const EnergyGrantedEventPayload({
    required this.operationId,
    required this.userId,
    required this.amount,
    required this.refillToCapacity,
    required this.reason,
  });

  /// Validates [json] against the `EnergyGrantedEventPayload` schema, then decodes it.
  /// Throws [ContractViolation] when the payload does not match the contract.
  factory EnergyGrantedEventPayload.fromJson(Object? json) {
    ContractValidator.instance.check('EnergyGrantedEventPayload', json);
    return EnergyGrantedEventPayload._decode(json);
  }

  static EnergyGrantedEventPayload _decode(Object? json) {
    final Map<Object?, Object?> map = json as Map<Object?, Object?>;
    return EnergyGrantedEventPayload(
      operationId: map['operationId'] as String,
      userId: map['userId'] as String,
      amount: map['amount'] == null ? null : (map['amount'] as num).toInt(),
      refillToCapacity: map['refillToCapacity'] as bool,
      reason: map['reason'] as String,
    );
  }

  final String operationId;
  final String userId;
  final int? amount;
  final bool refillToCapacity;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'operationId': operationId,
        'userId': userId,
        'amount': amount,
        'refillToCapacity': refillToCapacity,
        'reason': reason,
      };
}

/// Decoders for every `#/components/schemas` entry, keyed by schema name.
const Map<String, Object Function(Object?)> apiContractDecoders =
    <String, Object Function(Object?)>{
  'Error': Error.fromJson,
  'Health': Health.fromJson,
  'Prompt': Prompt.fromJson,
  'Asset': Asset.fromJson,
  'Choice': Choice.fromJson,
  'Token': Token.fromJson,
  'Pair': Pair.fromJson,
  'TextContent': TextContent.fromJson,
  'ChoiceContent': ChoiceContent.fromJson,
  'TokenContent': TokenContent.fromJson,
  'PairContent': PairContent.fromJson,
  'SpeechContent': SpeechContent.fromJson,
  'StoryContent': StoryContent.fromJson,
  'GradingRule': GradingRule.fromJson,
  'ExerciseBase': ExerciseBase.fromJson,
  'TextTranslationExercise': TextTranslationExercise.fromJson,
  'ChoiceExercise': ChoiceExercise.fromJson,
  'WordBankExercise': WordBankExercise.fromJson,
  'SentenceOrderExercise': SentenceOrderExercise.fromJson,
  'FillBlankExercise': FillBlankExercise.fromJson,
  'MatchPairsExercise': MatchPairsExercise.fromJson,
  'ImageChoiceExercise': ImageChoiceExercise.fromJson,
  'ListenChoiceExercise': ListenChoiceExercise.fromJson,
  'DictationExercise': DictationExercise.fromJson,
  'SpeakRepeatExercise': SpeakRepeatExercise.fromJson,
  'DialogueTurnExercise': DialogueTurnExercise.fromJson,
  'StoryQuestionExercise': StoryQuestionExercise.fromJson,
  'Exercise': Exercise.fromJson,
  'LessonBundle': LessonBundle.fromJson,
  'Course': Course.fromJson,
  'Enrollment': Enrollment.fromJson,
  'Node': Node.fromJson,
  'Path': Path.fromJson,
  'ContentNode': ContentNode.fromJson,
  'ContentSection': ContentSection.fromJson,
  'ContentUnit': ContentUnit.fromJson,
  'BundleIndex': BundleIndex.fromJson,
  'CourseManifest': CourseManifest.fromJson,
  'EnrollRequest': EnrollRequest.fromJson,
  'SessionRequest': SessionRequest.fromJson,
  'Session': Session.fromJson,
  'TextAnswer': TextAnswer.fromJson,
  'ChoiceAnswer': ChoiceAnswer.fromJson,
  'TokenAnswer': TokenAnswer.fromJson,
  'PairAnswer': PairAnswer.fromJson,
  'SpeechAnswer': SpeechAnswer.fromJson,
  'Answer': Answer.fromJson,
  'AnswerRequest': AnswerRequest.fromJson,
  'AnswerResult': AnswerResult.fromJson,
  'CompleteRequest': CompleteRequest.fromJson,
  'Completion': Completion.fromJson,
  'OfflineAnswer': OfflineAnswer.fromJson,
  'OfflineCompletionRequest': OfflineCompletionRequest.fromJson,
  'ReportRequest': ReportRequest.fromJson,
  'Receipt': Receipt.fromJson,
  'ReviewItem': ReviewItem.fromJson,
  'PublishRequest': PublishRequest.fromJson,
  'Profile': Profile.fromJson,
  'ProfilePatch': ProfilePatch.fromJson,
  'PublicProfile': PublicProfile.fromJson,
  'Rewards': Rewards.fromJson,
  'Quest': Quest.fromJson,
  'QuestClaimRequest': QuestClaimRequest.fromJson,
  'FollowRequest': FollowRequest.fromJson,
  'LeagueMember': LeagueMember.fromJson,
  'League': League.fromJson,
  'Activity': Activity.fromJson,
  'DeletionReceipt': DeletionReceipt.fromJson,
  'DeletionRequest': DeletionRequest.fromJson,
  'Capabilities': Capabilities.fromJson,
  'TutorRequest': TutorRequest.fromJson,
  'TutorResult': TutorResult.fromJson,
  'VoiceRequest': VoiceRequest.fromJson,
  'VoiceLease': VoiceLease.fromJson,
  'LiveVoiceLease': LiveVoiceLease.fromJson,
  'TurnVoiceLease': TurnVoiceLease.fromJson,
  'VoiceHeartbeat': VoiceHeartbeat.fromJson,
  'VoiceState': VoiceState.fromJson,
  'AssessmentRequest': AssessmentRequest.fromJson,
  'WordScore': WordScore.fromJson,
  'Assessment': Assessment.fromJson,
  'LessonEventPayload': LessonEventPayload.fromJson,
  'DeletionEventPayload': DeletionEventPayload.fromJson,
  'PurgeEventPayload': PurgeEventPayload.fromJson,
  'ZoneEventPayload': ZoneEventPayload.fromJson,
  'BusinessEvent': BusinessEvent.fromJson,
  'Watermark': Watermark.fromJson,
  'TurnRequest': TurnRequest.fromJson,
  'TurnResult': TurnResult.fromJson,
  'CoursePage': CoursePage.fromJson,
  'ReviewPage': ReviewPage.fromJson,
  'QuestPage': QuestPage.fromJson,
  'ProfilePage': ProfilePage.fromJson,
  'ActivityPage': ActivityPage.fromJson,
  'Energy': Energy.fromJson,
  'EnrollmentCommandRequest': EnrollmentCommandRequest.fromJson,
  'Mistake': Mistake.fromJson,
  'MistakePage': MistakePage.fromJson,
  'Word': Word.fromJson,
  'WordPage': WordPage.fromJson,
  'ActivityProgress': ActivityProgress.fromJson,
  'ActivityProgressPage': ActivityProgressPage.fromJson,
  'Preferences': Preferences.fromJson,
  'PreferencesPatch': PreferencesPatch.fromJson,
  'FeedbackRequest': FeedbackRequest.fromJson,
  'InventoryItem': InventoryItem.fromJson,
  'ShopItem': ShopItem.fromJson,
  'Shop': Shop.fromJson,
  'ShopPurchaseRequest': ShopPurchaseRequest.fromJson,
  'ShopPurchase': ShopPurchase.fromJson,
  'BoostRequest': BoostRequest.fromJson,
  'Boost': Boost.fromJson,
  'StreakRepairRequest': StreakRepairRequest.fromJson,
  'FriendStreak': FriendStreak.fromJson,
  'FriendStreakPage': FriendStreakPage.fromJson,
  'FriendStreakInviteRequest': FriendStreakInviteRequest.fromJson,
  'FriendStreakResponseRequest': FriendStreakResponseRequest.fromJson,
  'InteractionRequest': InteractionRequest.fromJson,
  'Interaction': Interaction.fromJson,
  'BlockRequest': BlockRequest.fromJson,
  'UserReportRequest': UserReportRequest.fromJson,
  'ClassroomJoinRequest': ClassroomJoinRequest.fromJson,
  'ClassroomMembership': ClassroomMembership.fromJson,
  'YearReview': YearReview.fromJson,
  'LeagueWeekResult': LeagueWeekResult.fromJson,
  'LeagueResult': LeagueResult.fromJson,
  'LeagueResultSeenRequest': LeagueResultSeenRequest.fromJson,
  'Entitlement': Entitlement.fromJson,
  'PurchaseRequest': PurchaseRequest.fromJson,
  'Purchase': Purchase.fromJson,
  'BillingNotification': BillingNotification.fromJson,
  'FamilyMember': FamilyMember.fromJson,
  'FamilyGroup': FamilyGroup.fromJson,
  'FamilyCreateRequest': FamilyCreateRequest.fromJson,
  'FamilyJoinRequest': FamilyJoinRequest.fromJson,
  'GiftRequest': GiftRequest.fromJson,
  'Gift': Gift.fromJson,
  'Referral': Referral.fromJson,
  'ReferralRedeemRequest': ReferralRedeemRequest.fromJson,
  'PromoRedeemRequest': PromoRedeemRequest.fromJson,
  'PromoRedemption': PromoRedemption.fromJson,
  'AdEventRequest': AdEventRequest.fromJson,
  'AdEvent': AdEvent.fromJson,
  'ConversationFeedback': ConversationFeedback.fromJson,
  'Conversation': Conversation.fromJson,
  'ConversationPage': ConversationPage.fromJson,
  'ConversationStartRequest': ConversationStartRequest.fromJson,
  'ConversationCompleteRequest': ConversationCompleteRequest.fromJson,
  'AiPracticeEventPayload': AiPracticeEventPayload.fromJson,
  'EntitlementEventPayload': EntitlementEventPayload.fromJson,
  'EnergyGrantedEventPayload': EnergyGrantedEventPayload.fromJson,
};
