import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client/api_providers.dart';
import '../../../core/cache/lesson_journal.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../learning/application/learning_controller.dart';
import '../../learning/data/learning_repository.dart';
import '../../learning/data/path_repository.dart';
import '../../progress/data/progress_snapshot.dart';
import '../data/account_sync_repository.dart';

final accountSyncRepositoryProvider = Provider<AccountSyncRepository>((ref) {
  final learning = ref.watch(learningRepositoryProvider);
  if (learning is! OfflineLearningSync) throw StateError('Sync unavailable');
  return ApiAccountSyncRepository(
    learning as OfflineLearningSync,
    ref.watch(apiEndpointsProvider),
  );
});

class AccountSyncState {
  const AccountSyncState({
    this.busy = false,
    this.confirmed = false,
    this.pending = 0,
    this.rejected = 0,
    this.error,
  });
  final bool busy, confirmed;
  final int pending, rejected;
  final String? error;
  bool get current =>
      confirmed && pending == 0 && rejected == 0 && error == null;
}

final accountSyncProvider =
    NotifierProvider<AccountSyncController, AccountSyncState>(
      AccountSyncController.new,
    );

class AccountSyncController extends Notifier<AccountSyncState> {
  int _generation = 0;
  String? _userId;
  LessonJournal? _journal;
  AccountSyncRepository? _repository;

  @override
  AccountSyncState build() {
    final generation = ++_generation;
    _journal = null;
    _repository = null;
    _userId = null;
    if (!ref.watch(appConfigProvider).isApi) return const AccountSyncState();
    final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (userId == null) {
      return const AccountSyncState(error: 'Please sign in again.');
    }
    _userId = userId;
    final journal = ref.watch(lessonJournalProvider);
    final repository = ref.watch(accountSyncRepositoryProvider);
    _journal = journal;
    _repository = repository;
    Future<void>(() => _run(generation, userId, journal, repository));
    return const AccountSyncState(busy: true);
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  Future<void> refresh() async {
    if (state.busy ||
        _userId == null ||
        _journal == null ||
        _repository == null) {
      return;
    }
    state = AccountSyncState(
      busy: true,
      pending: state.pending,
      rejected: state.rejected,
    );
    await _run(_generation, _userId!, _journal!, _repository!);
  }

  Future<void> _run(
    int generation,
    String userId,
    LessonJournal journal,
    AccountSyncRepository repository,
  ) async {
    if (!_current(generation)) return;
    var pending = 0, rejected = 0;
    try {
      pending = (await journal.pendingCompletions()).length;
      if (journal is RejectedLessonJournal) {
        rejected = (await journal.rejectedCompletions()).length;
      }
      if (!_current(generation)) return;
      await repository.synchronize(userId);
      if (!_current(generation)) return;
      ref.invalidate(progressSnapshotSourceProvider);
      ref.invalidate(pathRepositoryProvider);
      pending = (await journal.pendingCompletions()).length;
      if (journal is RejectedLessonJournal) {
        rejected = (await journal.rejectedCompletions()).length;
      }
      if (!_current(generation)) return;
      state = AccountSyncState(
        confirmed: true,
        pending: pending,
        rejected: rejected,
      );
    } on Object {
      if (_current(generation)) {
        state = AccountSyncState(
          pending: pending,
          rejected: rejected,
          error: 'We couldn’t sync your progress. Please try again.',
        );
      }
    }
  }
}
