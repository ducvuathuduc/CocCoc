import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journey_repository.dart';
import '../data/stories_repository.dart';
import '../domain/journey_models.dart';
import '../../progress/application/preview_controller.dart';
import '../../roleplay/application/roleplay_controller.dart';
import '../../roleplay/data/api_roleplay_repository.dart';
import '../../roleplay/data/roleplay_repository.dart';
import '../../roleplay/domain/roleplay_models.dart';

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

  /// Roleplay scenario this session plays (library pick or the restaurant).
  RoleplayScenario get scenario {
    final repo = ref.read(roleplayRepositoryProvider);
    return repo.scenario(state.scenarioId ?? restaurantScenarioId) ??
        repo.scenario(restaurantScenarioId)!;
  }

  /// Session lines: the scenario script, with any partner line the server
  /// actually replied (API mode) in its step's place.
  List<RoleplayLine> get roleplayLines {
    final lines = scenario.lines;
    final overrides = state.partnerLines;
    if (overrides.isEmpty) return lines;
    return [for (var i = 0; i < lines.length; i++) overrides[i] ?? lines[i]];
  }

  /// API mode: the server conversation this roleplay run advances.
  Future<RoleplayLiveSession?>? _live;

  RoleplayCommands? get _commands {
    final repo = ref.read(roleplayRepositoryProvider);
    if (repo case final RoleplayCommands commands) return commands;
    return null;
  }

  /// Ends an unfinished server run (picked another scenario / restarted).
  void _dropLive() {
    final live = _live;
    _live = null;
    final commands = _commands;
    if (live == null || commands == null || state.complete) return;
    unawaited(
      live
          .then((s) => s == null ? null : commands.abandon(s))
          .catchError((Object _) {}),
    );
  }

  Future<RoleplayLiveSession?> _open(RoleplayCommands commands, String id) =>
      commands.startSession(id).then<RoleplayLiveSession?>((s) => s).catchError(
        (Object error) {
          if (!ref.mounted) return null;
          state = error is MaxRequiredException
              ? state.copyWith(maxRequired: true)
              : state.copyWith(error: _turnError);
          return null;
        },
      );

  static const _turnError =
      'We couldn’t reach your conversation partner. Please try again.';

  /// Selects a library scenario (null returns to the practice-hub restaurant).
  bool pickScenario(String? id) {
    if (kind != 'roleplay') return false;
    if (id != null &&
        ref.read(roleplayRepositoryProvider).scenario(id) == null) {
      return false;
    }
    _dropLive();
    state = JourneyState(scenarioId: id);
    return true;
  }

  void dismissIntro() {
    if (kind == 'roleplay' && state.started) {
      state = state.copyWith(introSeen: true);
    }
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

  void start() {
    if (kind == 'roleplay') _dropLive();
    state = JourneyState(
      started: true,
      storyId: state.storyId,
      scenarioId: state.scenarioId,
    );
    final commands = kind == 'roleplay' ? _commands : null;
    if (commands != null) _live = _open(commands, scenario.id);
  }

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
    final commands = _commands;
    if (commands != null) {
      if (state.waiting || state.maxRequired) return;
      state = state.copyWith(waiting: true, clearError: true);
      unawaited(_sendLive(commands, value));
      return;
    }
    final step = state.step + 1;
    final complete = step >= roleplayLines.length;
    state = state.copyWith(
      step: step,
      replies: [...state.replies, value],
      draft: '',
      clearError: true,
      complete: complete,
    );
    if (complete) {
      ref
          .read(roleplayLibraryControllerProvider.notifier)
          .record(scenario.id, roleplayWordCount(state.replies));
    }
  }

  /// API mode: one learner turn through the server. An on-topic turn moves to
  /// the next step and shows the server's reply as the partner's next line;
  /// an off-topic one keeps the step (and the learner's draft) and shows the
  /// server's retry line. The last step completes the server conversation.
  Future<void> _sendLive(RoleplayCommands commands, String value) async {
    try {
      final session = await (_live ??= _open(commands, scenario.id));
      if (!ref.mounted) return;
      if (session == null) {
        // Opening failed (Max upsell or network): allow a fresh attempt.
        _live = null;
        state = state.copyWith(waiting: false);
        return;
      }
      final turn = await commands.sendTurn(session, value);
      if (!ref.mounted || !identical(await _live, session)) return;
      final base = scenario.lines;
      final at = state.step.clamp(0, base.length - 1);
      if (!turn.advanced) {
        state = state.copyWith(
          waiting: false,
          partnerLines: {
            ...state.partnerLines,
            at: RoleplayLine(
              prompt: turn.reply,
              translation: turn.explanation,
              hints: base[at].hints,
              tip: base[at].tip,
            ),
          },
        );
        return;
      }
      final step = state.step + 1;
      final complete = step >= base.length;
      state = state.copyWith(
        waiting: false,
        step: step,
        replies: [...state.replies, value],
        draft: '',
        clearError: true,
        complete: complete,
        partnerLines: complete
            ? state.partnerLines
            : {
                ...state.partnerLines,
                step: RoleplayLine(
                  prompt: turn.reply,
                  translation: base[step].translation,
                  hints: base[step].hints,
                  tip: base[step].tip,
                ),
              },
      );
      if (complete) await _completeLive(commands, session);
    } on MaxRequiredException {
      if (ref.mounted) {
        state = state.copyWith(waiting: false, maxRequired: true);
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(waiting: false, error: _turnError);
      }
    }
  }

  Future<void> _completeLive(
    RoleplayCommands commands,
    RoleplayLiveSession session,
  ) async {
    final library = ref.read(roleplayLibraryControllerProvider.notifier);
    final cardId = scenario.id;
    library.record(cardId, roleplayWordCount(state.replies));
    try {
      final result = await commands.complete(session);
      if (ref.mounted) library.applyServerResult(cardId, result);
    } on RoleplayIncompleteException catch (e) {
      // Server and client disagree on progress: resume at the server's step.
      if (!ref.mounted) return;
      final step = e.completedSteps.clamp(0, scenario.lines.length - 1);
      state = state.copyWith(
        complete: false,
        step: step,
        replies: state.replies.take(step).toList(),
        error: 'Keep going — finish the conversation to complete it.',
      );
    } catch (_) {
      // Local result stays; history refresh reconciles later.
    }
  }
}
