import '../domain/completion_summary.dart';
import '../domain/learning_models.dart';

abstract class CompletionRepository {
  CompletionSummary summary(
    SessionReceipt receipt, {
    required int mistakeCount,
  });
  CompletionStreak streak(int days);
}

/// Local presentation of an existing receipt; this repository never awards XP.
class MockCompletionRepository implements CompletionRepository {
  const MockCompletionRepository();

  @override
  CompletionStreak streak(int days) => CompletionStreak(
    days: days,
    semanticLabel: 'Streak, $days days',
    title: 'day streak',
    description:
        'Practicing daily grows your streak,\nbut skipping a day resets it!',
    commitLabel: 'I’M COMMITTED',
    // Archived calendar fixture, not a client-clock-derived progress award.
    week: List.unmodifiable([
      CompletionStreakDay('We', practiced: days >= 2),
      CompletionStreakDay('Th', practiced: days > 0, current: true),
      const CompletionStreakDay('Fr', practiced: false),
      const CompletionStreakDay('Sa', practiced: false),
      const CompletionStreakDay('Su', practiced: false),
      const CompletionStreakDay('Mo', practiced: false),
      const CompletionStreakDay('Tu', practiced: false),
    ]),
  );

  @override
  CompletionSummary summary(
    SessionReceipt receipt, {
    required int mistakeCount,
  }) {
    final perfect = receipt.accuracy == 1;
    final practice = receipt.guest || receipt.placement;
    final mistakes = mistakeCount < 0 ? 0 : mistakeCount;
    final accuracy = (receipt.accuracy * 100).round();
    return CompletionSummary(
      perfect: perfect,
      claimLabel: 'CLAIM XP',
      title: practice
          ? 'Practice complete'
          : perfect
          ? 'Flawless'
          : 'Lesson complete!',
      description: practice
          ? null
          : perfect
          ? '0 mistakes. You’re like a pristine, freshwater pearl.'
          : '$mistakes ${mistakes == 1 ? 'mistake' : 'mistakes'} reviewed. '
                'Keep up the great work!',
      xp: CompletionStat(
        label: 'TOTAL XP',
        semanticLabel: 'Total XP, ${receipt.xp}',
        value: '${receipt.xp}',
        animatedValue: receipt.xp,
      ),
      accuracy: CompletionStat(
        label: perfect ? 'AMAZING' : 'GREAT',
        semanticLabel: 'Accuracy, $accuracy percent',
        value: '$accuracy%',
        animatedValue: accuracy,
        suffix: '%',
      ),
      time: CompletionStat(
        label: perfect ? 'BLAZING' : 'QUICK',
        semanticLabel: 'Time, ${_spokenElapsed(receipt.elapsed)}',
        value: _elapsed(receipt.elapsed),
      ),
    );
  }
}

String _elapsed(Duration elapsed) {
  final seconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

String _spokenElapsed(Duration elapsed) {
  final seconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  final parts = <String>[];
  if (hours > 0) parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
  if (minutes > 0) {
    parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
  }
  if (remainder > 0 || parts.isEmpty) {
    parts.add('$remainder ${remainder == 1 ? 'second' : 'seconds'}');
  }
  return parts.join(' ');
}
