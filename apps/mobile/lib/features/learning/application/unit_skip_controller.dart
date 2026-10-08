import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/unit_skip.dart';

final unitSkipFixtureProvider = Provider<UnitSkipFixture?>((ref) => null);

typedef UnitSkipIdentity = ({int unit, int section, bool sectionCheck});

final _unitSkipProviders =
    <UnitSkipIdentity, NotifierProvider<UnitSkipController, UnitSkipState>>{};

NotifierProvider<UnitSkipController, UnitSkipState> unitSkipControllerProvider(
  int unit, {
  int section = 1,
  bool sectionCheck = false,
}) {
  final identity = (unit: unit, section: section, sectionCheck: sectionCheck);
  return _unitSkipProviders.putIfAbsent(
    identity,
    () => NotifierProvider.autoDispose<UnitSkipController, UnitSkipState>(
      () => UnitSkipController(
        unit,
        section: section,
        sectionCheck: sectionCheck,
      ),
    ),
  );
}

class UnitSkipController extends Notifier<UnitSkipState> {
  UnitSkipController(
    this.unit, {
    required this.section,
    required this.sectionCheck,
  });

  final int unit;
  final int section;
  final bool sectionCheck;

  UnitSkipQuestion? get question => state.currentQuestion;

  @override
  UnitSkipState build() {
    final validIdentity = sectionCheck
        ? unit == section && unit >= 2 && unit <= 8
        : section >= 1 && section <= 8 && unit >= 2 && unit <= 8;
    if (!validIdentity) {
      return UnitSkipState(
        unit: unit,
        section: section,
        sectionCheck: sectionCheck,
        questions: const <UnitSkipQuestion>[],
        stage: UnitSkipStage.unavailable,
      );
    }
    final fixture = ref.watch(unitSkipFixtureProvider);
    final questions = _snapshotQuestions(
      fixture?.questions ?? authoredUnitSkipQuestions,
    );
    return UnitSkipState(
      unit: unit,
      section: section,
      sectionCheck: sectionCheck,
      questions: questions,
      stage: questions.isEmpty
          ? UnitSkipStage.unavailable
          : UnitSkipStage.intro,
    );
  }

  List<UnitSkipQuestion> _snapshotQuestions(List<UnitSkipQuestion> questions) {
    if (questions.length < 3 ||
        questions.any((question) => !_valid(question))) {
      return const <UnitSkipQuestion>[];
    }
    return List<UnitSkipQuestion>.unmodifiable(
      questions.map(
        (question) => UnitSkipQuestion(
          id: question.id,
          lesson: question.lesson,
          prompt: question.prompt,
          tokens: List<UnitSkipToken>.unmodifiable(question.tokens),
          answerTokenIds: List<String>.unmodifiable(question.answerTokenIds),
        ),
      ),
    );
  }

  bool _valid(UnitSkipQuestion question) {
    if (question.id.isEmpty ||
        question.lesson.isEmpty ||
        question.prompt.isEmpty ||
        question.tokens.length < 2 ||
        question.answerTokenIds.length < 2) {
      return false;
    }
    final tokenIds = question.tokens.map((token) => token.id).toSet();
    return tokenIds.length == question.tokens.length &&
        question.answerTokenIds.toSet().length ==
            question.answerTokenIds.length &&
        question.answerTokenIds.every(tokenIds.contains);
  }

  void start() {
    if (state.stage != UnitSkipStage.intro || state.questions.isEmpty) return;
    state = _replace(stage: UnitSkipStage.answering);
  }

  void toggleToken(String id) {
    final current = question;
    if (state.stage != UnitSkipStage.answering ||
        current == null ||
        !current.tokens.any((token) => token.id == id)) {
      return;
    }
    final selected = <String>[...state.selectedTokenIds];
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    state = _replace(selectedTokenIds: List<String>.unmodifiable(selected));
  }

  void check() {
    final current = question;
    if (!state.canCheck || current == null) return;
    final correct = listEquals(state.selectedTokenIds, current.answerTokenIds);
    state = _replace(
      stage: UnitSkipStage.feedback,
      hearts: correct ? state.hearts : (state.hearts - 1).clamp(0, 5),
      correct: correct,
    );
  }

  void continueAfterFeedback() {
    if (state.stage != UnitSkipStage.feedback || state.correct == null) return;
    if (state.correct!) {
      final next = state.questionIndex + 1;
      if (next >= state.questions.length) {
        state = _replace(
          stage: UnitSkipStage.passed,
          questionIndex: state.questions.length,
          selectedTokenIds: const <String>[],
          clearCorrect: true,
        );
      } else {
        state = _replace(
          stage: UnitSkipStage.answering,
          questionIndex: next,
          selectedTokenIds: const <String>[],
          clearCorrect: true,
        );
      }
      return;
    }
    if (state.hearts == 0) {
      state = _replace(stage: UnitSkipStage.failed, clearCorrect: true);
    } else if (state.hearts == 1 && !state.warningShown) {
      state = _replace(
        stage: UnitSkipStage.lastHeartWarning,
        warningShown: true,
        clearCorrect: true,
      );
    } else {
      state = _replace(stage: UnitSkipStage.answering, clearCorrect: true);
    }
  }

  void continueAfterWarning() {
    if (state.stage != UnitSkipStage.lastHeartWarning) return;
    state = _replace(stage: UnitSkipStage.answering);
  }

  bool acknowledgePass() {
    if (state.stage != UnitSkipStage.passed || state.passAcknowledged) {
      return false;
    }
    state = _replace(passAcknowledged: true);
    return true;
  }

  void restart() {
    if (state.stage != UnitSkipStage.failed) return;
    state = UnitSkipState(
      unit: state.unit,
      section: state.section,
      sectionCheck: state.sectionCheck,
      questions: state.questions,
      stage: UnitSkipStage.intro,
    );
  }

  UnitSkipState _replace({
    UnitSkipStage? stage,
    int? questionIndex,
    List<String>? selectedTokenIds,
    int? hearts,
    bool? correct,
    bool clearCorrect = false,
    bool? warningShown,
    bool? passAcknowledged,
  }) => UnitSkipState(
    unit: state.unit,
    section: state.section,
    sectionCheck: state.sectionCheck,
    questions: state.questions,
    stage: stage ?? state.stage,
    questionIndex: questionIndex ?? state.questionIndex,
    selectedTokenIds: selectedTokenIds ?? state.selectedTokenIds,
    hearts: hearts ?? state.hearts,
    correct: clearCorrect ? null : correct ?? state.correct,
    warningShown: warningShown ?? state.warningShown,
    passAcknowledged: passAcknowledged ?? state.passAcknowledged,
  );
}
