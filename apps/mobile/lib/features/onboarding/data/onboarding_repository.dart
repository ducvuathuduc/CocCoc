import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/onboarding_state.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingState> load();
  Future<void> save(OnboardingState state);
}

class MemoryOnboardingRepository implements OnboardingRepository {
  MemoryOnboardingRepository([OnboardingState? initial])
    : state = initial ?? OnboardingState();
  OnboardingState state;
  @override
  Future<OnboardingState> load() async => state;
  @override
  Future<void> save(OnboardingState state) async {
    this.state = state;
  }
}

class PreferencesOnboardingRepository implements OnboardingRepository {
  PreferencesOnboardingRepository(this.preferences, {this.storageKey = key});
  final SharedPreferencesAsync preferences;
  static const key = 'onboarding.reference.v1';
  final String storageKey;

  @override
  Future<OnboardingState> load() async {
    final value = await preferences.getString(storageKey);
    if (value == null) return OnboardingState();
    try {
      return OnboardingState.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } on Object {
      return OnboardingState();
    }
  }

  @override
  Future<void> save(OnboardingState state) =>
      preferences.setString(storageKey, jsonEncode(state.toJson()));
}
