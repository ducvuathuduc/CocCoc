import '../domain/onboarding_content.dart';
import '../domain/onboarding_state.dart';

/// Source of onboarding copy and options. Swap the provider for an API impl.
abstract interface class OnboardingContentRepository {
  OnboardingContent loadContent();
}

class MockOnboardingContentRepository implements OnboardingContentRepository {
  const MockOnboardingContentRepository();

  @override
  OnboardingContent loadContent() => mockOnboardingContent;
}

const _b = PromptEmphasis.bold;

/// Copy transcribed from the Gummble Duolingo iOS onboarding flow
/// (docs/design/references/onboarding/01-20.png).
const mockOnboardingContent = OnboardingContent(
  welcomeTagline: 'Learn for free. Forever.',
  getStartedLabel: 'GET STARTED',
  haveAccountLabel: 'I ALREADY HAVE AN ACCOUNT',
  sourceLanguageHeader: 'For English speakers',
  fallbackLanguage: 'English',
  languages: [
    LanguageOption(name: 'Spanish', flagIndex: 0),
    LanguageOption(name: 'French', flagIndex: 1),
    LanguageOption(name: 'German', flagIndex: 2),
    LanguageOption(name: 'Italian', flagIndex: 3),
    LanguageOption(name: 'Intermediate English', flagIndex: 4),
    LanguageOption(name: 'Japanese', flagIndex: 5),
    LanguageOption(name: 'Chinese'),
  ],
  knowledgeLevels: [
    'I’m new to {language}',
    'I know some common words',
    'I can have basic conversations',
    'I can talk about various topics',
    'I can discuss most topics in detail',
  ],
  reasons: [
    LabeledOption(label: 'Just for fun', artIndex: 0),
    LabeledOption(label: 'Boost my career', artIndex: 1),
    LabeledOption(label: 'Spend time productively', artIndex: 2),
    LabeledOption(label: 'Connect with people', artIndex: 3),
    LabeledOption(label: 'Prepare for travel', artIndex: 4),
    LabeledOption(label: 'Support my education', artIndex: 5),
    LabeledOption(label: 'Other', artIndex: 6),
  ],
  goals: [
    GoalOption(minutes: 5, intensity: 'Casual'),
    GoalOption(minutes: 10, intensity: 'Regular'),
    GoalOption(minutes: 15, intensity: 'Serious'),
    GoalOption(minutes: 20, intensity: 'Intense'),
  ],
  benefits: [
    BenefitItem(
      title: 'Converse with confidence',
      subtitle: 'Stress-free speaking and listening exercises',
    ),
    BenefitItem(
      title: 'Build up your vocabulary',
      subtitle: 'Common words and practical phrases',
    ),
    BenefitItem(
      title: 'Develop a learning habit',
      subtitle: 'Smart reminders, fun challenges, and more',
    ),
  ],
  plans: [
    DetailOption(
      value: 1,
      title: 'Super Duolingo',
      subtitle: 'Faster progress, no ads',
      recommended: true,
    ),
    DetailOption(
      value: 0,
      title: 'Learn for free',
      subtitle: 'Core learning features, with ads',
    ),
  ],
  startOptions: [
    DetailOption(
      value: 0,
      title: 'Start from scratch',
      subtitle: 'Take the easiest lesson of the {language} course',
    ),
    DetailOption(
      value: 1,
      title: 'Find my level',
      subtitle: 'Let Duo recommend where you should start learning',
      recommended: true,
    ),
  ],
  prompts: {
    OnboardingStep.greeting: [PromptSegment('Hi there! I’m Duo!')],
    OnboardingStep.questions: [
      PromptSegment('Just '),
      PromptSegment('7 quick questions', _b),
      PromptSegment(' before we start your first lesson!'),
    ],
    OnboardingStep.language: [PromptSegment('What would you like to learn?')],
    OnboardingStep.knowledge: [
      PromptSegment('How much {language} do you know?'),
    ],
    OnboardingStep.reasons: [PromptSegment('Why are you learning {language}?')],
    OnboardingStep.routine: [PromptSegment('Let’s set up a learning routine!')],
    OnboardingStep.goal: [PromptSegment('What’s your daily learning goal?')],
    OnboardingStep.promise: [
      PromptSegment('That’s '),
      PromptSegment('50 words', PromptEmphasis.accent),
      PromptSegment(' in your first week!'),
    ],
    OnboardingStep.reminder: [
      PromptSegment('I’ll remind you to practice so it becomes a habit!'),
    ],
    OnboardingStep.widget: [
      PromptSegment('I’ll cheer you on from your home screen!'),
    ],
    OnboardingStep.benefits: [
      PromptSegment('Here’s what you can achieve in 3 months!'),
    ],
    OnboardingStep.plan: [PromptSegment('How do you want to get started?')],
    OnboardingStep.startPoint: [
      PromptSegment('Where would you like to start?'),
    ],
    OnboardingStep.levelConfirmation: [
      PromptSegment('Since you know a few words, let’s start at '),
      PromptSegment('Score 10!', _b),
    ],
  },
  alternatePrompts: {
    OnboardingStep.reasons: [
      PromptSegment('Let’s prepare you for conversations!'),
    ],
    OnboardingStep.plan: [PromptSegment('Awesome! You can upgrade anytime.')],
    OnboardingStep.levelConfirmation: [
      PromptSegment('Let’s find the right place for you. Start at '),
      PromptSegment('Score 10!', _b),
    ],
  },
  buttonLabels: {
    OnboardingStep.goal: 'I’M COMMITTED',
    OnboardingStep.reminder: 'REMIND ME TO PRACTICE',
    OnboardingStep.widget: 'ADD WIDGET',
  },
  defaultButtonLabel: 'CONTINUE',
  savingLabel: 'SAVING…',
  notNowLabel: 'NOT NOW',
  saveErrorText: 'Couldn’t save your choices.',
  retryLabel: 'Retry',
  buildingTitle: 'COURSE BUILDING…',
  buildingBody: [
    PromptSegment('Get ready to join the '),
    PromptSegment('7 million people', _b),
    PromptSegment('\ncurrently learning {language} with\nDuolingo!'),
  ],
  notificationPreview: NotificationPreviewCopy(
    title: '“Duolingo” Would Like to Send You Notifications',
    body: 'Notifications may include alerts, sounds, and icon badges. These can be configured in Settings.',
    deny: 'Don’t Allow',
    allow: 'Allow',
  ),
  reminderDialog: DialogCopy(
    title: 'Practice reminders',
    body: 'Would you like a daily reminder? You can change this preference later.',
    cancel: 'Not now',
    confirm: 'Remind me',
  ),
  superDialog: DialogCopy(
    title: 'Super Duolingo',
    body: 'Explore the Super experience.',
    cancel: 'Go back',
    confirm: 'Continue',
  ),
  progress: {
    OnboardingStep.language: .055,
    OnboardingStep.knowledge: .166,
    OnboardingStep.reasons: .278,
    OnboardingStep.routine: .333,
    OnboardingStep.goal: .39,
    OnboardingStep.promise: .445,
    OnboardingStep.reminder: .50,
    OnboardingStep.widget: .556,
    OnboardingStep.benefits: .778,
    OnboardingStep.plan: .833,
    OnboardingStep.startPoint: .944,
  },
);
