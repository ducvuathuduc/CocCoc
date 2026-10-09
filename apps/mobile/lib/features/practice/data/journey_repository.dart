import '../domain/journey_models.dart';

const englishStory = [
  JourneyQuestion(
    JourneyKind.reading,
    'A Big Family',
    [],
    [],
    transcript: 'Melissa: This is my mother.\nMom: Hello!\nMelissa: And this is my grandfather.\nMom: You have a big family!',
    translation:
        'Đây là mẹ tôi. Xin chào! Đây là ông tôi. Bạn có một gia đình lớn!',
  ),
  JourneyQuestion(
    JourneyKind.choice,
    'Melissa introduces her cat.',
    ['True', 'False'],
    ['False'],
    transcript: 'This is my mother.',
  ),
  JourneyQuestion(
    JourneyKind.word,
    'Select the word meaning “mẹ”.',
    ['This', 'is', 'my', 'mother'],
    ['mother'],
  ),
  JourneyQuestion(
    JourneyKind.choice,
    'Complete the missing phrase.',
    ['my cat', 'my mother', 'my school'],
    ['my mother'],
    transcript: 'Melissa: This is ____.\nMom: Hello!',
  ),
  JourneyQuestion(
    JourneyKind.bank,
    'Form the sentence',
    ['family', 'big', 'a', 'have', 'You'],
    ['You', 'have', 'a', 'big', 'family'],
    transcript: 'Mom: You have a big family!',
  ),
];
const englishRadio = [
  JourneyQuestion(
    JourneyKind.reading,
    'Living in the Shadows',
    [],
    [],
    transcript: 'Lily: Welcome to our English show.\nCaller: My sisters are large and smart.\nLily: Where do they live?\nCaller: They live in Vietnam.',
    translation: 'Các chị tôi cao lớn và thông minh. Họ sống ở Việt Nam.',
  ),
  JourneyQuestion(
    JourneyKind.pairs,
    'Match the pairs',
    ['woman', 'large', 'smart', 'người phụ nữ', 'cao lớn', 'thông minh'],
    ['woman', 'người phụ nữ', 'large', 'cao lớn', 'smart', 'thông minh'],
  ),
  JourneyQuestion(
    JourneyKind.multi,
    'Select 2 words from the transcript',
    ['large', 'smart', 'funny'],
    ['large', 'smart'],
    transcript: 'My sisters are large and smart.',
  ),
  JourneyQuestion(
    JourneyKind.choice,
    'Where do they live?',
    ['In Mexico', 'In Vietnam'],
    ['In Vietnam'],
    transcript: 'They live in Vietnam.',
  ),
];
const englishRoleplay = [
  ('Hello! Would you like the chicken?', 'Xin chào! Bạn có muốn món gà không?'),
  ('Would you like something to drink?', 'Bạn có muốn uống gì không?'),
  (
    'Here is your water. Enjoy your meal!',
    'Đây là nước của bạn. Chúc ngon miệng!',
  ),
];
const englishRapid = [
  JourneyQuestion(
    JourneyKind.choice,
    'Select the correct translation',
    ['simple', 'eighteen', 'that'],
    ['that'],
    transcript: 'đó',
  ),
  JourneyQuestion(
    JourneyKind.bank,
    'Translate this sentence',
    ['woman', 'I', 'a', 'am'],
    ['I', 'am', 'a', 'woman'],
    transcript: 'Tôi là một người phụ nữ.',
  ),
  JourneyQuestion(
    JourneyKind.choice,
    'Select the correct translation',
    ['cat', 'bear', 'boy'],
    ['bear'],
    transcript: 'con gấu',
  ),
  JourneyQuestion(
    JourneyKind.choice,
    'Select the correct translation',
    ['hello', 'thank you', 'good night'],
    ['thank you'],
    transcript: 'cảm ơn',
  ),
];
const englishLegendary = [
  JourneyQuestion(
    JourneyKind.bank,
    'Translate this sentence',
    ['cat', 'a', 'It', 'is'],
    ['It', 'is', 'a', 'cat'],
    transcript: 'Nó là một con mèo.',
  ),
  JourneyQuestion(
    JourneyKind.choice,
    'Select the correct translation',
    ['man', 'woman', 'girl'],
    ['woman'],
    transcript: 'người phụ nữ',
  ),
  JourneyQuestion(
    JourneyKind.bank,
    'Translate this sentence',
    ['Vietnam', 'am', 'from', 'I'],
    ['I', 'am', 'from', 'Vietnam'],
    transcript: 'Tôi đến từ Việt Nam.',
  ),
  JourneyQuestion(
    JourneyKind.choice,
    'Complete the sentence',
    ['please', 'hello', 'cat'],
    ['please'],
    transcript: 'Water, ____.',
  ),
];
List<JourneyQuestion> questionsFor(String kind) => switch (kind) {
  'rapid' => englishRapid,
  'legendary' => englishLegendary,
  'radio' => englishRadio,
  _ => englishStory,
};
String titleFor(String kind) => switch (kind) {
  'radio' => 'Radio',
  'roleplay' => 'Roleplay',
  'rapid' => 'Rapid Review',
  'legendary' => 'Legendary',
  _ => 'Story',
};
