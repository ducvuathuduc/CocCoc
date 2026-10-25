import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../domain/appearance_preference.dart';

abstract interface class AppearanceRepository {
  Future<AppearancePreference> load();
  Future<void> save(AppearancePreference preference);
}

final class PreferencesAppearanceRepository implements AppearanceRepository {
  PreferencesAppearanceRepository([SharedPreferencesAsync? preferences])
    : _preferences = preferences;

  static const storageKey = 'appearance.theme.v1';
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<AppearancePreference> load() async {
    try {
      final stored = await _store.getString(storageKey);
      return AppearancePreference.values.firstWhere(
        (value) => value.storageValue == stored,
        orElse: () => AppearancePreference.system,
      );
    } on MissingPluginException {
      return AppearancePreference.system;
    } on StateError {
      return AppearancePreference.system;
    }
  }

  @override
  Future<void> save(AppearancePreference preference) async {
    try {
      await _store.setString(storageKey, preference.storageValue);
    } on MissingPluginException {
      // Widget tests and unsupported hosts keep the in-memory selection.
    } on StateError {
      // SharedPreferences has no registered platform on unsupported hosts.
    }
  }
}
