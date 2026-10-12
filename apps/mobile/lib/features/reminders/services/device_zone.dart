import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The device IANA zone as a `timezone` [tz.Location].
abstract class DeviceZone {
  Future<tz.Location> current();
}

bool _tzReady = false;

/// Loads the bundled tz database once (pure Dart, no platform channel).
void ensureTimeZones() {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  _tzReady = true;
}

class FixedDeviceZone implements DeviceZone {
  FixedDeviceZone(this.id);
  final String id;
  @override
  Future<tz.Location> current() async {
    ensureTimeZones();
    return tz.getLocation(id);
  }
}

class PluginDeviceZone implements DeviceZone {
  @override
  Future<tz.Location> current() async {
    ensureTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(info.identifier);
      tz.setLocalLocation(location);
      return location;
    } catch (error) {
      // Unknown or legacy zone id: fall back to UTC rather than not reminding.
      debugPrint('Device timezone unavailable: $error');
      return tz.UTC;
    }
  }
}
