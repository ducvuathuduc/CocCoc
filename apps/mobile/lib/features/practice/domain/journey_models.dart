import '../../roleplay/domain/roleplay_models.dart';

enum JourneyKind { reading, choice, word, bank, pairs, multi }

class JourneyQuestion {
  const JourneyQuestion(
    this.kind,
    this.prompt,
    this.options,
    this.answer, {
    this.transcript = '',
    this.translation = '',
  });
  final JourneyKind kind;
  final String prompt, transcript, translation;
  final List<String> options, answer;
}

class JourneyState {
  const JourneyState({
    this.storyId = 'family',
    this.started = false,
    this.step = 0,
    this.complete = false,
    this.selected = const [],
    this.matched = const {},
    this.feedback,
    this.correct = 0,
    this.attempted = 0,
    this.draft = '',
    this.replies = const [],
    this.error,
    this.remaining = 105,
    this.expired = false,
    this.milestoneSeen = false,
    this.scenarioId,
    this.introSeen = false,
    this.partnerLines = const {},
    this.waiting = false,
    this.maxRequired = false,
  });

  /// Roleplay (API mode): server partner lines by step, overriding the
  /// scenario's scripted prompt with what the server actually replied.
  final Map<int, RoleplayLine> partnerLines;

  /// Roleplay (API mode): a learner turn is with the server.
  final bool waiting;

  /// Roleplay (API mode): the plan lacks Roleplay (`ENTITLEMENT_REQUIRED`);
  /// the session hands over to the existing Max upsell.
  final bool maxRequired;

  /// Roleplay scenario picked from the Roleplay library. Null keeps the
  /// original practice-hub restaurant flow.
  final String? scenarioId;
  final bool introSeen;
  final bool started, complete, expired, milestoneSeen;
  final int remaining;
  final int step, correct, attempted;
  final List<String> selected, replies;
  final Set<String> matched;
  final bool? feedback;
  final String draft;
  final String storyId;
  final String? error;
  JourneyState copyWith({
    String? storyId,
    bool? started,
    bool? complete,
    int? step,
    int? correct,
    int? attempted,
    List<String>? selected,
    Set<String>? matched,
    bool? feedback,
    bool clearFeedback = false,
    String? draft,
    List<String>? replies,
    String? error,
    bool clearError = false,
    int? remaining,
    bool? expired,
    bool? milestoneSeen,
    bool? introSeen,
    Map<int, RoleplayLine>? partnerLines,
    bool? waiting,
    bool? maxRequired,
  }) => JourneyState(
    scenarioId: scenarioId,
    partnerLines: Map.unmodifiable(partnerLines ?? this.partnerLines),
    waiting: waiting ?? this.waiting,
    maxRequired: maxRequired ?? this.maxRequired,
    introSeen: introSeen ?? this.introSeen,
    storyId: storyId ?? this.storyId,
    started: started ?? this.started,
    complete: complete ?? this.complete,
    step: step ?? this.step,
    correct: correct ?? this.correct,
    attempted: attempted ?? this.attempted,
    selected: List.unmodifiable(selected ?? this.selected),
    matched: Set.unmodifiable(matched ?? this.matched),
    feedback: clearFeedback ? null : feedback ?? this.feedback,
    draft: draft ?? this.draft,
    replies: List.unmodifiable(replies ?? this.replies),
    error: clearError ? null : error ?? this.error,
    remaining: remaining ?? this.remaining,
    expired: expired ?? this.expired,
    milestoneSeen: milestoneSeen ?? this.milestoneSeen,
  );
}
