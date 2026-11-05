# iOS streak widget (WidgetKit)

The home-screen streak widget is wired into `Runner.xcodeproj` as the
`StreakWidget` extension target and embedded in the Runner app.

Signing setup in Xcode:

1. Select the same signing team for Runner and StreakWidget. The repository
   intentionally does not hard-code a development team.
2. Confirm `group.com.cocenglish.cocenglish` exists for both App IDs in the
   selected Apple Developer account. Both targets already use the matching
   entitlement files.
3. Build on a Mac with Xcode. Flutter writes the data with `home_widget`
   (`PluginHomeWidgetGateway`, `iOSName: StreakWidget`) after every lesson
   and on app start; the widget reloads its timeline after local midnight.

Taps open `cocenglish://widget/home?homeWidget`; `home_widget` hands the URL
to Dart, which routes to the learning path.

`coc_widget_mood` selects one of the seven source-backed visuals: `ready`,
`early`, `practice`, `lastChance`, `save`, `protected` or `away`. Missing or
unknown values fall back from the current streak and flame state.

The same extension contains `LessonLiveActivity`. Runner owns the
`cocenglish/lesson_activity` method channel and starts, updates or ends the
single current lesson activity without push tokens or network access. Live
Activity taps open `cocenglish:///activity/resume`.
