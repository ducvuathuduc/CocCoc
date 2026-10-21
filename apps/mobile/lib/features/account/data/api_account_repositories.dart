import 'package:flutter/foundation.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_exception.dart';
import '../../auth/data/auth_repository.dart';
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
    this.onRegister,
    this.onDelete,
    this.createAccount,
  });

  final ApiEndpoints api;
  final AuthSessionRepository? auth;
  final AccountRepository content;

  /// Mirrors the result into local UI state (preview controller).
  final String? Function(String name, String email)? onRegister;
  final void Function()? onDelete;
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
      await auth?.signUp(profile.email, profile.password, profile.displayName);
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
      return onRegister?.call(profile.displayName, profile.email);
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
      onDelete?.call();
      return null;
    } on ApiException catch (error) {
      return error.userMessage;
    }
  }
}

/// Settings writes (classroom join, feedback) against Progress; static copy
/// and social-account toggles stay on [content] (Appwrite identities are
/// managed by the auth surface).
class ApiSettingsRepository implements SettingsRepository {
  ApiSettingsRepository({required this.api, required this.content});

  final ApiEndpoints api;
  final SettingsRepository content;

  @override
  SchoolsContent get schools => content.schools;

  @override
  List<SocialAccount> get socialAccounts => content.socialAccounts;

  @override
  Set<String> get connectedSocial => content.connectedSocial;

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
  Future<void> setSocialConnected(String id, {required bool connected}) =>
      content.setSocialConnected(id, connected: connected);

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
