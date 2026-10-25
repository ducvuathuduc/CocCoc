import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/email_verification.dart';

final emailVerificationRepositoryProvider =
    Provider<EmailVerificationRepository?>((ref) {
      final repository = ref.watch(authRepositoryProvider);
      return repository is EmailVerificationRepository
          ? repository as EmailVerificationRepository
          : null;
    });

class EmailVerificationState {
  const EmailVerificationState({
    this.email = '',
    this.status,
    this.loading = false,
    this.busy = false,
    this.sent = false,
    this.error,
  });

  final String email;
  final EmailVerificationStatus? status;
  final bool loading, busy, sent;
  final String? error;
  bool get verified => status?.verified == true;
  bool get ready => status != null && !loading && !busy;
}

final emailVerificationProvider =
    NotifierProvider<EmailVerificationController, EmailVerificationState>(
      EmailVerificationController.new,
    );

class EmailVerificationController extends Notifier<EmailVerificationState> {
  static const unavailable =
      'We couldn’t complete that request. Please try again.';
  int _generation = 0;
  String? _userId;
  EmailVerificationRepository? _repository;

  @override
  EmailVerificationState build() {
    final generation = ++_generation;
    _repository = null;
    _userId = null;
    if (!ref.watch(appConfigProvider).isApi) {
      return const EmailVerificationState();
    }
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    _userId = user?.id;
    if (user == null || user.guest || user.email.isEmpty) {
      return const EmailVerificationState(error: 'Please sign in again.');
    }
    final repository = ref.watch(emailVerificationRepositoryProvider);
    _repository = repository;
    if (repository == null) {
      return EmailVerificationState(email: user.email, error: unavailable);
    }
    Future<void>(() => _read(repository, generation));
    return EmailVerificationState(email: user.email, loading: true);
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  EmailVerificationStatus _accepted(EmailVerificationStatus status) {
    if (status.userId != _userId) throw const AuthFailure(unavailable);
    return status;
  }

  Future<void> _read(
    EmailVerificationRepository repository,
    int generation,
  ) async {
    if (!_current(generation)) return;
    try {
      final status = await repository.readEmailVerification();
      if (!_current(generation)) return;
      _accepted(status);
      state = EmailVerificationState(
        email: status.email,
        status: status,
        sent: state.sent,
      );
    } on Object {
      if (_current(generation)) {
        state = EmailVerificationState(
          email: state.email,
          status: state.status,
          sent: state.sent,
          error: unavailable,
        );
      }
    }
  }

  Future<void> refresh() async {
    final repository = _repository;
    if (state.busy || state.loading || repository == null) return;
    state = EmailVerificationState(
      email: state.email,
      status: state.status,
      loading: true,
      sent: state.sent,
    );
    await _read(repository, _generation);
  }

  Future<void> resend() async {
    final repository = _repository;
    if (!state.ready || state.verified || repository == null) return;
    final generation = _generation;
    state = EmailVerificationState(
      email: state.email,
      status: state.status,
      busy: true,
    );
    try {
      await repository.sendEmailVerification();
      if (!_current(generation)) return;
      state = EmailVerificationState(
        email: state.email,
        status: state.status,
        sent: true,
      );
    } on Object {
      if (_current(generation)) {
        state = EmailVerificationState(
          email: state.email,
          status: state.status,
          error: unavailable,
        );
      }
    }
  }

  Future<void> completeLink(String userId, String secret) async {
    final repository = _repository;
    if (state.busy || repository == null) return;
    if (userId != _userId || secret.trim().isEmpty) {
      ++_generation;
      state = EmailVerificationState(email: state.email, error: unavailable);
      return;
    }
    // Supersede the initial refresh so it cannot overwrite the callback result.
    final generation = ++_generation;
    state = EmailVerificationState(email: state.email, busy: true);
    try {
      final status = await repository.completeEmailVerification(userId, secret);
      if (!_current(generation)) return;
      _accepted(status);
      state = EmailVerificationState(email: status.email, status: status);
    } on Object {
      if (_current(generation)) {
        state = EmailVerificationState(email: state.email, error: unavailable);
      }
    }
  }
}
