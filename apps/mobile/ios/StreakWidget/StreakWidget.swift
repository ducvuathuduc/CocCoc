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

private enum StreakMood: String {
  case ready, early, practice, lastChance, save, protected, away
}

private struct StreakStyle {
  let title: String
  let smallTitle: String
  let start: Color
  let end: Color
  let asset: String
  let weekdays: [(String, Bool)]

  var mediumAsset: String { "\(asset)Medium" }
  var smallAsset: String { "\(asset)Small" }
}

private extension StreakMood {
  var style: StreakStyle {
    switch self {
    case .ready:
      StreakStyle(
        title: "Ready to start learning?", smallTitle: "Ready to start learning?",
        start: Color(red: 0.00, green: 0.65, blue: 0.96),
        end: Color(red: 0.67, green: 0.90, blue: 0.99), asset: "WidgetReady", weekdays: [])
    case .early:
      StreakStyle(
        title: "Get started early!", smallTitle: "Get started early!",
        start: Color(red: 0.22, green: 0.59, blue: 0.91),
        end: Color(red: 0.51, green: 0.73, blue: 0.94), asset: "WidgetEarly",
        weekdays: [("T", true), ("F", true), ("S", true), ("S", true), ("M", false)])
    case .practice:
      StreakStyle(
        title: "Please practice!", smallTitle: "Extend your streak!",
        start: Color(red: 0.62, green: 0.26, blue: 0.96),
        end: Color(red: 0.75, green: 0.40, blue: 0.93), asset: "WidgetPractice",
        weekdays: [("F", true), ("S", true), ("S", true), ("M", true), ("T", false)])
    case .lastChance:
      StreakStyle(
        title: "Last chance!", smallTitle: "Last chance!",
        start: Color(red: 0.69, green: 0.20, blue: 0.00),
        end: Color(red: 0.60, green: 0.03, blue: 0.31), asset: "WidgetLastChance",
        weekdays: [("F", true), ("S", true), ("S", true), ("M", true), ("T", false)])
    case .save:
      StreakStyle(
        title: "Save your streak!", smallTitle: "Don’t forget me!",
        start: Color(red: 0.22, green: 0.01, blue: 0.00),
        end: Color(red: 0.67, green: 0.17, blue: 0.16), asset: "WidgetSave",
        weekdays: [("S", true), ("M", true), ("T", true), ("W", true), ("T", false)])
    case .protected:
      StreakStyle(
        title: "Don’t forget me!", smallTitle: "Come back soon!",
        start: Color(red: 0.28, green: 0.02, blue: 0.16),
        end: Color(red: 0.67, green: 0.09, blue: 0.35), asset: "WidgetProtected",
        weekdays: [("F", true), ("S", true), ("S", true), ("M", true), ("T", true)])
    case .away:
      StreakStyle(
        title: "Come back to English!", smallTitle: "Come back to English!",
        start: Color(red: 0.07, green: 0.14, blue: 0.32),
        end: Color(red: 0.09, green: 0.53, blue: 0.67), asset: "WidgetAway", weekdays: [])
    }
  }
}

struct StreakWidgetView: View {
  let entry: StreakEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let style = mood.style
    ZStack(alignment: .bottomTrailing) {
      LinearGradient(colors: [style.start, style.end], startPoint: .topLeading, endPoint: .bottomTrailing)
      Image(family == .systemSmall ? style.smallAsset : style.mediumAsset)
        .resizable()
        .scaledToFit()
        .frame(
          maxWidth: family == .systemSmall ? .infinity : 145,
          maxHeight: family == .systemSmall ? 82 : 100,
          alignment: .bottomTrailing
        )
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 5) {
        if mood != .ready {
          Label(family == .systemSmall ? "\(entry.streak)" : "\(entry.streak) days", systemImage: "flame.fill")
            .font(.system(size: 23, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .labelStyle(.titleAndIcon)
        }
        Text(family == .systemSmall ? style.smallTitle : style.title)
          .font(.system(size: mood == .ready ? 20 : 16, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(2)
          .minimumScaleFactor(0.75)
        if family == .systemMedium && !style.weekdays.isEmpty {
          HStack(spacing: 9) {
            ForEach(Array(style.weekdays.enumerated()), id: \.offset) { _, day in
              VStack(spacing: 3) {
                Text(day.0).font(.system(size: 10, weight: .bold, design: .rounded))
                Image(systemName: day.1 ? "checkmark.circle.fill" : "circle.fill")
                  .font(.system(size: 14, weight: .bold))
                  .opacity(day.1 ? 1 : 0.35)
              }
            }
          }
          .foregroundStyle(.white)
        }
        Spacer(minLength: family == .systemSmall ? 52 : 0)
      }
      .frame(maxWidth: family == .systemSmall ? .infinity : 190, alignment: .leading)
      .padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .widgetURL(URL(string: "cocenglish://widget\(entry.link)?homeWidget"))
    .containerBackground(for: .widget) { style.start }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(entry.streak) day streak. \(family == .systemSmall ? style.smallTitle : style.title)")
  }

  private var mood: StreakMood {
    let defaults = UserDefaults(suiteName: appGroup)
    if let raw = defaults?.string(forKey: "coc_widget_mood"), let selected = StreakMood(rawValue: raw) {
      return selected
    }
    if entry.streak == 0 { return .ready }
    return entry.flame == "lit" ? .practice : .lastChance
  }
}

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
