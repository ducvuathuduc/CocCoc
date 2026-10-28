/// Session modes the Learning service accepts (SRS §Authored activity session
/// modes). The four legacy modes and the eight authored modes share one
/// lifecycle; only the authored modes are routed through [isAuthored].
enum SessionMode {
  lesson('LESSON'),
  review('REVIEW'),
  mastery('MASTERY'),
  placement('PLACEMENT'),
  stories('STORIES'),
  adventure('ADVENTURE'),
  radio('RADIO'),
  sideQuest('SIDE_QUEST'),
  clash('CLASH'),
  unitReview('UNIT_REVIEW'),
  testOut('TEST_OUT'),
  checkpoint('CHECKPOINT');

  const SessionMode(this.wireName);

  final String wireName;

  static SessionMode? tryParse(String? wireName) => switch (wireName) {
    'LESSON' => lesson,
    'REVIEW' => review,
    'MASTERY' => mastery,
    'PLACEMENT' => placement,
    'STORIES' => stories,
    'ADVENTURE' => adventure,
    'RADIO' => radio,
    'SIDE_QUEST' => sideQuest,
    'CLASH' => clash,
    'UNIT_REVIEW' => unitReview,
    'TEST_OUT' => testOut,
    'CHECKPOINT' => checkpoint,
    _ => null,
  };

  /// The eight 2026-10-28 authored modes that reuse the exercise flow.
  bool get isAuthored => switch (this) {
    stories ||
    adventure ||
    radio ||
    sideQuest ||
    clash ||
    unitReview ||
    testOut ||
    checkpoint => true,
    lesson || review || mastery || placement => false,
  };

  /// TEST_OUT and CHECKPOINT are server-graded pass/fail gates with no reward.
  bool get isGate => this == testOut || this == checkpoint;

  /// LESSON is the only mode with an offline completion journal.
  bool get isOnlineOnly => this != lesson;
}
