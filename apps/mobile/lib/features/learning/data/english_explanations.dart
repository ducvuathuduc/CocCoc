import '../domain/learning_models.dart';

// Authored English examples, never an AI response or an official course export.
const englishExplanations = <String, (String, List<String>)>{
  'english-01-image': (
    'Woman means người phụ nữ. A boy is a young male person; a girl is a young female person.',
    ['The woman is here.', 'The girl is here.'],
  ),
  'english-02-choice': (
    'Woman means người phụ nữ. And joins words or phrases; boy means cậu bé.',
    ['A woman and a boy.'],
  ),
  'english-03-bank': (
    'With I, use am. Put a before the singular noun woman: I + am + a + woman.',
    ['I am a woman.', 'I am a man.'],
  ),
  'english-04-pairs': (
    'Match the meanings: woman = người phụ nữ, man = người đàn ông, bear = con gấu.',
    ['The woman sees a bear.'],
  ),
  'english-05-translate': (
    'Cat means mèo. This exercise asks for the complete phrase the cat. The identifies the particular cat.',
    ['The cat is here.'],
  ),
  'english-06-listen': (
    'A girl means một cô bé. Girl and woman describe different ages; man means người đàn ông.',
    ['A girl is here.'],
  ),
  'english-07-blank': (
    'The form of be after I is am. After he or she, use is.',
    ['I am a man.', 'She is a woman.'],
  ),
  'english-08-order': (
    'English statement order is subject + verb + location: The bear + is + here.',
    ['The bear is here.', 'The cat is here.'],
  ),
  'english-09-dialogue': (
    'Hello is a greeting. You can reply with Hello when someone greets you.',
    ['Sam: Hello! You: Hello!'],
  ),
  'english-10-story': (
    'The story says Lea sees a cat. The phrase a cat answers what she sees.',
    ['Lea sees a cat.'],
  ),
  'english-practice-dictation': (
    'Use am with I. Here tells us the location. Keep the words in the order I am here.',
    ['I am here.'],
  ),
  'english-practice-speak': (
    'Hello is a greeting. I am Sam introduces the speaker by name.',
    ['Hello, I am Sam.'],
  ),
};

String exerciseAnswer(Exercise exercise) {
  if (exercise.correctText.isNotEmpty) return exercise.correctText;
  if (exercise.pairs.isNotEmpty) {
    return exercise.pairs.entries
        .map((e) => '${e.key} → ${e.value}')
        .join('\n');
  }
  return exercise.correctIds
      .map(
        (id) =>
            [
              ...exercise.choices,
              ...exercise.tokens,
            ].where((c) => c.id == id).firstOrNull?.text ??
            id,
      )
      .join(' ');
}

String submittedAnswer(Exercise exercise, LessonState state) {
  if (state.text.trim().isNotEmpty) return state.text.trim();
  if (state.matchedPairs.isNotEmpty) {
    return state.matchedPairs.entries
        .map((e) => '${e.key} → ${e.value}')
        .join('\n');
  }
  final ids = state.selectedId == null ? state.tokenIds : [state.selectedId!];
  return ids
      .map(
        (id) =>
            [
              ...exercise.choices,
              ...exercise.tokens,
            ].where((c) => c.id == id).firstOrNull?.text ??
            id,
      )
      .join(' ');
}
