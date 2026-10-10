import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/completion_repository.dart';
import '../domain/completion_summary.dart';
import '../domain/learning_models.dart';

final completionRepositoryProvider = Provider<CompletionRepository>(
  (ref) => const MockCompletionRepository(),
);

final completionSummaryProvider =
    Provider.family<CompletionSummary, (SessionReceipt, int)>((ref, request) {
      return ref
          .watch(completionRepositoryProvider)
          .summary(request.$1, mistakeCount: request.$2);
    });

final completionStreakProvider = Provider.family<CompletionStreak, int>((
  ref,
  days,
) {
  return ref.watch(completionRepositoryProvider).streak(days);
});
