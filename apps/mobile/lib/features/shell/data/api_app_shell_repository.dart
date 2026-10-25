import '../../progress/data/progress_snapshot.dart';
import '../domain/app_shell_models.dart';
import 'app_shell_repository.dart';

/// Shell stats with server-authoritative streak, gems and energy from the
/// shared Progress snapshot (`/v1/me/rewards`, `/v1/me/energy`). Until the
/// first response lands, balance fields remain unavailable.
class ApiAppShellRepository extends MockAppShellRepository {
  const ApiAppShellRepository(this.source);

  final ProgressSnapshotSource source;

  @override
  List<AppStat> stats(AppShellSnapshot snapshot) {
    final server = source.value;
    if (server == null) {
      return const [
        AppStat(
          kind: AppStatKind.course,
          label: 'Courses',
          value: '',
          semanticLabel: 'Courses, score unavailable',
        ),
        AppStat(
          kind: AppStatKind.streak,
          label: 'Streak',
          value: '—',
          semanticLabel: 'Streak, unavailable',
          active: false,
        ),
        AppStat(
          kind: AppStatKind.gems,
          label: 'Shop',
          value: '—',
          semanticLabel: 'Shop, gems unavailable',
        ),
        AppStat(
          kind: AppStatKind.energy,
          label: 'Energy',
          value: '—',
          semanticLabel: 'Energy, unavailable',
        ),
      ];
    }
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
        hearts: snapshot.hearts,
      ),
    );
  }
}
