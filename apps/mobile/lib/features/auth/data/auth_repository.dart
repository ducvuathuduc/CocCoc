import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/auth_state.dart';
import '../services/appwrite_auth_service.dart';

abstract interface class AuthRepository {
  Future<AuthUser> signIn(String email, String password);
  Future<void> sendRecovery(String email);
  Future<void> resetPassword(String userId, String secret, String password);
  Future<AuthUser> socialSignIn(AuthProvider provider);
  Future<AuthUser?> restoreSession();
  Future<AuthUser?> rememberedAccount();
  Future<void> forgetAccount();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

class AppwriteAuthRepository implements AuthRepository {
  AppwriteAuthRepository(this.service, [SharedPreferencesAsync? preferences])
    : _preferences = preferences;

  static const rememberedKey = 'auth.remembered.v1';
  static const _requestError =
      'We couldn’t complete that request. Please try again.';

  final AppwriteAuthService service;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _storage =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final user = await service.signIn(email, password);
      await _rememberBestEffort(user);
      return user;
    } on AppwriteAuthServiceException catch (error) {
      throw AuthFailure(error.message);
    } on Object {
      throw const AuthFailure(_requestError);
    }
  }

  @override
  Future<void> sendRecovery(String email) async {
    try {
      await service.sendRecovery(email);
    } on AppwriteAuthServiceException catch (error) {
      throw AuthFailure(error.message);
    } on Object {
      throw const AuthFailure(_requestError);
    }
  }

  @override
  Future<void> resetPassword(
    String userId,
    String secret,
    String password,
  ) async {
    try {
      await service.resetPassword(userId, secret, password);
    } on AppwriteAuthServiceException catch (error) {
      throw AuthFailure(error.message);
    } on Object {
      throw const AuthFailure(_requestError);
    }
  }

  @override
  Future<AuthUser> socialSignIn(AuthProvider provider) async {
    try {
      final user = await service.socialSignIn(provider);
      await _rememberBestEffort(user);
      return user;
    } on AppwriteAuthServiceException catch (error) {
      throw AuthFailure(error.message);
    } on Object {
      throw const AuthFailure(_requestError);
    }
  }

  @override
  Future<AuthUser?> restoreSession() async {
    try {
      final user = await service.restoreSession();
      if (user != null) await _rememberBestEffort(user);
      return user;
    } on AppwriteAuthServiceException catch (error) {
      throw AuthFailure(error.message);
    } on Object {
      throw const AuthFailure(_requestError);
    }
  }

  @override
  Future<AuthUser?> rememberedAccount() async {
    if (!service.isConfigured) return null;
    String? value;
    try {
      value = await _storage.getString(rememberedKey);
    } on MissingPluginException {
      return null;
    } on Object {
      throw const AuthFailure(_requestError);
    }
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['version'] != 1) return null;
      final id = json['id'] as String;
      final email = json['email'] as String;
      final name = json['name'] as String;
      if (id.isEmpty || email.isEmpty) return null;
      return AuthUser(id: id, email: email, name: name);
    } on Object {
      await _forgetBestEffort();
      return null;
    }
  }

  @override
  Future<void> forgetAccount() async {
    if (!service.isConfigured) return;
    try {
      await _storage.remove(rememberedKey);
    } on MissingPluginException {
      return;
    } on Object {
      throw const AuthFailure(_requestError);
    }
  }

  Future<void> _rememberBestEffort(AuthUser user) async {
    try {
      await _storage.setString(
        rememberedKey,
        jsonEncode({
          'version': 1,
          'id': user.id,
          'email': user.email,
          'name': user.name,
        }),
      );
    } on Object {
      // A verified SDK session remains valid if local metadata cannot be saved.
    }
  }

  Future<void> _forgetBestEffort() async {
    try {
      await _storage.remove(rememberedKey);
    } on Object {
      // Corrupt metadata is treated as absent even when cleanup cannot persist.
    }
  }
}
