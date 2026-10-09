enum UnitSkipStage {
  intro,
  answering,
  feedback,
  lastHeartWarning,
  failed,
  passed,
  unavailable,
}

class UnitSkipToken {
  const UnitSkipToken({required this.id, required this.text});

  final String id;
  final String text;
}

class UnitSkipQuestion {
  const UnitSkipQuestion({
    required this.id,
    required this.lesson,
    required this.prompt,
    required this.tokens,
    required this.answerTokenIds,
  }) : assert(id != ''),
       assert(lesson != ''),
       assert(prompt != '');

  final String id;
  final String lesson;
  final String prompt;
  final List<UnitSkipToken> tokens;
  final List<String> answerTokenIds;

  String get answerText {
    final answer = <String>[];
    for (final id in answerTokenIds) {
      for (final token in tokens) {
        if (token.id == id) {
          answer.add(token.text);
          break;
        }
      }
    }
    return answer.join(' ');
  }
}

class UnitSkipFixture {
  const UnitSkipFixture({required this.questions});

  final List<UnitSkipQuestion> questions;
}

class UnitSkipState {
  const UnitSkipState({
    required this.unit,
    required this.section,
    required this.sectionCheck,
    required this.questions,
    required this.stage,
    this.questionIndex = 0,
    this.selectedTokenIds = const <String>[],
    this.hearts = 5,
    this.correct,
    this.warningShown = false,
    this.passAcknowledged = false,
  });

  final int unit;
  final int section;
  final bool sectionCheck;
  final List<UnitSkipQuestion> questions;
  final UnitSkipStage stage;
  final int questionIndex;
  final List<String> selectedTokenIds;
  final int hearts;
  final bool? correct;
  final bool warningShown;
  final bool passAcknowledged;

  UnitSkipQuestion? get currentQuestion =>
      questionIndex >= 0 && questionIndex < questions.length
      ? questions[questionIndex]
      : null;

  bool get canCheck =>
      stage == UnitSkipStage.answering && selectedTokenIds.isNotEmpty;

  double get progress =>
      questions.isEmpty ? 0 : (questionIndex / questions.length).clamp(0, 1);
}

const authoredUnitSkipQuestions = <UnitSkipQuestion>[
  UnitSkipQuestion(
    id: 'travel-paris',
    lesson: 'Travel',
    prompt: 'Bạn có đang ghé thăm Paris không?',
    tokens: <UnitSkipToken>[
      UnitSkipToken(id: 'are', text: 'Are'),
      UnitSkipToken(id: 'you', text: 'you'),
      UnitSkipToken(id: 'visiting', text: 'visiting'),
      UnitSkipToken(id: 'paris', text: 'Paris?'),
      UnitSkipToken(id: 'like', text: 'like'),
      UnitSkipToken(id: 'talking', text: 'talking'),
    ],
    answerTokenIds: <String>['are', 'you', 'visiting', 'paris'],
  ),
  UnitSkipQuestion(
    id: 'school-english',
    lesson: 'School',
    prompt: 'Tôi thích học tiếng Anh.',
    tokens: <UnitSkipToken>[
      UnitSkipToken(id: 'i', text: 'I'),
      UnitSkipToken(id: 'like', text: 'like'),
      UnitSkipToken(id: 'learning', text: 'learning'),
      UnitSkipToken(id: 'english', text: 'English.'),
      UnitSkipToken(id: 'speaking', text: 'speaking'),
    ],
    answerTokenIds: <String>['i', 'like', 'learning', 'english'],
  ),
  UnitSkipQuestion(
    id: 'routine-breakfast',
    lesson: 'Daily routine',
    prompt: 'Chúng tôi ăn sáng lúc bảy giờ.',
    tokens: <UnitSkipToken>[
      UnitSkipToken(id: 'we', text: 'We'),
      UnitSkipToken(id: 'eat', text: 'eat'),
      UnitSkipToken(id: 'breakfast', text: 'breakfast'),
      UnitSkipToken(id: 'seven', text: 'at seven.'),
      UnitSkipToken(id: 'tomorrow', text: 'tomorrow'),
    ],
    answerTokenIds: <String>['we', 'eat', 'breakfast', 'seven'],
  ),
];
