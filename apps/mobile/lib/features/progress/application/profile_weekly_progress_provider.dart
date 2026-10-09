import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../learning/application/learning_controller.dart';
import '../domain/profile_weekly_progress.dart';
import 'profile_summary_provider.dart';

const _weeklyFixtures = <String, List<int>>{
  'Alex': [10, 15, 20, 10, 25, 20, 20],
  'Maria': [20, 18, 32, 24, 30, 28, 26],
  'Lucas': [8, 12, 16, 10, 20, 14, 18],
  'Anna': [25, 28, 35, 20, 30, 38, 34],
  'Samira': [15, 18, 22, 16, 24, 26, 21],
  'Sam Lee': [18, 20, 25, 20, 28, 30, 24],
  'Noah': [5, 8, 12, 10, 14, 12, 15],
  'Emma': [20, 25, 30, 26, 32, 35, 30],
  'James Smith': [12, 16, 20, 14, 24, 22, 24],
};

final profileWeeklyProgressProvider =
    Provider.family<ProfileWeeklyProgressData?, String>((ref, userId) {
      final fixture = _weeklyFixtures[userId];
      final summary = ref.watch(profileSummaryProvider(userId));
      if (fixture == null || summary == null) return null;
      final learnerXp = ref.watch(
        learningStateProvider.select((learning) => learning.xp),
      );
      final owner = WeeklyXpSeries(label: summary.name, points: fixture);
      final you = WeeklyXpSeries(
        label: 'You',
        points: [0, 0, 0, 0, 0, 0, learnerXp],
      );
      return ProfileWeeklyProgressData(
        userId: userId,
        owner: owner,
        you: you,
        axisTicks: _axisTicks([...owner.points, ...you.points]),
      );
    });

List<int> _axisTicks(List<int> points) {
  final maximum = points.fold<int>(0, math.max);
  final step = _niceStep(math.max(1, maximum) / 3);
  return List<int>.unmodifiable([0, step, step * 2, step * 3]);
}

int _niceStep(double value) {
  final magnitude = math
      .pow(10, (math.log(value) / math.ln10).floor())
      .toDouble();
  final normalized = value / magnitude;
  final factor = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return (factor * magnitude).ceil();
}
