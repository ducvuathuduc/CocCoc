enum OnboardingStep {
  welcome,
  greeting,
  questions,
  language,
  building,
  knowledge,
  reasons,
  routine,
  goal,
  promise,
  reminder,
  widget,
  benefits,
  plan,
  startPoint,
  levelConfirmation,
  lessonEntry,
}

const languages = [
  'Spanish',
  'French',
  'German',
  'Italian',
  'Intermediate English',
  'Japanese',
  'Chinese',
];
const reasons = [
  'Just for fun',
  'Boost my career',
  'Spend time productively',
  'Connect with people',
  'Prepare for travel',
  'Support my education',
  'Other',
];
const goalMinutes = [5, 10, 15, 20];

class OnboardingState {
  OnboardingState({
    this.step = OnboardingStep.welcome,
    this.language,
    this.knowledge = -1,
    Set<int> reasonIds = const {},
    this.goal = 10,
    this.reminders,
    this.widgetRequested,
    this.plan = -1,
    this.startPoint = -1,
  }) : reasonIds = Set.unmodifiable(reasonIds);

  final OnboardingStep step;
  final String? language;
  final int knowledge;
  final Set<int> reasonIds;
  final int goal;
  final bool? reminders;
  final bool? widgetRequested;
  final int plan;
  final int startPoint;

  bool get canContinue => switch (step) {
    OnboardingStep.language => language != null,
    OnboardingStep.knowledge => knowledge >= 0,
    OnboardingStep.reasons => reasonIds.isNotEmpty,
    OnboardingStep.plan => plan >= 0,
    OnboardingStep.startPoint => startPoint >= 0,
    OnboardingStep.reminder => reminders != null,
    OnboardingStep.widget => widgetRequested != null,
    OnboardingStep.building || OnboardingStep.lessonEntry => false,
    _ => true,
  };

  OnboardingState copyWith({
    OnboardingStep? step,
    String? language,
    int? knowledge,
    Set<int>? reasonIds,
    int? goal,
    bool? reminders,
    bool? widgetRequested,
    int? plan,
    int? startPoint,
  }) => OnboardingState(
    step: step ?? this.step,
    language: language ?? this.language,
    knowledge: knowledge ?? this.knowledge,
    reasonIds: reasonIds ?? this.reasonIds,
    goal: goal ?? this.goal,
    reminders: reminders ?? this.reminders,
    widgetRequested: widgetRequested ?? this.widgetRequested,
    plan: plan ?? this.plan,
    startPoint: startPoint ?? this.startPoint,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'step': step.name,
    'language': language,
    'knowledge': knowledge,
    'reasons': reasonIds.toList()..sort(),
    'goal': goal,
    'reminders': reminders,
    'widgetRequested': widgetRequested,
    'plan': plan,
    'startPoint': startPoint,
  };

  static OnboardingState fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) return OnboardingState();
    try {
      final step = OnboardingStep.values.byName(json['step'] as String);
      final language = json['language'] as String?;
      final knowledge = json['knowledge'] as int;
      final ids = (json['reasons'] as List).cast<int>().toSet();
      final goal = json['goal'] as int;
      final plan = json['plan'] as int;
      final start = json['startPoint'] as int;
      if ((language != null && !languages.contains(language)) ||
          knowledge < -1 ||
          knowledge > 4 ||
          ids.any((id) => id < 0 || id >= reasons.length) ||
          !goalMinutes.contains(goal) ||
          plan < -1 ||
          plan > 1 ||
          start < -1 ||
          start > 1) {
        return OnboardingState();
      }
      final restored = OnboardingState(
        step: step,
        language: language,
        knowledge: knowledge,
        reasonIds: ids,
        goal: goal,
        reminders: json['reminders'] as bool?,
        widgetRequested: json['widgetRequested'] as bool?,
        plan: plan,
        startPoint: start,
      );
      // Resume at the first missing answer, preserving everything else.
      final required = <OnboardingStep, bool>{
        OnboardingStep.language: language != null,
        OnboardingStep.knowledge: knowledge >= 0,
        OnboardingStep.reasons: ids.isNotEmpty,
        OnboardingStep.reminder: restored.reminders != null,
        OnboardingStep.widget: restored.widgetRequested != null,
        OnboardingStep.plan: plan >= 0,
        OnboardingStep.startPoint: start >= 0,
      };
      for (final entry in required.entries) {
        if (step.index > entry.key.index && !entry.value) {
          return restored.copyWith(step: entry.key);
        }
      }
      return restored;
    } on Object {
      return OnboardingState();
    }
  }
}
