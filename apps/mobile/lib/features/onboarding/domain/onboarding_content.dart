import 'onboarding_state.dart';

/// How a run of mascot copy is emphasised.
enum PromptEmphasis { none, bold, accent }

/// One run of mascot speech. `{language}` is replaced with the chosen course.
class PromptSegment {
  const PromptSegment(this.text, [this.emphasis = PromptEmphasis.none]);
  final String text;
  final PromptEmphasis emphasis;

  PromptSegment resolve(String language) =>
      PromptSegment(text.replaceAll('{language}', language), emphasis);
}

typedef Prompt = List<PromptSegment>;

class LanguageOption {
  const LanguageOption({required this.name, this.flagIndex});
  final String name;

  /// Index into the reference flag art; null renders the vector flag.
  final int? flagIndex;
}

class LabeledOption {
  const LabeledOption({required this.label, required this.artIndex});
  final String label;
  final int artIndex;
}

class GoalOption {
  const GoalOption({required this.minutes, required this.intensity});
  final int minutes;
  final String intensity;
}

class DetailOption {
  const DetailOption({
    required this.value,
    required this.title,
    required this.subtitle,
    this.recommended = false,
  });
  final int value;
  final String title;
  final String subtitle;
  final bool recommended;
}

class BenefitItem {
  const BenefitItem({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

class DialogCopy {
  const DialogCopy({
    required this.title,
    required this.body,
    required this.cancel,
    required this.confirm,
  });
  final String title;
  final String body;
  final String cancel;
  final String confirm;
}

class NotificationPreviewCopy {
  const NotificationPreviewCopy({
    required this.title,
    required this.body,
    required this.deny,
    required this.allow,
  });
  final String title;
  final String body;
  final String deny;
  final String allow;
}

/// Everything the onboarding screens display. Screens never hold copy.
class OnboardingContent {
  const OnboardingContent({
    required this.welcomeTagline,
    required this.getStartedLabel,
    required this.haveAccountLabel,
    required this.sourceLanguageHeader,
    required this.fallbackLanguage,
    required this.languages,
    required this.knowledgeLevels,
    required this.reasons,
    required this.goals,
    required this.benefits,
    required this.plans,
    required this.startOptions,
    required this.prompts,
    required this.alternatePrompts,
    required this.buttonLabels,
    required this.defaultButtonLabel,
    required this.savingLabel,
    required this.notNowLabel,
    required this.saveErrorText,
    required this.retryLabel,
    required this.buildingTitle,
    required this.buildingBody,
    required this.notificationPreview,
    required this.reminderDialog,
    required this.superDialog,
    required this.progress,
  });

  final String welcomeTagline;
  final String getStartedLabel;
  final String haveAccountLabel;
  final String sourceLanguageHeader;
  final String fallbackLanguage;
  final List<LanguageOption> languages;
  final List<String> knowledgeLevels;
  final List<LabeledOption> reasons;
  final List<GoalOption> goals;
  final List<BenefitItem> benefits;
  final List<DetailOption> plans;
  final List<DetailOption> startOptions;
  final Map<OnboardingStep, Prompt> prompts;

  /// Prompts shown once the learner has answered the step.
  final Map<OnboardingStep, Prompt> alternatePrompts;
  final Map<OnboardingStep, String> buttonLabels;
  final String defaultButtonLabel;
  final String savingLabel;
  final String notNowLabel;
  final String saveErrorText;
  final String retryLabel;
  final String buildingTitle;
  final Prompt buildingBody;
  final NotificationPreviewCopy notificationPreview;
  final DialogCopy reminderDialog;
  final DialogCopy superDialog;
  final Map<OnboardingStep, double> progress;

  String buttonLabel(OnboardingStep step) =>
      buttonLabels[step] ?? defaultButtonLabel;

  Prompt prompt(OnboardingStep step, String language, {bool answered = false}) {
    final source = (answered ? alternatePrompts[step] : null) ?? prompts[step];
    return [
      for (final s in source ?? const <PromptSegment>[]) s.resolve(language),
    ];
  }
}
