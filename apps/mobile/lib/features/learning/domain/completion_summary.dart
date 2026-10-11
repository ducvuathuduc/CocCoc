class CompletionStat {
  const CompletionStat({
    required this.label,
    required this.semanticLabel,
    required this.value,
    this.animatedValue,
    this.suffix = '',
  });

  final String label;
  final String semanticLabel;
  final String value;
  final int? animatedValue;
  final String suffix;
}

class CompletionSummary {
  const CompletionSummary({
    required this.title,
    required this.description,
    required this.perfect,
    required this.claimLabel,
    required this.xp,
    required this.accuracy,
    required this.time,
  });

  final String title;
  final String? description;
  final bool perfect;
  final String claimLabel;
  final CompletionStat xp;
  final CompletionStat accuracy;
  final CompletionStat time;
}

class CompletionStreakDay {
  const CompletionStreakDay(
    this.label, {
    required this.practiced,
    this.current = false,
  });
  final String label;
  final bool practiced;
  final bool current;
}

class CompletionStreak {
  const CompletionStreak({
    required this.days,
    required this.semanticLabel,
    required this.title,
    required this.description,
    required this.commitLabel,
    required this.week,
  });
  final int days;
  final String semanticLabel;
  final String title;
  final String description;
  final String commitLabel;
  final List<CompletionStreakDay> week;
}
