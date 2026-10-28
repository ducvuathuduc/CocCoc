import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';
import '../data/year_review_repository.dart';
import '../domain/year_review.dart';

export '../data/year_review_repository.dart';

const yearReviewPageCount = 7;

typedef YearReviewClipboardWriter = Future<void> Function(String value);

final yearReviewClipboardWriterProvider = Provider<YearReviewClipboardWriter>(
  (_) =>
      (value) => Clipboard.setData(ClipboardData(text: value)),
);

final yearReviewRepositoryProvider = Provider<YearReviewRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) {
    return const MockYearReviewRepository();
  }
  return ApiYearReviewRepository(
    ref.watch(apiEndpointsProvider),
    year: DateTime.now().year - 1,
  );
});

class YearReviewState {
  YearReviewState({
    this.index = 0,
    this.sharing = false,
    this.copied = false,
    this.shareError,
    this.loading = false,
    this.loadError,
    bool demo = true,
    YearReviewSnapshot? snapshot,
  }) : data = snapshot ?? (demo ? historical2025 : null);

  final int index;
  final bool sharing;
  final bool copied;
  final String? shareError;
  final bool loading;
  final String? loadError;
  final YearReviewSnapshot? data;
  bool get hasSnapshot => data != null;
  YearReviewSnapshot get snapshot =>
      data ?? (throw StateError('Year review is not loaded'));
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
    final generation = ++_generation;
    final repository = ref.watch(yearReviewRepositoryProvider);
    final real = ref.watch(appConfigProvider).isApi;
    Future<void>.microtask(() => _load(repository, generation));
    return YearReviewState(demo: !real, loading: real);
  }

  Future<void> _load(YearReviewRepository repository, int generation) async {
    try {
      final snapshot = await repository.load();
      if (!ref.mounted || generation != _generation) return;
      state = YearReviewState(
        index: state.index,
        snapshot: snapshot,
        demo: false,
      );
    } on Object {
      if (!ref.mounted || generation != _generation) return;
      state = YearReviewState(
        index: state.index,
        snapshot: state.data,
        demo: false,
        loadError: 'Could not load your Year in Review. Please retry.',
      );
    }
  }

  Future<void> retry() async {
    if (state.loading) return;
    final generation = ++_generation;
    state = YearReviewState(snapshot: state.data, demo: false, loading: true);
    await _load(ref.read(yearReviewRepositoryProvider), generation);
  }

  void setIndex(int index) {
    if (!state.hasSnapshot ||
        index < 0 ||
        index >= yearReviewPageCount ||
        index == state.index) {
      return;
    }
    state = YearReviewState(
      index: index,
      sharing: state.sharing,
      copied: state.copied,
      shareError: state.shareError,
      snapshot: state.snapshot,
    );
  }

  void next() => setIndex(state.index + 1);

  void back() => setIndex(state.index - 1);

  void restart() {
    if (!state.hasSnapshot) return;
    _generation += 1;
    state = YearReviewState(snapshot: state.snapshot);
  }

  Future<bool> share() async {
    if (state.sharing || !state.hasSnapshot) return false;
    final generation = ++_generation;
    state = YearReviewState(
      index: state.index,
      sharing: true,
      snapshot: state.snapshot,
    );
    try {
      await ref.read(yearReviewClipboardWriterProvider)(
        _shareText(state.snapshot),
      );
      if (!ref.mounted || generation != _generation) return false;
      state = YearReviewState(
        index: state.index,
        copied: true,
        snapshot: state.snapshot,
      );
      return true;
    } on PlatformException {
      if (!ref.mounted || generation != _generation) return false;
      state = YearReviewState(
        index: state.index,
        shareError: 'Couldn’t copy. Try again.',
        snapshot: state.snapshot,
      );
      return false;
    }
  }
}

String _shareText(YearReviewSnapshot review) {
  return 'My ${review.year} ${review.course} Year in Review: '
      '${_withThousands(review.totalXp)} XP, ${review.lessons} lessons, '
      'and a ${review.longestStreak}-day longest streak.';
}

String _withThousands(int value) {
  return '$value'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
