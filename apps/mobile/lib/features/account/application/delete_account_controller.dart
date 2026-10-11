import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_repository.dart';

class DeleteAccountState {
  const DeleteAccountState({
    this.secondsLeft = 0,
    this.busy = false,
    this.error,
  });

  /// Countdown before DELETE ACCOUNT unlocks (Duolingo "DELETE ACCOUNT (5)").
  final int secondsLeft;
  final bool busy;
  final String? error;
  bool get canDelete => secondsLeft == 0 && !busy;
}

final deleteAccountControllerProvider =
    NotifierProvider.autoDispose<DeleteAccountController, DeleteAccountState>(
      DeleteAccountController.new,
    );

class DeleteAccountController extends Notifier<DeleteAccountState> {
  Timer? _timer;
  @override
  DeleteAccountState build() {
    ref.onDispose(() => _timer?.cancel());
    final seconds = ref.read(accountRepositoryProvider).deleteContent;
    _start(seconds.countdownSeconds);
    return DeleteAccountState(secondsLeft: seconds.countdownSeconds);
  }

  void _start(int seconds) {
    _timer?.cancel();
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.secondsLeft - 1;
      state = DeleteAccountState(secondsLeft: left < 0 ? 0 : left);
      if (left <= 0) t.cancel();
    });
  }

  /// Returns true when the request was accepted.
  Future<bool> confirm() async {
    if (!state.canDelete) return false;
    state = const DeleteAccountState(busy: true);
    final error = await ref.read(accountRepositoryProvider).requestDeletion();
    if (!ref.mounted) return error == null;
    state = DeleteAccountState(error: error);
    return error == null;
  }
}
