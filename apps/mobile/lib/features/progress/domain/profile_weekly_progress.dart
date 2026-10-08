class WeeklyXpSeries {
  WeeklyXpSeries({required this.label, required List<int> points})
    : assert(points.length == 7),
      assert(points.every((point) => point >= 0)),
      points = List<int>.unmodifiable(points);

  final String label;
  final List<int> points;

  int get totalXp => points.fold(0, (total, point) => total + point);
}

class ProfileWeeklyProgressData {
  ProfileWeeklyProgressData({
    required this.userId,
    required this.owner,
    required this.you,
    required List<int> axisTicks,
  }) : assert(axisTicks.length == 4),
       axisTicks = List<int>.unmodifiable(axisTicks);

  final String userId;
  final WeeklyXpSeries owner;
  final WeeklyXpSeries you;
  final List<int> axisTicks;

  int get axisMaximum => axisTicks.last;
}

const weeklyDayLabels = <String>['T', 'W', 'T', 'F', 'S', 'S', 'M'];
const weeklyDayNames = <String>[
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
  'Monday',
];
