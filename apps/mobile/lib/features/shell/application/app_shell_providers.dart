import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../learning/application/learning_controller.dart';
import '../../progress/application/extended_controller.dart';
import '../../progress/application/preview_controller.dart';
import '../data/app_shell_repository.dart';
import '../domain/app_shell_models.dart';

final appShellRepositoryProvider = Provider<AppShellRepository>(
  (ref) => const MockAppShellRepository(),
);

final appStatsProvider = Provider<List<AppStat>>((ref) {
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
        ),
      );
});

final appTabsProvider = Provider<List<AppTab>>(
  (ref) => ref.watch(appShellRepositoryProvider).tabs(),
);
