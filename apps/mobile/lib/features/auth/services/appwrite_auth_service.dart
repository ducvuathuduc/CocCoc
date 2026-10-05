import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:appwrite/models.dart' as appwrite_models;
import 'package:flutter/foundation.dart';

import '../domain/auth_state.dart';

class AppwriteAuthServiceException implements Exception {
  const AppwriteAuthServiceException(this.message);

  final String message;
}

class AppwriteAuthService {
  AppwriteAuthService._({
    required this._account,
    required this.recoveryUrl,
    required this.googleEnabled,
    required this.facebookEnabled,
    required this.appleEnabled,
  });

  factory AppwriteAuthService.fromEnvironment() {
    const endpoint = String.fromEnvironment('APPWRITE_ENDPOINT');
    const projectId = String.fromEnvironment('APPWRITE_PROJECT_ID');
    const recoveryUrl = String.fromEnvironment('APPWRITE_RECOVERY_URL');
    const googleEnabled = bool.fromEnvironment('APPWRITE_GOOGLE_ENABLED');
    const facebookEnabled = bool.fromEnvironment('APPWRITE_FACEBOOK_ENABLED');
    const appleEnabled = bool.fromEnvironment('APPWRITE_APPLE_ENABLED');

    final endpointUri = Uri.tryParse(endpoint);
    final configured =
        endpointUri != null &&
        endpointUri.scheme == 'https' &&
        endpointUri.host.isNotEmpty &&
        projectId.trim().isNotEmpty;
    final account = configured
        ? Account(Client().setEndpoint(endpoint).setProject(projectId))
        : null;
    return AppwriteAuthService._(
      account: account,
      recoveryUrl: recoveryUrl,
      googleEnabled: googleEnabled,
      facebookEnabled: facebookEnabled,
      appleEnabled: appleEnabled,
    );
  }

  static const configurationMessage =
      'Sign-in isn’t connected yet. Please try again later.';
  static const signInMessage =
      'We couldn’t sign you in. Check your email and password and try again.';
  static const requestMessage =
      'We couldn’t complete that request. Please try again.';
  static const socialMessage =
      'That sign-in option isn’t available right now. Please try again.';

  final Account? _account;
  final String recoveryUrl;
  final bool googleEnabled;
  final bool facebookEnabled;
  final bool appleEnabled;

  bool get isConfigured => _account != null;

  Set<AuthProvider> availableProviders(TargetPlatform platform) {
    if (!isConfigured) return const {};
    return {
      if (googleEnabled) AuthProvider.google,
      if (facebookEnabled) AuthProvider.facebook,
      if (appleEnabled && platform == TargetPlatform.iOS) AuthProvider.apple,
    };
  }

  Account _configuredAccount() {
    final account = _account;
    if (account == null) {
      throw const AppwriteAuthServiceException(configurationMessage);
    }
    return account;
  }

  Future<AuthUser> signIn(String email, String password) async {
    final account = _configuredAccount();
    try {
      await account.createEmailPasswordSession(
        email: email.trim(),
        password: password,
      );
      return _toAuthUser(await account.get());
    } on Object {
      throw const AppwriteAuthServiceException(signInMessage);
    }
  }

  Future<void> sendRecovery(String email) async {
    final account = _configuredAccount();
    final uri = Uri.tryParse(recoveryUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const AppwriteAuthServiceException(configurationMessage);
    }
    try {
      await account.createRecovery(email: email.trim(), url: recoveryUrl);
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  Future<void> resetPassword(
    String userId,
    String secret,
    String password,
  ) async {
    final account = _configuredAccount();
    if (userId.trim().isEmpty ||
        secret.trim().isEmpty ||
        password.length < 12) {
      throw const AppwriteAuthServiceException(requestMessage);
    }
    try {
      await account.updateRecovery(
        userId: userId,
        secret: secret,
        password: password,
      );
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  Future<AuthUser> socialSignIn(AuthProvider provider) async {
    final account = _configuredAccount();
    if (!availableProviders(defaultTargetPlatform).contains(provider)) {
      throw const AppwriteAuthServiceException(socialMessage);
    }
    try {
      await account.createOAuth2Session(provider: _provider(provider));
      return _toAuthUser(await account.get());
    } on Object {
      throw const AppwriteAuthServiceException(socialMessage);
    }
  }

  Future<AuthUser?> restoreSession() async {
    final account = _configuredAccount();
    try {
      return _toAuthUser(await account.get());
    } on AppwriteException catch (error) {
      if (error.code == 401) return null;
      throw const AppwriteAuthServiceException(requestMessage);
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  appwrite_enums.OAuthProvider _provider(AuthProvider provider) =>
      switch (provider) {
        AuthProvider.google => appwrite_enums.OAuthProvider.google,
        AuthProvider.facebook => appwrite_enums.OAuthProvider.facebook,
        AuthProvider.apple => appwrite_enums.OAuthProvider.apple,
      };

  AuthUser _toAuthUser(appwrite_models.User user) =>
      AuthUser(id: user.$id, email: user.email, name: user.name);
}
