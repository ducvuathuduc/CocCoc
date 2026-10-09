import '../domain/journey_models.dart';

class EnglishStory {
  const EnglishStory(this.id, this.title, this.questions);
  final String id, title;
  final List<JourneyQuestion> questions;
}

EnglishStory _story(
  String id,
  String title,
  String script,
  String translation,
  String statement,
  bool truth,
  String word,
  String meaning,
  String sentence,
) => EnglishStory(
  id,
  title,
  List.unmodifiable([
    JourneyQuestion(
      JourneyKind.reading,
      title,
      const [],
      const [],
      transcript: script,
      translation: translation,
    ),
    JourneyQuestion(
      JourneyKind.choice,
      statement,
      const ['True', 'False'],
      [truth ? 'True' : 'False'],
    ),
    JourneyQuestion(
      JourneyKind.word,
      'Select the word meaning “$meaning”.',
      List.unmodifiable({word, 'water', 'school', 'cat'}),
      [word],
    ),
    JourneyQuestion(
      JourneyKind.bank,
      'Form the sentence',
      List.unmodifiable(sentence.split(' ').reversed),
      List.unmodifiable(sentence.split(' ')),
    ),
  ]),
);

// Authored English samples; library titles/illustrations are reference-derived.
final englishStoryLibrary = Map<String, EnglishStory>.unmodifiable({
  'morning': _story(
    'morning',
    'Good Morning',
    'Eddy: Good morning!\nBarista: Would you like coffee?\nEddy: Yes, coffee, please.',
    'Chào buổi sáng! Bạn có muốn cà phê không? Có, cho tôi cà phê nhé.',
    'Eddy wants tea.',
    false,
    'coffee',
    'cà phê',
    'Coffee is good',
  ),
  'want': _story(
    'want',
    'What Do You Want?',
    'Oscar: What do you want?\nLucy: I want a book.\nOscar: This book is good.',
    'Bạn muốn gì? Tôi muốn một quyển sách. Quyển sách này hay.',
    'Lucy wants a book.',
    true,
    'book',
    'quyển sách',
    'The book is good',
  ),
  'jacket': _story(
    'jacket',
    'I Want This Jacket!',
    'Eddy: I want this jacket!\nJunior: It is red.\nEddy: Red is my favorite color.',
    'Tôi muốn chiếc áo khoác này! Nó màu đỏ. Đỏ là màu tôi thích nhất.',
    'The jacket is blue.',
    false,
    'jacket',
    'áo khoác',
    'I want this jacket',
  ),
  'student': _story(
    'student',
    'The New Student',
    'Lucy: Who is she?\nLily: She is a new student.\nLucy: Hello! Welcome to our school.',
    'Cô ấy là ai? Cô ấy là học sinh mới. Xin chào! Chào mừng đến trường của chúng tôi.',
    'She is a new student.',
    true,
    'student',
    'học sinh',
    'She is a student',
  ),
  'art': _story(
    'art',
    'This Is Not Art',
    'Oscar: Look at this painting.\nEddy: Is it a cat?\nOscar: No, it is a house!',
    'Nhìn bức tranh này. Nó là một con mèo à? Không, đó là một ngôi nhà!',
    'The painting shows a house.',
    true,
    'house',
    'ngôi nhà',
    'That painting is beautiful',
  ),
  'dog': _story(
    'dog',
    'I Really Want a Dog',
    'Junior: I really want a dog.\nEddy: Dogs need food and water.\nJunior: I can help!',
    'Con rất muốn có một chú chó. Chó cần thức ăn và nước. Con có thể giúp!',
    'Junior wants a cat.',
    false,
    'dog',
    'con chó',
    'I really want a dog',
  ),
  'ticket': _story(
    'ticket',
    'A Ticket to New York',
    'Junior: A ticket to New York, please.\nAgent: One ticket?\nJunior: Yes, one ticket. Thank you!',
    'Cho tôi một vé đến New York. Một vé phải không? Đúng, một vé. Cảm ơn!',
    'Junior asks for two tickets.',
    false,
    'ticket',
    'vé',
    'A ticket to New York',
  ),
  'family': const EnglishStory('family', 'A Big Family', []),
});
