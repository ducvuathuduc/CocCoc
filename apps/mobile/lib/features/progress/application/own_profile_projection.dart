import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot_cache.dart';
import '../../../core/config/app_config.dart';
import '../../account/application/avatar_controller.dart';
import '../../account/application/profile_editor_controller.dart';
import '../../account/domain/avatar_configuration.dart';
import '../../auth/application/auth_controller.dart';
import '../../learning/application/learning_controller.dart';
import '../data/progress_snapshot.dart';
import '../domain/league_result.dart';
import 'extended_controller.dart';
import 'preview_controller.dart';
import 'profile_surface_controller.dart';

/// Only supported, same-account values enter the existing own-profile view.
/// Null counters represent unavailable data, never an inferred zero.
final class OwnProfileProjection {
  const OwnProfileProjection({
    required this.name,
    required this.identityLabel,
    required this.userId,
    required this.avatar,
    required this.league,
    this.following,
    this.followers,
    this.streak,
    this.score,
    this.xp,
    this.badge,
    this.showCreateProfile = false,
  });

  final String name, identityLabel, userId, league;
  final AvatarState avatar;
  final int? following, followers, streak, score, xp;
  final String? badge;
  final bool showCreateProfile;
}

final ownProfileProjectionProvider = Provider<OwnProfileProjection>((ref) {
  if (!ref.watch(appConfigProvider).isApi) {
    final preview = ref.watch(previewControllerProvider);
    final profile = ref.watch(profileEditorProvider);
    final progress = ref.watch(learningStateProvider);
    final surface = ref.watch(profileSurfaceProvider);
    final plan = ref.watch(extendedControllerProvider);
    return OwnProfileProjection(
      name: preview.name,
      identityLabel: '@${profile.username.toUpperCase()} · JOINED 2026',
      userId: 'me',
      avatar: ref.watch(avatarControllerProvider),
      following: preview.following.length,
      followers: surface.followers.length,
      streak: progress.streak,
      score: progress.score,
      league: preview.leagueOptIn ? 'Bronze' : 'No current',
      xp: progress.xp,
      badge: plan.unlimited ? (plan.isMax ? 'MAX' : 'SUPER') : null,
      showCreateProfile: !preview.registered,
    );
  }

  final user = ref.watch(authControllerProvider.select((state) => state.user));
  watchSnapshot(ref, progressSnapshotFeature);
  final source = ref.watch(progressSnapshotSourceProvider);
  final candidate = user == null ? null : source.value;
  final snapshot = candidate?.profile.userId == user?.id ? candidate : null;
  final nickname = snapshot?.profile.nickname.trim();
  final league = snapshot?.league;
  // Avatar configurations/handles/join dates/follow totals are not in Profile.
  // A local demo avatar or plan cannot stand in for an account-owned projection.
  return OwnProfileProjection(
    name: nickname != null && nickname.isNotEmpty
        ? nickname
        : (user?.name.trim().isNotEmpty ?? false)
        ? user!.name
        : '—',
    identityLabel: '—',
    userId: user?.id ?? '',
    avatar: AvatarState(
      saved: const {},
      draft: const {},
      catalog: AvatarCatalog.empty(),
    ),
    streak: snapshot?.rewards.currentStreak,
    xp: snapshot?.rewards.studyXp,
    league: snapshot == null
        ? '—'
        : league == null
        ? 'No current'
        : league.tier >= 0 && league.tier < LeagueTier.values.length
        ? LeagueTier.values[league.tier].label
        : '—',
  );
});
