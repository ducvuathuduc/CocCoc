// Authored English samples reuse the inspected archived course layout. These
// are local reading fixtures, never a curriculum/reward contract.
class GuidePhrase {
  const GuidePhrase(this.english, this.vietnamese);
  final String english;
  final String vietnamese;
}

class GrammarConcept {
  const GrammarConcept(this.title, this.explanation);
  final String title;
  final String explanation;
}

class CourseSection {
  const CourseSection(
    this.number,
    this.range,
    this.cefr,
    this.phrase,
    this.description,
    this.example,
    this.grammar,
  );
  final int number;
  final String range;
  final String cefr;
  final String phrase;
  final String description;
  final GuidePhrase example;
  final List<GrammarConcept> grammar;
}

const englishSections = <CourseSection>[
  CourseSection(
    1,
    '5 to 9',
    'A1',
    'I am learning English.',
    'You will start with essential phrases and simple grammar concepts.',
    GuidePhrase(
      'I am from Vietnam. I speak Vietnamese.',
      'Tôi đến từ Việt Nam. Tôi nói tiếng Việt.',
    ),
    [
      GrammarConcept(
        'Articles',
        'Use a or an for one thing: a cat, an apple. Use the for a specific thing.',
      ),
      GrammarConcept(
        'Verbs',
        'I am, you are, she is. Match the verb to the subject.',
      ),
      GrammarConcept(
        'Pronouns',
        'I, you, he, she, it, we and they replace names in a sentence.',
      ),
    ],
  ),
  CourseSection(
    2,
    '10 to 19',
    'A1',
    'I know a few words.',
    'You will ask simple questions and describe people and things.',
    GuidePhrase(
      'My father is funny. He has a dog.',
      'Bố tôi rất vui tính. Ông ấy có một con chó.',
    ),
    [
      GrammarConcept(
        'Questions',
        'Put am, is or are before the subject: Are you ready?',
      ),
      GrammarConcept(
        'Possessives',
        'Use my, your, his and her to show who something belongs to.',
      ),
      GrammarConcept(
        'Adjectives',
        'Place an adjective before a noun: a green bike.',
      ),
    ],
  ),
  CourseSection(
    3,
    '20 to 29',
    'A1',
    'I can describe my day.',
    'You will talk about your daily routine, familiar places and plans.',
    GuidePhrase('I take the bus every morning.', 'Tôi đi xe buýt mỗi sáng.'),
    [
      GrammarConcept(
        'Present simple',
        'Use the present simple for routines. Add s for he, she and it: She walks.',
      ),
      GrammarConcept(
        'Time',
        'Use at with clock times, on with days, and in with months.',
      ),
      GrammarConcept(
        'Frequency',
        'Often and usually describe how frequently something happens.',
      ),
    ],
  ),
  CourseSection(
    4,
    '30 to 59',
    'A2',
    'I can talk about familiar experiences.',
    'You will handle everyday tasks and describe experiences in more detail.',
    GuidePhrase(
      'Could you tell me where the station is?',
      'Bạn có thể chỉ cho tôi nhà ga ở đâu không?',
    ),
    [
      GrammarConcept(
        'Past simple',
        'Use the past simple for finished events: I visited my friend yesterday.',
      ),
      GrammarConcept(
        'Comparisons',
        'Use taller than, more interesting than and as good as to compare.',
      ),
      GrammarConcept(
        'Polite requests',
        'Could you help me? is a polite way to ask for help.',
      ),
    ],
  ),
  CourseSection(
    5,
    '60 to 79',
    'B1',
    'I can explain my plans.',
    'You will follow everyday conversations and explain reasons for your plans.',
    GuidePhrase(
      'I changed my plans because the weather got worse.',
      'Tôi đã đổi kế hoạch vì thời tiết trở nên xấu hơn.',
    ),
    [
      GrammarConcept(
        'Present perfect',
        'Use have or has with a past participle: I have visited London.',
      ),
      GrammarConcept(
        'Conditionals',
        'If it rains, we will stay home connects a condition and a result.',
      ),
      GrammarConcept(
        'Reasons',
        'Use because to give a reason and so to introduce a result.',
      ),
    ],
  ),
  CourseSection(
    6,
    '80 to 99',
    'B1',
    'I can share my opinion.',
    'You will explain opinions and understand detailed conversations.',
    GuidePhrase(
      'Although the trip was tiring, it was worth the effort.',
      'Mặc dù chuyến đi mệt mỏi, nó rất đáng công sức.',
    ),
    [
      GrammarConcept(
        'Contrast',
        'Although introduces a contrast. Despite is followed by a noun or an ing form.',
      ),
      GrammarConcept(
        'Relative clauses',
        'The book that you recommended was excellent adds information about the book.',
      ),
      GrammarConcept(
        'Reported speech',
        'She said that she was busy reports what someone said.',
      ),
    ],
  ),
  CourseSection(
    7,
    '100 to 114',
    'B2',
    'I can discuss complex topics.',
    'You will support your ideas with detail and discuss more complex topics.',
    GuidePhrase(
      'The proposal would improve access while reducing costs.',
      'Đề xuất sẽ cải thiện khả năng tiếp cận đồng thời giảm chi phí.',
    ),
    [
      GrammarConcept(
        'Passive voice',
        'The report was published yesterday focuses on the report rather than its author.',
      ),
      GrammarConcept(
        'Modal deduction',
        'Must, might and cannot show different degrees of certainty.',
      ),
      GrammarConcept(
        'Linking ideas',
        'Furthermore adds a point; however introduces a contrast.',
      ),
    ],
  ),
  CourseSection(
    8,
    '115 to 129',
    'B2',
    'I feel comfortable expressing myself spontaneously.',
    'You will express detailed ideas naturally and respond to unfamiliar topics.',
    GuidePhrase(
      'Had I known about the delay, I would have taken a different route.',
      'Nếu biết về sự chậm trễ, tôi đã chọn một tuyến đường khác.',
    ),
    [
      GrammarConcept(
        'Past conditionals',
        'If I had known, I would have helped describes an unreal past condition.',
      ),
      GrammarConcept(
        'Emphasis',
        'What I appreciate most is your patience emphasizes a particular idea.',
      ),
      GrammarConcept(
        'Register',
        'Choose formal or informal wording to suit the situation.',
      ),
    ],
  ),
];

class CourseTarget {
  const CourseTarget(this.section, this.unit);
  final int section;
  final int unit;
  bool get valid => section >= 1 && section <= 8 && unit >= 1 && unit <= 8;
  @override
  bool operator ==(Object other) =>
      other is CourseTarget && other.section == section && other.unit == unit;
  @override
  int get hashCode => Object.hash(section, unit);
}

CourseTarget? guideTarget(String id, String? section) {
  final match = RegExp(r'^unit-([1-8])$').firstMatch(id);
  final sectionNumber = section == null ? 1 : int.tryParse(section);
  if (match == null || sectionNumber == null) return null;
  final target = CourseTarget(sectionNumber, int.parse(match[1]!));
  return target.valid ? target : null;
}

class UnitGuide {
  const UnitGuide(this.title, this.phrases, this.tipTitle, this.tip);
  final String title;
  final List<GuidePhrase> phrases;
  final String tipTitle;
  final String tip;
}

const englishUnitGuides = <UnitGuide>[
  UnitGuide(
    'Use basic phrases',
    [
      GuidePhrase('Hello!', 'Xin chào!'),
      GuidePhrase('Thank you very much.', 'Cảm ơn bạn rất nhiều.'),
      GuidePhrase('Goodbye.', 'Tạm biệt.'),
      GuidePhrase('Nice to meet you.', 'Rất vui được gặp bạn.'),
    ],
    'Say hello!',
    'Use hello to greet someone. You can also say good morning, good afternoon or good evening.',
  ),
  UnitGuide(
    'Introduce yourself',
    [
      GuidePhrase('My name is Linh.', 'Tên tôi là Linh.'),
      GuidePhrase('I am from Vietnam.', 'Tôi đến từ Việt Nam.'),
      GuidePhrase('What is your name?', 'Bạn tên là gì?'),
      GuidePhrase('Where are you from?', 'Bạn đến từ đâu?'),
    ],
    'Meet someone new',
    'Use My name is to introduce yourself. Ask What is your name? when you meet someone new.',
  ),
  UnitGuide(
    'Describe people',
    [
      GuidePhrase('She is my sister.', 'Cô ấy là chị gái tôi.'),
      GuidePhrase('My father is funny.', 'Bố tôi rất vui tính.'),
      GuidePhrase('He has a dog.', 'Anh ấy có một con chó.'),
      GuidePhrase('They are my friends.', 'Họ là bạn của tôi.'),
    ],
    'Who is it?',
    'Use he, she and they to talk about people. Match is or are to the subject.',
  ),
  UnitGuide(
    'Order food',
    [
      GuidePhrase('I would like some tea.', 'Tôi muốn uống trà.'),
      GuidePhrase('The restaurant is open.', 'Nhà hàng đang mở cửa.'),
      GuidePhrase(
        'A table for two, please.',
        'Cho tôi bàn dành cho hai người.',
      ),
      GuidePhrase('Could I have the bill?', 'Cho tôi xin hóa đơn được không?'),
    ],
    'A green bike!',
    'English adjectives usually come before the noun they describe: a green bike, green tea, a Mexican restaurant.',
  ),
  UnitGuide(
    'Talk about your routine',
    [
      GuidePhrase('I wake up at seven.', 'Tôi thức dậy lúc bảy giờ.'),
      GuidePhrase('We eat breakfast at home.', 'Chúng tôi ăn sáng ở nhà.'),
      GuidePhrase('She goes to work by bus.', 'Cô ấy đi làm bằng xe buýt.'),
      GuidePhrase('I study English every day.', 'Tôi học tiếng Anh mỗi ngày.'),
    ],
    'Every day',
    'Use the present simple for habits. Add s or es for he, she and it: She studies every day.',
  ),
  UnitGuide(
    'Find your way',
    [
      GuidePhrase('Where is the station?', 'Nhà ga ở đâu?'),
      GuidePhrase('Turn left at the corner.', 'Rẽ trái ở góc đường.'),
      GuidePhrase('It is next to the bank.', 'Nó ở cạnh ngân hàng.'),
      GuidePhrase('Go straight ahead.', 'Đi thẳng về phía trước.'),
    ],
    'Places nearby',
    'Use next to, opposite and between to explain where a place is.',
  ),
  UnitGuide(
    'Make plans',
    [
      GuidePhrase('What are you doing tomorrow?', 'Ngày mai bạn sẽ làm gì?'),
      GuidePhrase(
        'We are going to visit a friend.',
        'Chúng tôi sẽ đến thăm một người bạn.',
      ),
      GuidePhrase('Would you like to come?', 'Bạn có muốn đi cùng không?'),
      GuidePhrase('Let us meet at six.', 'Chúng ta gặp nhau lúc sáu giờ nhé.'),
    ],
    'Plan ahead',
    'Use going to for plans you have already made. Use would you like to for an invitation.',
  ),
  UnitGuide(
    'Share experiences',
    [
      GuidePhrase('I have visited London.', 'Tôi đã đến London.'),
      GuidePhrase(
        'Have you tried this before?',
        'Bạn đã từng thử món này chưa?',
      ),
      GuidePhrase('It was a wonderful trip.', 'Đó là một chuyến đi tuyệt vời.'),
      GuidePhrase('I would love to go again.', 'Tôi rất muốn đến đó lần nữa.'),
    ],
    'Have you ever?',
    'Use have or has with a past participle to talk about experiences. Use the past simple when you give a finished time.',
  ),
];

UnitGuide unitGuide(CourseTarget target) {
  if (target.section == 1 || target.unit != 1) {
    return englishUnitGuides[target.unit - 1];
  }
  final section = englishSections[target.section - 1];
  return UnitGuide(
    section.phrase,
    [section.example],
    section.grammar.first.title,
    section.grammar.first.explanation,
  );
}
