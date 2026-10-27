import 'package:flutter/foundation.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/services/appwrite_auth_service.dart';
import '../domain/account_models.dart';
import 'account_repository.dart';
import 'settings_repository.dart';

/// Account creation and deletion against Appwrite Account + Progress.
///
/// `createProfile` signs up with Appwrite (P3-AUTH-001), then runs the
/// idempotent `initializeProfile` and sets the nickname via `updateMe`.
/// Screen copy comes from [content].
class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository({
    required this.api,
    required this.auth,
    required this.content,
    this.onDeletionAccepted,
    this.createAccount,
  });

  final ApiEndpoints api;
  final AuthSessionRepository? auth;
  final AccountContent content;

  /// Updates the identity-scoped receipt state after server acceptance only.
  final void Function()? onDeletionAccepted;
  final Future<void> Function(String email, String password, String name)?
  createAccount;

  @override
  SignupContent get signupContent => content.signupContent;

  @override
  DeleteAccountContent get deleteContent => content.deleteContent;

  @override
  Future<String?> createProfile(NewProfile profile) async {
    try {
      if (createAccount != null) {
        await createAccount!(
          profile.email,
          profile.password,
          profile.displayName,
        );
        // The root session preparation uses a fresh, identity-scoped client.
        return null;
      }
      final session = auth;
      if (session == null) return 'This feature isn’t connected yet.';
      await session.signUp(
        profile.email,
        profile.password,
        profile.displayName,
      );
      final created = await api.initializeProfile();
      final nickname = profile.displayName.length > 40
          ? profile.displayName.substring(0, 40)
          : profile.displayName;
      if (nickname.isNotEmpty) {
        await api.updateMe(
          wire.ProfilePatch(
            nickname: nickname,
            expectedRevision: created.revision,
          ),
        );
      }
      return null;
    } on AuthFailure catch (error) {
      return error.message;
    } on ApiException catch (error) {
      return error.userMessage;
    }
  }

  @override
  Future<String?> requestDeletion() async {
    try {
      await api.deleteAccount(const wire.DeletionRequest());
      onDeletionAccepted?.call();
      return null;
    } on ApiException catch (error) {
      return error.userMessage;
    }
  }
}

/// Identity operations Settings > Social accounts needs from Appwrite.
///
/// Behind an interface so the switches can be exercised without an SDK
/// session. Implementations must never persist provider tokens.
abstract interface class SocialIdentityGateway {
  /// OAuth providers this build enables.
  Set<String> get configuredProviders;

  /// Providers currently linked to the signed-in account.
  Future<Set<String>> linkedProviders();

  /// Starts the OAuth2 link flow for [providerId] (user-initiated only).
  Future<void> link(String providerId);

  /// Removes the account identity linked to [providerId].
  Future<void> unlink(String providerId);
}

/// Appwrite Account identities of the current session.
class AppwriteSocialIdentityGateway implements SocialIdentityGateway {
  AppwriteSocialIdentityGateway(this.service);

  final AppwriteAuthService service;

  static const _providers = {
    'apple': AuthProvider.apple,
    'facebook': AuthProvider.facebook,
    'google': AuthProvider.google,
  };

  @override
  Set<String> get configuredProviders => {
    for (final provider in service.availableProviders(defaultTargetPlatform))
      _id(provider),
  };

  @override
  Future<Set<String>> linkedProviders() => _guard(() async {
    final identities = await service.listIdentities();
    return {for (final identity in identities) identity.provider};
  });

  @override
  Future<void> link(String providerId) => _guard(() async {
    final provider = _providers[providerId];
    if (provider == null) throw _unsupported;
    await service.linkProvider(provider);
  });

  @override
  Future<void> unlink(String providerId) => _guard(() async {
    if (!_providers.containsKey(providerId)) throw _unsupported;
    final identities = await service.listIdentities();
    for (final identity in identities) {
      if (identity.provider == providerId) {
        await service.unlinkIdentity(identity.id);
      }
    }
  });

  static const _unsupported = AppwriteAuthServiceException(
    AppwriteAuthService.socialMessage,
  );

  static String _id(AuthProvider provider) => switch (provider) {
    AuthProvider.google => 'google',
    AuthProvider.facebook => 'facebook',
    AuthProvider.apple => 'apple',
  };

  /// Maps SDK failures to a neutral screen message; raw details stay out.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AppwriteAuthServiceException catch (error) {
      throw ApiException(
        code: error.message == AppwriteAuthService.configurationMessage
            ? 'NOT_CONFIGURED'
            : 'UNAVAILABLE',
        message: error.message,
      );
    }
  }
}

/// Settings writes (classroom join, feedback, social accounts) against
/// Progress and Appwrite Account; static copy stays on [content].
class ApiSettingsRepository implements SettingsRepository {
  ApiSettingsRepository({
    required this.api,
    required this.content,
    this.identities,
  });

  final ApiEndpoints api;
  final SettingsContent content;

  /// Linked-identity surface; null when this build has none (mock auth or no
  /// signed-in session), so no toggle can manufacture an identity.
  final SocialIdentityGateway? identities;

  Set<String> _connected = const {};

  @override
  SchoolsContent get schools => content.schools;

  @override
  List<SocialAccount> get socialAccounts {
    final gateway = identities;
    if (gateway == null) return content.socialAccounts;
    final configured = gateway.configuredProviders;
    if (configured.isEmpty) return content.socialAccounts;
    final visible = [
      for (final account in content.socialAccounts)
        if (configured.contains(account.id)) account,
    ];
    return visible.isEmpty ? content.socialAccounts : visible;
  }

  @override
  Set<String> get connectedSocial => _connected;

  @override
  Future<Set<String>> loadSocialConnections() async {
    final gateway = identities;
    if (gateway == null) return const {};
    final linked = Set<String>.unmodifiable(await gateway.linkedProviders());
    _connected = linked;
    return linked;
  }

  @override
  FeedbackContent get feedback => content.feedback;

  @override
  Future<ClassroomJoin> joinClassroom(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9-]{4,16}$').hasMatch(normalized)) {
      return const ClassroomJoin.failed(
        'Classroom codes have 6 letters or numbers.',
      );
    }
    try {
      final membership = await api.joinClassroom(
        wire.ClassroomJoinRequest(joinCode: normalized),
      );
      return ClassroomJoin.joined(membership.name);
    } on ApiException catch (error) {
      if (error.isNotFound) {
        return const ClassroomJoin.failed(
          'We couldn’t find that classroom. Check the code with your teacher.',
        );
      }
      return ClassroomJoin.failed(error.userMessage);
    }
  }

  @override
  Future<void> setSocialConnected(String id, {required bool connected}) async {
    final gateway = identities;
    if (gateway == null) {
      throw const ApiException(
        code: 'NOT_CONFIGURED',
        message: 'Identity linking unavailable.',
      );
    }
    if (connected) {
      await gateway.link(id);
      _connected = {..._connected, id};
    } else {
      await gateway.unlink(id);
      _connected = {..._connected}..remove(id);
    }
    try {
      await loadSocialConnections();
    } on Object {
      // The link change already succeeded; keep the switch state and let the
      // next visit re-read the authoritative identities.
    }
  }

  @override
  Future<void> sendFeedback(String topic, String message) async {
    final slug = topic
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    await api.sendFeedback(
      wire.FeedbackRequest(
        topic: slug.isEmpty ? 'general' : slug,
        message: message,
        appVersion: '0.1.0',
        platform: switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'IOS',
          _ when kIsWeb => 'WEB',
          _ => 'ANDROID',
        },
      ),
    );
  }
}
