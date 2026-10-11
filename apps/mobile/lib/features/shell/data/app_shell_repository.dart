import '../domain/app_shell_models.dart';

abstract class AppShellRepository {
  List<AppStat> stats(AppShellSnapshot snapshot);
  List<AppTab> tabs();
}

class MockAppShellRepository implements AppShellRepository {
  const MockAppShellRepository();

  @override
  List<AppStat> stats(AppShellSnapshot snapshot) => List.unmodifiable([
    AppStat(
      kind: AppStatKind.course,
      label: 'Courses',
      value: snapshot.score == 0 ? '' : '${snapshot.score}',
      semanticLabel: 'Courses, English score ${snapshot.score}',
    ),
    AppStat(
      kind: AppStatKind.streak,
      label: 'Streak',
      value: '${snapshot.streak}',
      semanticLabel: 'Streak, ${snapshot.streak} days',
      active: snapshot.streakActive,
    ),
    AppStat(
      kind: AppStatKind.gems,
      label: 'Shop',
      value: '${snapshot.gems}',
      semanticLabel: 'Shop, ${snapshot.gems} gems',
    ),
    AppStat(
      kind: AppStatKind.energy,
      label: 'Energy',
      value: snapshot.unlimited ? '∞' : '${snapshot.energy}',
      semanticLabel: snapshot.unlimited
          ? 'Energy, unlimited'
          : 'Energy, ${snapshot.energy}',
      unlimited: snapshot.unlimited,
    ),
  ]);

  @override
  List<AppTab> tabs() => const [
    AppTab(kind: AppTabKind.home, branchIndex: 0, label: 'Home'),
    AppTab(kind: AppTabKind.practice, branchIndex: 1, label: 'Practice'),
    AppTab(kind: AppTabKind.quests, branchIndex: 2, label: 'Quests'),
    AppTab(kind: AppTabKind.league, branchIndex: 3, label: 'League'),
    AppTab(kind: AppTabKind.profile, branchIndex: 4, label: 'Profile'),
  ];
}
