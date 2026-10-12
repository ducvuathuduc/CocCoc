// Roleplay domain: topics hold scenarios; each scenario is a short scripted
// conversation with an in-scene character. Progress is tracked per scenario.

class RoleplayHint {
  const RoleplayHint(this.gloss, this.phrase);

  /// Vietnamese meaning shown small above the phrase.
  final String gloss;

  /// English phrase inserted into the reply when tapped.
  final String phrase;
}

class RoleplayLine {
  const RoleplayLine({
    required this.prompt,
    required this.translation,
    this.hints = const [],
    this.tip = '',
  });

  /// What the character says (English).
  final String prompt;

  /// Vietnamese translation revealed by TRANSLATE.
  final String translation;

  /// Word suggestions for the reply.
  final List<RoleplayHint> hints;

  /// Coaching note shown on the feedback screen under the learner's reply.
  final String tip;
}

enum RoleplayScene { restaurant, station }

class RoleplayScenario {
  const RoleplayScenario({
    required this.id,
    required this.topicId,
    required this.title,
    required this.setting,
    required this.wellDone,
    required this.takeaway,
    required this.pattern,
    required this.example,
    required this.lines,
    this.scene = RoleplayScene.station,
  });
  final String id, topicId, title;

  /// Intro card copy ("You're rushing to catch a flight…").
  final String setting;

  /// Copy on the "Well done!" card after the last reply.
  final String wellDone;

  /// Key takeaway sentence + pattern box on the feedback screen.
  final String takeaway, pattern, example;
  final List<RoleplayLine> lines;
  final RoleplayScene scene;
}

class RoleplayTopic {
  const RoleplayTopic({required this.id, required this.title});
  final String id, title;
}

class RoleplayProgress {
  const RoleplayProgress({
    this.stars = 0,
    this.bestWords = 0,
    this.completions = 0,
  });
  final int stars, bestWords, completions;
  bool get completed => completions > 0;
}

class RoleplayResult {
  const RoleplayResult({
    required this.scenarioId,
    required this.wordsUsed,
    required this.stars,
    required this.xp,
    required this.newRecord,
  });
  final String scenarioId;
  final int wordsUsed, stars, xp;
  final bool newRecord;
}

/// Scoring copied from the reference results: 11 words → 1 star / 20 XP,
/// 13 words → 2 stars / 30 XP; the intro promises "up to 40 XP and 3 stars".
int roleplayStarsFor(int words) => words >= 18
    ? 3
    : words >= 12
    ? 2
    : 1;
int roleplayXpFor(int stars) => 10 + 10 * stars;
int roleplayWordCount(Iterable<String> replies) => replies
    .expand((r) => r.trim().split(RegExp(r'\s+')))
    .where((w) => w.isNotEmpty)
    .length;

class RoleplayLibraryState {
  const RoleplayLibraryState({
    required this.progress,
    required this.featuredId,
    this.lastResult,
  });
  final Map<String, RoleplayProgress> progress;
  final String featuredId;
  final RoleplayResult? lastResult;
  RoleplayProgress progressOf(String id) =>
      progress[id] ?? const RoleplayProgress();
  RoleplayLibraryState copyWith({
    Map<String, RoleplayProgress>? progress,
    String? featuredId,
    RoleplayResult? lastResult,
  }) => RoleplayLibraryState(
    progress: Map.unmodifiable(progress ?? this.progress),
    featuredId: featuredId ?? this.featuredId,
    lastResult: lastResult ?? this.lastResult,
  );
}

/// A server-backed roleplay run (API mode): the conversation the learner's
/// turns advance.
class RoleplayLiveSession {
  const RoleplayLiveSession({
    required this.conversationId,
    required this.cardId,
    required this.serverScenarioId,
  });
  final String conversationId;

  /// Library card the learner picked.
  final String cardId;

  /// Server scenario the conversation runs on.
  final String serverScenarioId;
}

/// The server's answer to one learner turn.
class RoleplayTurn {
  const RoleplayTurn({
    required this.reply,
    required this.advanced,
    required this.explanation,
    this.correction,
  });

  /// Partner's next line (or "Let's try again…" / the closing line).
  final String reply;

  /// The turn was on topic and moved the script to its next step.
  final bool advanced;

  /// Vietnamese coaching for this step.
  final String explanation;

  /// Model answer when the turn was off topic.
  final String? correction;
}

/// Server-graded outcome of a completed roleplay.
class RoleplayServerResult {
  const RoleplayServerResult({
    required this.stars,
    required this.wordsUsed,
    required this.xp,
  });
  final int stars, wordsUsed, xp;
}

/// The plan does not include Roleplay / Video Call (`ENTITLEMENT_REQUIRED`):
/// the app routes to its existing Max upsell.
class MaxRequiredException implements Exception {
  const MaxRequiredException(this.feature);
  final String feature;
  @override
  String toString() => 'MaxRequiredException($feature)';
}

/// The server refused to complete because the script is unfinished
/// (`SESSION_INCOMPLETE`); [completedSteps] is where the server stands.
class RoleplayIncompleteException implements Exception {
  const RoleplayIncompleteException(this.completedSteps, this.requiredSteps);
  final int completedSteps, requiredSteps;
  @override
  String toString() =>
      'RoleplayIncompleteException($completedSteps/$requiredSteps)';
}
