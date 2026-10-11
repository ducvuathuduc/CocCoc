enum AppStatKind { course, streak, gems, energy }

enum AppTabKind { home, practice, quests, league, profile }

class AppShellSnapshot {
  const AppShellSnapshot({
    required this.score,
    required this.streak,
    required this.gems,
    required this.energy,
    required this.unlimited,
    required this.streakActive,
  });
  final int score, streak, gems, energy;
  final bool unlimited;
  final bool streakActive;
}

class AppStat {
  const AppStat({
    required this.kind,
    required this.label,
    required this.value,
    required this.semanticLabel,
    this.unlimited = false,
    this.active = true,
  });
  final AppStatKind kind;
  final String label, value, semanticLabel;
  final bool unlimited;
  final bool active;
}

class AppTab {
  const AppTab({
    required this.kind,
    required this.branchIndex,
    required this.label,
  });
  final AppTabKind kind;
  final int branchIndex;
  final String label;
}
