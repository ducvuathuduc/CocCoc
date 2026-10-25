import ActivityKit
import Flutter
import UIKit

@MainActor
final class LessonActivityBridge {
  private static let channelName = "cocenglish/lesson_activity"
  private let channel: FlutterMethodChannel
  private var pendingTask: Task<Void, Never>?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(false)
        return
      }
      let previous = self.pendingTask
      let task = Task { @MainActor [weak self] in
        await previous?.value
        guard let self else {
          result(false)
          return
        }
        switch call.method {
        case "sync":
          guard let input = Input(call.arguments) else {
            result(false)
            return
          }
          result(await self.sync(input))
        case "end":
          result(await self.endAll())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      self.pendingTask = task
    }
  }

  private func sync(_ input: Input) async -> Bool {
    guard #available(iOS 16.2, *) else { return false }

    let activities = Activity<LessonActivityAttributes>.activities
    let matching = activities.filter { $0.attributes.lessonId == input.lessonId }
    for activity in activities where activity.attributes.lessonId != input.lessonId {
      await end(activity)
    }
    for duplicate in matching.dropFirst() {
      await end(duplicate)
    }

    let content = ActivityContent(
      state: input.contentState,
      staleDate: nil,
      relevanceScore: input.paused ? 50 : 100
    )
    if let current = matching.first {
      await current.update(content)
      return true
    }

    guard !input.paused,
      UIApplication.shared.applicationState == .active,
      ActivityAuthorizationInfo().areActivitiesEnabled
    else {
      return false
    }

    do {
      _ = try Activity.request(
        attributes: LessonActivityAttributes(lessonId: input.lessonId),
        content: content,
        pushType: nil
      )
      return true
    } catch {
      return false
    }
  }

  private func endAll() async -> Bool {
    guard #available(iOS 16.2, *) else { return false }
    for activity in Activity<LessonActivityAttributes>.activities {
      await end(activity)
    }
    return true
  }

  @available(iOS 16.2, *)
  private func end(_ activity: Activity<LessonActivityAttributes>) async {
    let finalContent = ActivityContent(
      state: activity.content.state,
      staleDate: nil
    )
    await activity.end(finalContent, dismissalPolicy: .immediate)
  }
}

private extension LessonActivityBridge {
  struct Input {
    let lessonId: String
    let completed: Int
    let total: Int
    let hearts: Int
    let unlimited: Bool
    let elapsedSeconds: Int
    let streak: Int
    let paused: Bool

    init?(_ arguments: Any?) {
      guard let values = arguments as? [String: Any],
        let rawLessonId = values["lessonId"] as? String,
        let rawCompleted = values["completed"] as? Int,
        let rawTotal = values["total"] as? Int,
        let rawHearts = values["hearts"] as? Int,
        let unlimited = values["unlimited"] as? Bool,
        let rawElapsedSeconds = values["elapsedSeconds"] as? Int,
        let rawStreak = values["streak"] as? Int,
        let paused = values["paused"] as? Bool
      else {
        return nil
      }

      let normalizedLessonId = rawLessonId.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !normalizedLessonId.isEmpty else { return nil }

      lessonId = String(normalizedLessonId.prefix(128))
      total = min(max(rawTotal, 1), 1_000)
      completed = min(max(rawCompleted, 0), total)
      hearts = min(max(rawHearts, 0), 99)
      self.unlimited = unlimited
      elapsedSeconds = min(max(rawElapsedSeconds, 0), 28_800)
      streak = min(max(rawStreak, 0), 100_000)
      self.paused = paused
    }

    @available(iOS 16.2, *)
    var contentState: LessonActivityAttributes.ContentState {
      LessonActivityAttributes.ContentState(
        completed: completed,
        total: total,
        hearts: hearts,
        unlimited: unlimited,
        elapsedSeconds: elapsedSeconds,
        streak: streak,
        paused: paused
      )
    }
  }
}
