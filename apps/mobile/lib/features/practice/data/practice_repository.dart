import '../domain/practice_models.dart';

abstract class PracticeRepository {
  List<PracticeWord> loadWords();
}

class MockPracticeRepository implements PracticeRepository {
  const MockPracticeRepository();

  @override
  List<PracticeWord> loadWords() => mockPracticeWords;
}

const mockPracticeWords = <PracticeWord>[
  PracticeWord(id: 'woman', term: 'woman', meaning: 'người phụ nữ'),
  PracticeWord(id: 'hello', term: 'hello', meaning: 'xin chào'),
  PracticeWord(id: 'bear', term: 'bear', meaning: 'con gấu'),
  PracticeWord(id: 'thank-you', term: 'thank you', meaning: 'cảm ơn'),
];

const mockCallOpening = <ConversationLine>[
  ConversationLine(speaker: 'Lily', text: 'Hello.'),
];
