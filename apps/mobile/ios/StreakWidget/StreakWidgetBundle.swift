import SwiftUI
import WidgetKit

@main
struct StreakWidgetBundle: WidgetBundle {
  var body: some Widget {
    StreakWidget()
    LessonLiveActivity()
  }
}
