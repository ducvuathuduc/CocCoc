import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/league_repository.dart';
import 'preview_controller.dart';

/// Server membership for the current week, independent of the local gate flag.
final leagueJoinedProvider = Provider<bool>((ref) {
  watchProgressSnapshot(ref);
  return ref.watch(leagueRepositoryProvider).joined;
});

class LeagueJoinState {
  const LeagueJoinState({this.busy = false, this.failed = false});

  final bool busy;
  final bool failed;
}

final leagueJoinControllerProvider =
    NotifierProvider.autoDispose<LeagueJoinController, LeagueJoinState>(
      LeagueJoinController.new,
    );

/// The weekly gate command: opt in locally in mock mode, and join the server
/// cohort first in API mode. The local flag only drives the gate animation;
/// standings and tier always come from [leagueRepositoryProvider].
class LeagueJoinController extends Notifier<LeagueJoinState> {
  @override
  LeagueJoinState build() => const LeagueJoinState();

  Future<bool> join() async {
    if (state.busy) return false;
    if (!ref.read(appConfigProvider).isApi) {
      ref.read(previewControllerProvider.notifier).optIntoLeague();
      return true;
    }
    state = const LeagueJoinState(busy: true);
    try {
      final ranking = await ref.read(leagueRepositoryProvider).join();
      if (!ref.mounted) return false;
      if (ranking == null) {
        state = const LeagueJoinState(failed: true);
        return false;
      }
      ref.read(previewControllerProvider.notifier).optIntoLeague();
      state = const LeagueJoinState();
      return true;
    } catch (_) {
      if (ref.mounted) state = const LeagueJoinState(failed: true);
      return false;
    }
  }
}
