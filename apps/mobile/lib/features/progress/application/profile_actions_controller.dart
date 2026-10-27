import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/social_repository.dart';
import 'preview_controller.dart';

const reportReasons = {'Nudity', 'Spam', 'Something else'};
const sampleProfileIds = {
  'Alex',
  'James Smith',
  'Maria',
  'Lucas',
  'Anna',
  'Samira',
  'Sam Lee',
  'Noah',
  'Emma',
};
String profilePreviewUrl(String userId) => Uri(
  scheme: 'https',
  host: 'cocenglish.test',
  pathSegments: ['profile', userId],
).toString();

final profileClipboardWriterProvider = Provider<Future<void> Function(String)>(
  (ref) =>
      (url) => Clipboard.setData(ClipboardData(text: url)),
);

class ProfileActionsState {
  const ProfileActionsState({
    this.blocked = const {},
    this.reports = const {},
    this.copying = false,
    this.copyError,
    this.copiedUser,
  });
  final Set<String> blocked;
  final Map<String, String> reports;
  final bool copying;
  final String? copyError, copiedUser;
}

final profileActionsProvider =
    NotifierProvider<ProfileActionsController, ProfileActionsState>(
      ProfileActionsController.new,
    );

// Mock moderation receipts only. No report or message leaves the app.
class ProfileActionsController extends Notifier<ProfileActionsState> {
  bool _alive = true;
  @override
  ProfileActionsState build() {
    ref.onDispose(() => _alive = false);
    _mirrorFollows();
    return const ProfileActionsState();
  }

  /// API mode mirrors the local Follow/Following toggle to `/v1/follows`.
  /// Mock mode keeps the archived preview-only behaviour.
  void _mirrorFollows() {
    ref.listen<Set<String>>(
      previewControllerProvider.select((state) => state.following),
      (previous, next) {
        if (previous == null || previous == next) return;
        if (!ref.read(appConfigProvider).isApi) return;
        final social = ref.read(socialRepositoryProvider);
        for (final userId in next.difference(previous)) {
          sendSocial(() => social.follow(userId));
        }
        for (final userId in previous.difference(next)) {
          sendSocial(() => social.unfollow(userId));
        }
      },
    );
  }

  /// API mode accepts any server user id; mock mode keeps sample ids only.
  bool _knownProfile(String userId) => ref.read(appConfigProvider).isApi
      ? userId.isNotEmpty && userId.length <= 36
      : sampleProfileIds.contains(userId);

  bool reportAndBlock(String userId, String reason) {
    if (!_knownProfile(userId) ||
        !reportReasons.contains(reason) ||
        state.reports.containsKey(userId)) {
      return false;
    }
    if (ref.read(previewControllerProvider).following.contains(userId)) {
      ref.read(previewControllerProvider.notifier).follow(userId);
    }
    final social = ref.read(socialRepositoryProvider);
    sendSocial(() => social.report(userId, reason: reason));
    sendSocial(() => social.block(userId));
    state = ProfileActionsState(
      blocked: {...state.blocked, userId},
      reports: {...state.reports, userId: reason},
      copying: state.copying,
      copyError: state.copyError,
      copiedUser: state.copiedUser,
    );
    return true;
  }

  void block(String userId) {
    if (!_knownProfile(userId) || state.blocked.contains(userId)) {
      return;
    }
    if (ref.read(previewControllerProvider).following.contains(userId)) {
      ref.read(previewControllerProvider.notifier).follow(userId);
    }
    final social = ref.read(socialRepositoryProvider);
    sendSocial(() => social.block(userId));
    state = ProfileActionsState(
      blocked: {...state.blocked, userId},
      reports: state.reports,
      copying: state.copying,
      copyError: state.copyError,
      copiedUser: state.copiedUser,
    );
  }

  void unblock(String userId) {
    if (!state.blocked.contains(userId)) return;
    final social = ref.read(socialRepositoryProvider);
    sendSocial(() => social.unblock(userId));
    state = ProfileActionsState(
      blocked: {...state.blocked}..remove(userId),
      reports: state.reports,
      copying: state.copying,
      copyError: state.copyError,
      copiedUser: state.copiedUser,
    );
  }

  void beginShare() {
    if (state.copying) return;
    state = ProfileActionsState(blocked: state.blocked, reports: state.reports);
  }

  Future<bool> copyLink(String userId) async {
    if (state.copying ||
        (!sampleProfileIds.contains(userId) && userId != 'me')) {
      return false;
    }
    state = ProfileActionsState(
      blocked: state.blocked,
      reports: state.reports,
      copying: true,
    );
    try {
      await ref.read(profileClipboardWriterProvider)(profilePreviewUrl(userId));
      if (!_alive) return false;
      state = ProfileActionsState(
        blocked: state.blocked,
        reports: state.reports,
        copiedUser: userId,
      );
      return true;
    } catch (_) {
      if (!_alive) return false;
      state = ProfileActionsState(
        blocked: state.blocked,
        reports: state.reports,
        copyError: 'Could not copy. Try again.',
      );
      return false;
    }
  }
}
