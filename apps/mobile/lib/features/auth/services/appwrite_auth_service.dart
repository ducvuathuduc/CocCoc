import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:appwrite/models.dart' as appwrite_models;
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../domain/auth_state.dart';
import '../domain/email_verification.dart';

class AppwriteAuthServiceException implements Exception {
  const AppwriteAuthServiceException(this.message);

  final String message;
}

/// One sign-in identity linked to the signed-in account.
///
/// Only the identity id and provider name leave the service; the SDK's
/// provider access/refresh tokens are never copied, stored or logged.
class LinkedIdentity {
  const LinkedIdentity({required this.id, required this.provider});

  final String id;
  final String provider;
}

class AppwriteAuthService {
  AppwriteAuthService._({
    required this._account,
    required this.recoveryUrl,
    required this.verificationUrl,
    required this.googleEnabled,
  });

  factory AppwriteAuthService.fromEnvironment() =>
      AppwriteAuthService.fromConfig(AppConfig.current);

  /// Builds the Account client for [config]'s public endpoint and project.
  factory AppwriteAuthService.fromConfig(AppConfig config) {
    const recoveryUrl = String.fromEnvironment('APPWRITE_RECOVERY_URL');
    const verificationUrl = String.fromEnvironment('APPWRITE_VERIFICATION_URL');
    const googleEnabled = bool.fromEnvironment('APPWRITE_GOOGLE_ENABLED');

    final endpoint = config.appwriteEndpoint;
    final projectId = config.appwriteProjectId;
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
      verificationUrl: verificationUrl,
      googleEnabled: googleEnabled,
    );
  }

  /// Wraps an existing [Account] (tests, custom clients).
  @visibleForTesting
  factory AppwriteAuthService.withAccount(
    Account? account, {
    String recoveryUrl = '',
    String verificationUrl = '',
  }) => AppwriteAuthService._(
    account: account,
    recoveryUrl: recoveryUrl,
    verificationUrl: verificationUrl,
    googleEnabled: false,
  );

  static const configurationMessage =
      'Sign-in isn’t connected yet. Please try again later.';
  static const signInMessage =
      'We couldn’t sign you in. Check your email and password and try again.';
  static const requestMessage =
      'We couldn’t complete that request. Please try again.';
  static const signUpMessage =
      'We couldn’t create your account. Check your details and try again.';
  static const codeMessage =
      'That code didn’t work. Check the latest email and try again.';
  static const socialMessage =
      'That sign-in option isn’t available right now. Please try again.';

  final Account? _account;
  final String recoveryUrl;
  final String verificationUrl;
  final bool googleEnabled;

  bool get isConfigured => _account != null;

  Set<AuthProvider> availableProviders() {
    if (!isConfigured) return const {};
    return {if (googleEnabled) AuthProvider.google};
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

  /// Emails a 6-digit sign-in code (Appwrite Email OTP). New emails get an
  /// account on first successful code; returns the token's user id.
  Future<String> sendEmailCode(String email) async {
    final account = _configuredAccount();
    final value = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      throw const AppwriteAuthServiceException(requestMessage);
    }
    try {
      final token = await account.createEmailToken(
        userId: ID.unique(),
        email: value,
      );
      return token.userId;
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  /// Exchanges the emailed code for a session (account.createSession).
  Future<AuthUser> verifyEmailCode(String userId, String code) async {
    final account = _configuredAccount();
    final secret = code.trim();
    if (userId.trim().isEmpty || !RegExp(r'^\d{6}$').hasMatch(secret)) {
      throw const AppwriteAuthServiceException(codeMessage);
    }
    try {
      await account.createSession(userId: userId, secret: secret);
    } on Object {
      throw const AppwriteAuthServiceException(codeMessage);
    }
    try {
      return _toAuthUser(await account.get());
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
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

  Future<EmailVerificationStatus> readEmailVerification() async {
    final account = _configuredAccount();
    try {
      final user = await account.get();
      return EmailVerificationStatus(
        userId: user.$id,
        email: user.email,
        verified: user.emailVerification,
      );
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  Future<void> sendEmailVerification() async {
    final account = _configuredAccount();
    final uri = Uri.tryParse(verificationUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const AppwriteAuthServiceException(configurationMessage);
    }
    try {
      await account.createEmailVerification(url: verificationUrl);
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  Future<EmailVerificationStatus> completeEmailVerification(
    String userId,
    String secret,
  ) async {
    final account = _configuredAccount();
    if (userId.trim().isEmpty || secret.trim().isEmpty) {
      throw const AppwriteAuthServiceException(requestMessage);
    }
    final before = await readEmailVerification();
    if (before.userId != userId) {
      throw const AppwriteAuthServiceException(requestMessage);
    }
    try {
      await account.updateEmailVerification(userId: userId, secret: secret);
      return await readEmailVerification();
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
    if (!availableProviders().contains(provider)) {
      throw const AppwriteAuthServiceException(socialMessage);
    }
    try {
      await account.createOAuth2Session(provider: _provider(provider));
      return _toAuthUser(await account.get());
    } on Object {
      throw const AppwriteAuthServiceException(socialMessage);
    }
  }

  /// Lists the OAuth identities linked to the current account.
  Future<List<LinkedIdentity>> listIdentities() async {
    final account = _configuredAccount();
    try {
      final result = await account.listIdentities();
      return [
        for (final identity in result.identities)
          LinkedIdentity(id: identity.$id, provider: identity.provider),
      ];
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  /// Links [provider] to the signed-in account through Appwrite's OAuth2 flow.
  ///
  /// Only call from an explicit user action: the SDK opens the provider's
  /// consent page and returns after the redirect.
  Future<void> linkProvider(AuthProvider provider) async {
    final account = _configuredAccount();
    if (!availableProviders().contains(provider)) {
      throw const AppwriteAuthServiceException(socialMessage);
    }
    try {
      await account.createOAuth2Session(provider: _provider(provider));
    } on Object {
      throw const AppwriteAuthServiceException(socialMessage);
    }
  }

  /// Deletes a linked identity by id; Appwrite refuses to remove the last one.
  Future<void> unlinkIdentity(String identityId) async {
    final account = _configuredAccount();
    if (identityId.trim().isEmpty) {
      throw const AppwriteAuthServiceException(requestMessage);
    }
    try {
      await account.deleteIdentity(identityId: identityId);
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
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

  /// Creates an email/password account and signs it in (P3-AUTH-001).
  Future<AuthUser> signUp(String email, String password, String name) async {
    final account = _configuredAccount();
    try {
      await account.create(
        userId: ID.unique(),
        email: email.trim(),
        password: password,
        name: name.trim().isEmpty ? null : name.trim(),
      );
      await account.createEmailPasswordSession(
        email: email.trim(),
        password: password,
      );
      return _toAuthUser(await account.get());
    } on Object {
      throw const AppwriteAuthServiceException(signUpMessage);
    }
  }

  /// Starts an anonymous (guest) session; it can be upgraded later.
  Future<AuthUser> continueAsGuest() async {
    final account = _configuredAccount();
    try {
      await account.createAnonymousSession();
      return _toAuthUser(await account.get());
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  /// Deletes the current session. A missing session counts as signed out.
  Future<void> signOut() async {
    final account = _configuredAccount();
    try {
      await account.deleteSession(sessionId: 'current');
    } on AppwriteException catch (error) {
      if (error.code == 401) return;
      throw const AppwriteAuthServiceException(requestMessage);
    } on Object {
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  /// Mints a short-lived JWT for the API services; null when signed out.
  Future<String?> createJwt() async {
    final account = _account;
    if (account == null) return null;
    try {
      return (await account.createJWT()).jwt;
    } on AppwriteException catch (error) {
      if (error.code == 401) return null;
      throw const AppwriteAuthServiceException(requestMessage);
    }
  }

  appwrite_enums.OAuthProvider _provider(AuthProvider provider) =>
      switch (provider) {
        AuthProvider.google => appwrite_enums.OAuthProvider.google,
      };

  AuthUser _toAuthUser(appwrite_models.User user) => AuthUser(
    id: user.$id,
    email: user.email,
    name: user.name,
    guest: user.email.isEmpty,
  );
}
