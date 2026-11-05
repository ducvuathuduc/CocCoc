import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct LessonActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let completed: Int
    let total: Int
    let hearts: Int
    let unlimited: Bool
    let elapsedSeconds: Int
    let streak: Int
    let paused: Bool
  }

  let lessonId: String
}
