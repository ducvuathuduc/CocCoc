import 'reminder_models.dart';
import '../../progress/domain/streak_widget.dart';

/// Flame state on the home-screen streak widget.
enum WidgetFlame {
  /// A lesson was completed today.
  lit,

  /// There is a streak and today is not practised yet.
  atRisk,

  /// No streak yet (or it was lost).
  none,
}

/// Data the native Android AppWidget / iOS WidgetKit extension renders.
/// Keys are shared with the native code; keep them in sync with
/// `StreakWidgetProvider.kt` and `ios/StreakWidget/StreakWidget.swift`.
class StreakHomeWidgetData {
  const StreakHomeWidgetData({
    required this.streak,
    required this.flame,
    required this.goalMinutes,
    required this.todayMinutes,
    required this.headline,
    this.mood = StreakWidgetMood.ready,
    this.link = ReminderLinks.lesson,
  });

  factory StreakHomeWidgetData.from({
    required int streak,
    required bool practicedToday,
    required int goalMinutes,
    required int todayMinutes,
    StreakWidgetMood mood = StreakWidgetMood.ready,
  }) {
    final flame = practicedToday
        ? WidgetFlame.lit
        : streak > 0
        ? WidgetFlame.atRisk
        : WidgetFlame.none;
    final goal = goalMinutes <= 0 ? 10 : goalMinutes;
    final done = todayMinutes.clamp(0, 24 * 60);
    final headline = switch (flame) {
      WidgetFlame.lit when done >= goal => 'Xong mục tiêu hôm nay! 🎉',
      WidgetFlame.lit => 'Lửa đã cháy hôm nay 🔥',
      WidgetFlame.atRisk => 'Học ngay để giữ chuỗi!',
      WidgetFlame.none => 'Bắt đầu chuỗi mới nào!',
    };
    return StreakHomeWidgetData(
      streak: streak < 0 ? 0 : streak,
      flame: flame,
      goalMinutes: goal,
      todayMinutes: done,
      headline: headline,
      mood: mood,
    );
  }

  final int streak, goalMinutes, todayMinutes;
  final WidgetFlame flame;
  final StreakWidgetMood mood;
  final String headline, link;

  /// 0..100 daily goal progress.
  int get goalPercent =>
      ((todayMinutes / goalMinutes) * 100).clamp(0, 100).round();

  Map<String, Object> toStorage() => {
    'coc_streak': streak,
    'coc_flame': flame.name,
    'coc_goal_minutes': goalMinutes,
    'coc_today_minutes': todayMinutes,
    'coc_goal_percent': goalPercent,
    'coc_headline': headline,
    'coc_widget_mood': mood.name,
    'coc_link': link,
  };
}
