import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/year_review.dart';

const yearReviewPageCount = 7;

typedef YearReviewClipboardWriter = Future<void> Function(String value);

final yearReviewClipboardWriterProvider = Provider<YearReviewClipboardWriter>(
  (_) =>
      (value) => Clipboard.setData(ClipboardData(text: value)),
);

class YearReviewState {
  const YearReviewState({
    this.index = 0,
    this.sharing = false,
    this.copied = false,
    this.shareError,
  });

  final int index;
  final bool sharing;
  final bool copied;
  final String? shareError;
}

final yearReviewControllerProvider =
    NotifierProvider.autoDispose<YearReviewController, YearReviewState>(
      YearReviewController.new,
    );

class YearReviewController extends Notifier<YearReviewState> {
  var _generation = 0;

  @override
  YearReviewState build() {
    ref.onDispose(() => _generation += 1);
    return const YearReviewState();
  }

  void setIndex(int index) {
    if (index < 0 || index >= yearReviewPageCount || index == state.index) {
      return;
    }
    state = YearReviewState(
      index: index,
      sharing: state.sharing,
      copied: state.copied,
      shareError: state.shareError,
    );
  }

  void next() => setIndex(state.index + 1);

  void back() => setIndex(state.index - 1);

  void restart() {
    _generation += 1;
    state = const YearReviewState();
  }

  Future<bool> share() async {
    if (state.sharing) return false;
    final generation = ++_generation;
    state = YearReviewState(index: state.index, sharing: true);
    try {
      await ref.read(yearReviewClipboardWriterProvider)(_shareText);
      if (!ref.mounted || generation != _generation) return false;
      state = YearReviewState(index: state.index, copied: true);
      return true;
    } on PlatformException {
      if (!ref.mounted || generation != _generation) return false;
      state = YearReviewState(
        index: state.index,
        shareError: 'Couldn’t copy. Try again.',
      );
      return false;
    }
  }
}

String get _shareText {
  final review = historical2025;
  return 'My ${review.year} ${review.course} Year in Review: '
      '${_withThousands(review.totalXp)} XP, ${review.lessons} lessons, '
      'and a ${review.longestStreak}-day longest streak.';
}

String _withThousands(int value) {
  final digits = '$value';
  return '${digits.substring(0, digits.length - 3)},'
      '${digits.substring(digits.length - 3)}';
}
