import '../../progress/data/progress_snapshot.dart';
import '../domain/app_shell_models.dart';
import 'app_shell_repository.dart';

/// Shell stats with server-authoritative streak, gems and energy from the
/// shared Progress snapshot (`/v1/me/rewards`, `/v1/me/energy`). Until the
/// first response lands the local ledger values are shown unchanged.
class ApiAppShellRepository extends MockAppShellRepository {
  const ApiAppShellRepository(this.source);

  final ProgressSnapshotSource source;

  @override
  List<AppStat> stats(AppShellSnapshot snapshot) {
    final server = source.value;
    if (server == null) return super.stats(snapshot);
    final rewards = server.rewards;
    final energy = server.energy;
    return super.stats(
      AppShellSnapshot(
        score: snapshot.score,
        streak: rewards.currentStreak,
        gems: rewards.gems,
        energy: energy.balance,
        unlimited: energy.mode == 'UNLIMITED',
        streakActive: rewards.currentStreak > 0,
      ),
    );
  }
}
