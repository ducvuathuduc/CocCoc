import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ClashStage { intro, versus, rules, playing, timeUp, waiting }

class ClashQuestion {
  const ClashQuestion(
    this.cue,
    this.options,
    this.answer, {
    this.wordBank = false,
  });
  final String cue;
  final List<String> options, answer;
  final bool wordBank;
}

const clashQuestions = [
  ClashQuestion('chị gái', ['family', 'sister', 'school'], ['sister']),
  ClashQuestion(
    'Tôi đang mở cửa sổ.',
    [
      'I',
      'am',
      'opening',
      'the',
      'window',
      'Your',
      'no',
      'university',
      'plane',
    ],
    ['I', 'am', 'opening', 'the', 'window'],
    wordBank: true,
  ),
  ClashQuestion('buổi sáng', ['morning', 'evening', 'night'], ['morning']),
  ClashQuestion(
    'Chúng tôi học tiếng Anh.',
    ['We', 'study', 'English', 'They', 'French', 'school'],
    ['We', 'study', 'English'],
    wordBank: true,
  ),
  ClashQuestion('gia đình', ['student', 'family', 'ticket'], ['family']),
  ClashQuestion(
    'Cô ấy là một giáo viên.',
    ['She', 'is', 'a', 'teacher', 'He', 'my'],
    ['She', 'is', 'a', 'teacher'],
    wordBank: true,
  ),
];

class ClashState {
  const ClashState({
    this.stage = ClashStage.intro,
    this.remaining = 60,
    this.index = 0,
    this.correct = 0,
    this.checked = false,
    this.answer = const [],
  });
  final ClashStage stage;
  final int remaining, index, correct;
  final bool checked;
  final List<String> answer;
  ClashState copyWith({
    ClashStage? stage,
    int? remaining,
    int? index,
    int? correct,
    bool? checked,
    List<String>? answer,
  }) => ClashState(
    stage: stage ?? this.stage,
    remaining: remaining ?? this.remaining,
    index: index ?? this.index,
    correct: correct ?? this.correct,
    checked: checked ?? this.checked,
    answer: List.unmodifiable(answer ?? this.answer),
  );
}

final clashControllerProvider = NotifierProvider<ClashController, ClashState>(
  ClashController.new,
);

class ClashController extends Notifier<ClashState> {
  @override
  ClashState build() => const ClashState();
  ClashQuestion get question =>
      clashQuestions[state.index % clashQuestions.length];
  bool get isCorrect => state.answer.join('|') == question.answer.join('|');
  void advance() {
    switch (state.stage) {
      case ClashStage.intro:
        state = state.copyWith(stage: ClashStage.versus);
        break;
      case ClashStage.versus:
        state = state.copyWith(stage: ClashStage.rules);
        break;
      case ClashStage.rules:
        state = state.copyWith(stage: ClashStage.playing);
        break;
      case ClashStage.playing:
        if (state.checked) {
          state = state.copyWith(
            index: state.index + 1,
            answer: const [],
            checked: false,
          );
        }
        break;
      case ClashStage.timeUp:
        state = state.copyWith(stage: ClashStage.waiting);
        break;
      case ClashStage.waiting:
        break;
    }
  }

  void choose(String value) {
    if (state.stage != ClashStage.playing ||
        state.checked ||
        !question.options.contains(value)) {
      return;
    }
    final values = [...state.answer];
    if (question.wordBank) {
      values.contains(value) ? values.remove(value) : values.add(value);
    } else {
      values
        ..clear()
        ..add(value);
    }
    state = state.copyWith(answer: values);
  }

  bool check() {
    if (state.stage != ClashStage.playing ||
        state.checked ||
        state.answer.isEmpty) {
      return false;
    }
    state = state.copyWith(
      checked: true,
      correct: state.correct + (isCorrect ? 1 : 0),
    );
    return true;
  }

  void tick(int seconds) {
    if (state.stage != ClashStage.playing || seconds <= 0) return;
    final left = (state.remaining - seconds).clamp(0, 60);
    state = state.copyWith(
      remaining: left,
      stage: left == 0 ? ClashStage.timeUp : ClashStage.playing,
    );
  }

  void quit() => state = const ClashState();
}
