import 'package:home_widget/home_widget.dart';

import '../domain/streak_home_widget.dart';

/// Native home-screen widget I/O (Android AppWidget, iOS WidgetKit).
abstract class HomeWidgetGateway {
  Future<void> init();
  Future<void> publish(StreakHomeWidgetData data);

  /// In-app location of a widget tap that cold-started the app.
  Future<String?> launchLink();

  /// In-app locations of widget taps while the app is running.
  Stream<String?> get taps;
}

class NoopHomeWidgetGateway implements HomeWidgetGateway {
  @override
  Future<void> init() async {}
  @override
  Future<void> publish(StreakHomeWidgetData data) async {}
  @override
  Future<String?> launchLink() async => null;
  @override
  Stream<String?> get taps => const Stream.empty();
}

/// `home_widget` implementation. The App Group is shared with the iOS
/// `StreakWidget` extension; Android reads the same keys from
/// `HomeWidgetPreferences`.
class PluginHomeWidgetGateway implements HomeWidgetGateway {
  static const appGroupId = 'group.com.cocenglish.cocenglish';
  static const androidProvider =
      'com.cocenglish.cocenglish.StreakWidgetProvider';
  static const iOSKind = 'StreakWidget';

  @override
  Future<void> init() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  @override
  Future<void> publish(StreakHomeWidgetData data) async {
    for (final e in data.toStorage().entries) {
      await HomeWidget.saveWidgetData<Object>(e.key, e.value);
    }
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidProvider,
      iOSName: iOSKind,
    );
  }

  /// `cocenglish://widget/home` → `/home`.
  static String? _link(Uri? uri) {
    if (uri == null || uri.host != 'widget') return null;
    return uri.path.isEmpty ? '/home' : uri.path;
  }

  @override
  Future<String?> launchLink() async =>
      _link(await HomeWidget.initiallyLaunchedFromHomeWidget());

  @override
  Stream<String?> get taps => HomeWidget.widgetClicked.map(_link);
}
