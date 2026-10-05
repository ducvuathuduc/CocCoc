import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journey_repository.dart';
import '../data/stories_repository.dart';
import '../domain/journey_models.dart';
import '../../progress/application/preview_controller.dart';

final _journeyProviders = {
  for (final kind in ['story', 'radio', 'roleplay', 'rapid', 'legendary'])
    kind: NotifierProvider<JourneyController, JourneyState>(
      () => JourneyController(kind),
    ),
};
NotifierProvider<JourneyController, JourneyState> journeyControllerProvider(
  String kind,
) => _journeyProviders[kind] ?? _journeyProviders['story']!;

class JourneyController extends Notifier<JourneyState> {
  JourneyController(this.kind);
  final String kind;
  @override
  JourneyState build() => const JourneyState();
  EnglishStory get story => englishStoryLibrary[state.storyId]!;
  List<JourneyQuestion> get questions =>
      kind == 'story' && state.storyId != 'family'
      ? story.questions
      : questionsFor(kind);
  bool pickStory(String id) {
    if (kind != 'story' || !englishStoryLibrary.containsKey(id)) return false;
    if (id != state.storyId) state = JourneyState(storyId: id);
    return true;
  }

  JourneyQuestion? get question => state.complete
      ? null
      : questions[state.step.clamp(0, questions.length - 1)];
  bool get canCheck {
    if (state.complete ||
        state.expired ||
        state.feedback != null ||
        !state.started) {
      return false;
    }
    final q = question!;
    return switch (q.kind) {
      JourneyKind.reading => false,
      JourneyKind.multi || JourneyKind.pairs => state.selected.length == 2,
      JourneyKind.bank => state.selected.length == q.answer.length,
      _ => state.selected.length == 1,
    };
  }

  void start() => state = JourneyState(started: true, storyId: state.storyId);
  void continueReading() {
    if (state.started &&
        !state.complete &&
        question?.kind == JourneyKind.reading) {
      _advance();
    }
  }

  void select(String value) {
    if (state.complete ||
        state.expired ||
        state.feedback != null ||
        !state.started) {
      return;
    }
    final q = question!;
    if (!q.options.contains(value) || state.matched.contains(value)) return;
    final selected = List<String>.of(state.selected);
    if (selected.contains(value)) {
      selected.remove(value);
    } else if (q.kind == JourneyKind.multi || q.kind == JourneyKind.pairs) {
      if (selected.length < 2) selected.add(value);
    } else if (q.kind == JourneyKind.bank) {
      selected.add(value);
    } else {
      selected
        ..clear()
        ..add(value);
    }
    state = state.copyWith(selected: selected);
  }

  void check() {
    if (!canCheck) return;
    final q = question!;
    bool valid;
    if (q.kind == JourneyKind.pairs) {
      final index = q.answer.indexOf(state.selected.first);
      valid =
          index >= 0 &&
          state.selected.last == q.answer[index.isEven ? index + 1 : index - 1];
    } else if (q.kind == JourneyKind.multi) {
      valid = setEquals(state.selected.toSet(), q.answer.toSet());
    } else {
      valid = listEquals(state.selected, q.answer);
    }
    state = state.copyWith(
      feedback: valid,
      correct: state.correct + (valid ? 1 : 0),
      attempted: state.attempted + 1,
      matched: valid && q.kind == JourneyKind.pairs
          ? {...state.matched, ...state.selected}
          : state.matched,
    );
  }

  void next() {
    if (state.complete || state.expired || state.feedback == null) {
      return;
    }
    if ((kind == 'rapid' || kind == 'legendary') && state.feedback == false) {
      state = state.copyWith(selected: [], clearFeedback: true);
      return;
    }
    if (question?.kind == JourneyKind.pairs &&
        state.matched.length < question!.answer.length) {
      state = state.copyWith(selected: [], clearFeedback: true);
      return;
    }
    _advance();
  }

  void _advance() {
    final step = state.step + 1;
    state = state.copyWith(
      step: step,
      complete: step >= questions.length,
      selected: [],
      matched: {},
      clearFeedback: true,
    );
  }

  void edit(String value) {
    if (!state.complete) state = state.copyWith(draft: value, clearError: true);
  }

  void dismissMilestone() => state = state.copyWith(milestoneSeen: true);
  void tick(int seconds) {
    if (kind != 'rapid' ||
        seconds <= 0 ||
        !state.started ||
        state.complete ||
        state.expired) {
      return;
    }
    final remaining = (state.remaining - seconds).clamp(0, 105);
    state = state.copyWith(remaining: remaining, expired: remaining == 0);
  }

  bool useTimerBoost() {
    if (kind != 'rapid' ||
        !state.started ||
        !state.expired ||
        state.complete ||
        !ref.read(previewControllerProvider.notifier).consumeTimerBoost()) {
      return false;
    }
    state = state.copyWith(remaining: 60, expired: false);
    return true;
  }

  void send() {
    if (kind != 'roleplay' || !state.started || state.complete) return;
    final value = state.draft.trim();
    if (value.isEmpty || value.length > 500) {
      state = state.copyWith(
        error: 'Write an English reply between 1 and 500 characters.',
      );
      return;
    }
    final step = state.step + 1;
    state = state.copyWith(
      step: step,
      replies: [...state.replies, value],
      draft: '',
      clearError: true,
      complete: step >= englishRoleplay.length,
    );
  }
}
