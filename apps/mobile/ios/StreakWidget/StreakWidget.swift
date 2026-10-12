// CocEnglish home-screen streak widget (WidgetKit).
//
// Reads the values Flutter writes through `home_widget` into the shared App
// Group (keys from lib/features/reminders/domain/streak_home_widget.dart).
// Setup steps that need Xcode are in ios/StreakWidget/README.md.
import SwiftUI
import WidgetKit

private let appGroup = "group.com.cocenglish.cocenglish"

struct StreakEntry: TimelineEntry {
  let date: Date
  let streak: Int
  let flame: String  // lit | atRisk | none
  let headline: String
  let goalMinutes: Int
  let todayMinutes: Int
  let goalPercent: Int
  let link: String

  static let placeholder = StreakEntry(
    date: Date(), streak: 7, flame: "lit", headline: "Lửa đã cháy hôm nay 🔥",
    goalMinutes: 10, todayMinutes: 6, goalPercent: 60, link: "/home")
}

struct StreakProvider: TimelineProvider {
  func placeholder(in context: Context) -> StreakEntry { .placeholder }

  func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
    completion(context.isPreview ? .placeholder : read())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
    // Re-read after local midnight so "lit" turns into "at risk" on a new day
    // even if the app is not opened; Flutter also reloads after each lesson.
    let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
    completion(Timeline(entries: [read()], policy: .after(midnight)))
  }

  private func read() -> StreakEntry {
    let d = UserDefaults(suiteName: appGroup)
    return StreakEntry(
      date: Date(),
      streak: d?.integer(forKey: "coc_streak") ?? 0,
      flame: d?.string(forKey: "coc_flame") ?? "none",
      headline: d?.string(forKey: "coc_headline") ?? "Mở app để bắt đầu chuỗi!",
      goalMinutes: max(d?.integer(forKey: "coc_goal_minutes") ?? 10, 1),
      todayMinutes: d?.integer(forKey: "coc_today_minutes") ?? 0,
      goalPercent: d?.integer(forKey: "coc_goal_percent") ?? 0,
      link: d?.string(forKey: "coc_link") ?? "/home")
  }
}

private let accent = Color(red: 0x5B / 255, green: 0xCD / 255, blue: 0x05 / 255)
private let flameOn = Color(red: 1, green: 0x96 / 255, blue: 0)
private let flameOff = Color(red: 0xB0 / 255, green: 0xAE / 255, blue: 0xB0 / 255)
private let ink = Color(red: 0x4D / 255, green: 0x4B / 255, blue: 0x4E / 255)
private let border = Color(red: 0xE7 / 255, green: 0xE5 / 255, blue: 0xE7 / 255)

struct StreakWidgetView: View {
  let entry: StreakEntry

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: entry.flame == "none" ? "flame" : "flame.fill")
        .font(.system(size: 34, weight: .bold))
        .foregroundStyle(entry.flame == "lit" ? flameOn : flameOff)
        .accessibilityLabel("Ngọn lửa chuỗi ngày học")
      VStack(alignment: .leading, spacing: 4) {
        Text("\(entry.streak)")
          .font(.system(size: 26, weight: .heavy, design: .rounded))
          .foregroundStyle(entry.flame == "lit" ? flameOn : flameOff)
        Text(entry.headline)
          .font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(ink)
          .lineLimit(2)
        ProgressView(value: Double(entry.goalPercent), total: 100)
          .tint(accent)
        Text("\(min(entry.todayMinutes, entry.goalMinutes))/\(entry.goalMinutes) phút hôm nay")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
      }
    }
    .widgetURL(URL(string: "cocenglish://widget\(entry.link)?homeWidget"))
    .containerBackground(for: .widget) { Color.white }
  }
}

@main
struct StreakWidget: Widget {
  let kind = "StreakWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
      StreakWidgetView(entry: entry)
    }
    .configurationDisplayName("Chuỗi ngày học")
    .description("Xem chuỗi ngày học và mục tiêu hôm nay.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
