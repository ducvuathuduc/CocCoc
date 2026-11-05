import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../hearts/application/hearts_controller.dart';
import '../../hearts/domain/hearts.dart';
import '../../learning/application/learning_controller.dart';
import '../../progress/application/extended_controller.dart';
import '../../progress/application/preview_controller.dart';
import '../../../core/config/app_config.dart';
import '../../progress/data/league_repository.dart';
import '../../progress/data/progress_snapshot.dart';
import '../data/api_app_shell_repository.dart';
import '../data/app_shell_repository.dart';
import '../domain/app_shell_models.dart';

final appShellRepositoryProvider = Provider<AppShellRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) {
    return const MockAppShellRepository();
  }
  return ApiAppShellRepository(ref.watch(progressSnapshotSourceProvider));
});

final appStatsProvider = Provider<List<AppStat>>((ref) {
  watchProgressSnapshot(ref);
  if (ref.watch(appConfigProvider).isApi) {
    // Real balances come exclusively from the account-scoped snapshot.
    return ref
        .watch(appShellRepositoryProvider)
        .stats(
          AppShellSnapshot(
            score: ref.watch(
              learningStateProvider.select((state) => state.score),
            ),
            streak: 0,
            gems: 0,
            energy: 0,
            unlimited: false,
            streakActive: false,
          ),
        );
  }
  final progress = ref.watch(
    learningStateProvider.select(
      (state) => (state.score, state.streak, state.completedLessons > 0),
    ),
  );
  final energy = ref.watch(
    extendedControllerProvider.select(
      (state) => (state.energy, state.unlimited),
    ),
  );
  return ref
      .watch(appShellRepositoryProvider)
      .stats(
        AppShellSnapshot(
          score: progress.$1,
          streak: progress.$2,
          gems: ref.watch(previewWalletProvider),
          energy: energy.$1,
          unlimited: energy.$2,
          streakActive: progress.$3,
          hearts: ref.watch(livesModelProvider) == LivesModel.hearts
              ? ref.watch(heartsControllerProvider.select((s) => s.balance))
              : null,
        ),
      );
});

final appTabsProvider = Provider<List<AppTab>>(
  (ref) => ref.watch(appShellRepositoryProvider).tabs(),
);
