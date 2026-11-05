import 'package:flutter/material.dart';

enum AppearancePreference {
  system('system', 'System Default', ThemeMode.system),
  dark('dark', 'On', ThemeMode.dark),
  light('light', 'Off', ThemeMode.light);

  const AppearancePreference(this.storageValue, this.label, this.themeMode);

  final String storageValue;
  final String label;
  final ThemeMode themeMode;
}

class AppearanceState {
  const AppearanceState({
    this.preference = AppearancePreference.system,
    this.restoring = true,
    this.saving = false,
    this.saveFailed = false,
  });

  final AppearancePreference preference;
  final bool restoring;
  final bool saving;
  final bool saveFailed;

  ThemeMode get themeMode => preference.themeMode;

  AppearanceState copyWith({
    AppearancePreference? preference,
    bool? restoring,
    bool? saving,
    bool? saveFailed,
  }) => AppearanceState(
    preference: preference ?? this.preference,
    restoring: restoring ?? this.restoring,
    saving: saving ?? this.saving,
    saveFailed: saveFailed ?? this.saveFailed,
  );
}
