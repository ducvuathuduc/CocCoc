# iOS streak widget (WidgetKit)

Source for the home-screen streak widget lives here, but the Xcode target is
not yet in `Runner.xcodeproj` (it has to be created in Xcode on a Mac; this
repository is built on Linux, where the project file cannot be validated).

One-time setup in Xcode:

1. File > New > Target > **Widget Extension**, product name `StreakWidget`,
   bundle id `com.cocenglish.cocenglish.StreakWidget`, uncheck "Include
   Configuration App Intent". Delete the generated Swift file and add
   `StreakWidget.swift`, `Info.plist` and `StreakWidget.entitlements` from
   this folder to the target. Deployment target iOS 17 (uses
   `containerBackground`).
2. Runner target > Signing & Capabilities > **App Groups** >
   `group.com.cocenglish.cocenglish` (use `Runner/Runner.entitlements`).
   Add the same App Group to the StreakWidget target.
3. Build. Flutter writes the data with `home_widget`
   (`PluginHomeWidgetGateway`, `iOSName: StreakWidget`) after every lesson
   and on app start; the widget reloads its timeline after local midnight.

Taps open `cocenglish://widget/home?homeWidget`; `home_widget` hands the URL
to Dart, which routes to the learning path.
