import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

private let lessonResumeURL = URL(string: "cocenglish:///activity/resume")!
private let lessonGreen = Color(red: 0.35, green: 0.80, blue: 0.00)
private let warningRed = Color(red: 0.31, green: 0.00, blue: 0.00)

struct LessonLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LessonActivityAttributes.self) { context in
      LessonLockScreenView(state: context.state)
        .widgetURL(lessonResumeURL)
        .activityBackgroundTint(context.state.paused ? warningRed : .white)
        .activitySystemActionForegroundColor(context.state.paused ? .white : .black)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image("LessonAppIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
        }
        DynamicIslandExpandedRegion(.trailing) {
          LessonHearts(state: context.state)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 10) {
            Text(context.state.paused ? "Resume your lesson" : "Keep learning")
              .font(.system(size: 18, weight: .bold, design: .rounded))
            ProgressView(
              value: Double(context.state.completed),
              total: Double(context.state.total)
            )
            .tint(context.state.paused ? .yellow : lessonGreen)
          }
        }
      } compactLeading: {
        Image("LessonIslandIcon")
          .resizable()
          .scaledToFit()
          .frame(width: 20, height: 20)
          .accessibilityLabel("CocEnglish lesson")
      } compactTrailing: {
        Image(systemName: "arrow.right")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(lessonGreen)
          .accessibilityLabel("Resume lesson")
      } minimal: {
        Image("LessonIslandIcon")
          .resizable()
          .scaledToFit()
          .accessibilityLabel("CocEnglish lesson")
      }
      .widgetURL(lessonResumeURL)
      .keylineTint(lessonGreen)
    }
  }
}

private struct LessonLockScreenView: View {
  let state: LessonActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 12) {
        Text(state.paused ? "Lesson paused" : "English")
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(state.paused ? .white.opacity(0.75) : .secondary)
        Text(state.paused ? "Resume your lesson" : "\(remaining) exercises left!")
          .font(.system(size: 23, weight: .heavy, design: .rounded))
          .foregroundStyle(state.paused ? .white : Color(red: 0.30, green: 0.29, blue: 0.30))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
        HStack(spacing: 22) {
          Label("\(state.completed)/\(state.total)", systemImage: "checkmark.star.fill")
            .foregroundStyle(state.paused ? .yellow : Color(red: 1.00, green: 0.78, blue: 0.14))
          Label(elapsed, systemImage: "stopwatch.fill")
            .foregroundStyle(state.paused ? .white : Color(red: 0.22, green: 0.66, blue: 0.96))
          Label("\(state.streak)", systemImage: "flame.fill")
            .foregroundStyle(state.paused ? .white : .secondary)
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .labelStyle(.titleAndIcon)
      }
      Spacer(minLength: 0)
      Image(state.paused ? "LessonWarningDuo" : "LessonLockDuo")
        .resizable()
        .scaledToFit()
        .frame(width: state.paused ? 130 : 100, height: 102, alignment: .bottomTrailing)
        .accessibilityHidden(true)
    }
    .padding(16)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      state.paused
        ? "Lesson paused. Resume your lesson."
        : "English lesson. \(remaining) exercises left. \(elapsed) elapsed."
    )
  }

  private var remaining: Int { max(state.total - state.completed, 0) }

  private var elapsed: String {
    String(format: "%d:%02d", state.elapsedSeconds / 60, state.elapsedSeconds % 60)
  }
}

private struct LessonHearts: View {
  let state: LessonActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "heart.fill")
        .foregroundStyle(Color(red: 0.20, green: 0.89, blue: 0.69))
      if state.unlimited {
        Image(systemName: "infinity")
          .foregroundStyle(Color(red: 0.40, green: 0.47, blue: 1.00))
      } else {
        Text("\(state.hearts)")
          .font(.system(size: 16, weight: .bold, design: .rounded))
      }
    }
    .accessibilityLabel(state.unlimited ? "Unlimited hearts" : "\(state.hearts) hearts")
  }
}
