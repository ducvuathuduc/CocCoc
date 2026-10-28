import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../domain/learning_models.dart';

/// Display bundle for Explain My Answer: one paragraph plus example lines.
typedef EnglishExplanation = (String, List<String>);

// Authored English examples, never an AI response or an official course export.
const englishExplanations = <String, EnglishExplanation>{
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
        .map(
          (e) =>
              '${exercise.pairLabel(e.key)} → ${exercise.pairLabel(e.value)}',
        )
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
        .map(
          (e) =>
              '${exercise.pairLabel(e.key)} → ${exercise.pairLabel(e.value)}',
        )
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

/// The inputs that identify one Explain My Answer request. Equality is by the
/// real exercise id, lesson node and submitted answer, so provider rebuilds do
/// not refetch while the same feedback stays on screen.
final class ExplanationRequest {
  const ExplanationRequest({
    required this.exercise,
    required this.nodeId,
    required this.answer,
  });

  final Exercise exercise;
  final String nodeId;
  final String answer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExplanationRequest &&
          other.exercise.id == exercise.id &&
          other.nodeId == nodeId &&
          other.answer == answer;

  @override
  int get hashCode => Object.hash(exercise.id, nodeId, answer);
}

/// Server-backed Explain My Answer: `POST /v1/tutor` with the exercise id from
/// the published lesson bundle. Used only in API mode; mock continues to read
/// the authored [englishExplanations] map synchronously.
final exerciseExplanationProvider = FutureProvider.autoDispose
    .family<EnglishExplanation?, ExplanationRequest>((ref, request) async {
      final authored = englishExplanations[request.exercise.id];
      if (!ref.watch(appConfigProvider).isApi) return authored;
      final api = ref.watch(apiEndpointsProvider);
      final learnerText = request.answer.trim().isEmpty
          ? request.exercise.prompt
          : request.answer;
      try {
        final result = await api.tutorFeedback(
          wire.TutorRequest(
            requestId: api.client.ids.next(),
            exerciseId: switch (_wireId(request.exercise.id)) {
              final id? => wire.JsonPresence<String>.value(id),
              null => const wire.JsonPresence<String>.absent(),
            },
            learnerText: learnerText.length > 512
                ? learnerText.substring(0, 512)
                : learnerText,
            level: 'A1',
            locale: 'en-US',
            feedbackLocale: 'vi-VN',
          ),
        );
        return explanationFromTutor(result) ?? authored;
      } catch (_) {
        // The authored fallback keeps the screen useful when the tutor is
        // unreachable; unknown server exercises keep the existing
        // "unavailable" state rather than inventing an explanation.
        return authored;
      }
    });

EnglishExplanation? explanationFromTutor(wire.TutorResult result) {
  final explanation = result.explanation.trim();
  final tutor = result.tutorText.trim();
  if (explanation.isEmpty && tutor.isEmpty) return null;
  return (
    explanation.isEmpty ? tutor : explanation,
    List<String>.unmodifiable([
      if (tutor.isNotEmpty && tutor != explanation) tutor,
    ]),
  );
}

final _invalidId = RegExp(r'[^A-Za-z0-9_.-]');

String? _wireId(String id) {
  var value = id.replaceAll(_invalidId, '_');
  if (value.isEmpty) return null;
  if (!RegExp(r'^[A-Za-z0-9]').hasMatch(value)) value = 'x$value';
  return value.length > 36 ? value.substring(0, 36) : value;
}
