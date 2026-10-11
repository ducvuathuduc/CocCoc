import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_repository.dart';
import '../domain/account_models.dart';

/// Steps: 0 age, 1 name, 2 email, 3 password, 4 welcome.
class RegistrationState {
  const RegistrationState({
    this.step = 0,
    this.age = '',
    this.first = '',
    this.last = '',
    this.email = '',
    this.password = '',
    this.error,
    this.busy = false,
    this.hidden = true,
    this.errorTick = 0,
    this.forward = true,
  });
  final int step;
  final String age, first, last, email, password;
  final String? error;
  final bool busy, hidden;

  /// Incremented on each validation failure; drives the error shake.
  final int errorTick;

  /// Direction of the last step change (page slide).
  final bool forward;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static const _domainFixes = {
    'gmail.c': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmial.com': 'gmail.com',
    'gmai.com': 'gmail.com',
    'yahoo.c': 'yahoo.com',
    'hotmail.c': 'hotmail.com',
    'outlook.c': 'outlook.com',
  };

  bool get ageValid {
    final v = int.tryParse(age.trim());
    return v != null && v >= 1 && v <= 120;
  }

  bool get nameValid =>
      first.trim().isNotEmpty && first.length + last.length <= 59;
  bool get emailValid => _emailPattern.hasMatch(email.trim());
  bool get passwordValid => password.length >= 12;
  String get fullName => '${first.trim()} ${last.trim()}'.trim();

  /// Whether the primary button is enabled for the current step
  /// (Duolingo keeps NEXT grey until input exists).
  bool get canSubmit =>
      !busy &&
      switch (step) {
        0 => age.trim().isNotEmpty,
        1 => first.trim().isNotEmpty,
        2 => email.trim().isNotEmpty,
        3 => password.isNotEmpty,
        _ => true,
      };

  /// Inline email error shown under the field after a failed NEXT.
  bool get emailInvalidShown =>
      step == 2 && error != null && email.isNotEmpty && !emailValid;

  /// Typo-corrected email offered under "Suggested email".
  String? get emailSuggestion {
    final at = email.trim().lastIndexOf('@');
    if (at < 1) return null;
    final domain = email.trim().substring(at + 1).toLowerCase();
    final fix = _domainFixes[domain];
    return fix == null ? null : '${email.trim().substring(0, at)}@$fix';
  }

  RegistrationState copyWith({
    int? step,
    String? age,
    String? first,
    String? last,
    String? email,
    String? password,
    String? error,
    bool? busy,
    bool? hidden,
    int? errorTick,
    bool? forward,
  }) => RegistrationState(
    step: step ?? this.step,
    age: age ?? this.age,
    first: first ?? this.first,
    last: last ?? this.last,
    email: email ?? this.email,
    password: password ?? this.password,
    error: error,
    busy: busy ?? this.busy,
    hidden: hidden ?? this.hidden,
    errorTick: errorTick ?? this.errorTick,
    forward: forward ?? this.forward,
  );
}

final registrationControllerProvider =
    NotifierProvider<RegistrationController, RegistrationState>(
      RegistrationController.new,
    );

class RegistrationController extends Notifier<RegistrationState> {
  bool _disposed = false;
  @override
  RegistrationState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const RegistrationState();
  }

  void edit({
    String? age,
    String? first,
    String? last,
    String? email,
    String? password,
  }) {
    if (state.busy) return;
    state = state.copyWith(
      age: age,
      first: first,
      last: last,
      email: email,
      password: password,
    );
  }

  void acceptSuggestion() {
    final s = state.emailSuggestion;
    if (s != null) state = state.copyWith(email: s);
  }

  void back() {
    if (state.busy || state.step == 0) return;
    state = state.copyWith(step: state.step - 1, forward: false);
  }

  void toggleHidden() =>
      state = state.copyWith(hidden: !state.hidden, error: state.error);

  void _fail(String error) =>
      state = state.copyWith(error: error, errorTick: state.errorTick + 1);

  Future<void> next() async {
    if (state.busy || state.step == 4) return;
    final error = switch (state.step) {
      0 when !state.ageValid => 'Enter an age between 1 and 120.',
      1 when !state.nameValid => 'Enter your name (up to 60 characters).',
      2 when !state.emailValid => 'Invalid email address',
      3 when !state.passwordValid => 'Use at least 12 characters.',
      _ => null,
    };
    if (error != null) return _fail(error);
    if (state.step < 3) {
      state = state.copyWith(step: state.step + 1, forward: true);
      return;
    }
    state = state.copyWith(busy: true);
    final result = await ref
        .read(accountRepositoryProvider)
        .createProfile(
          NewProfile(
            age: int.parse(state.age.trim()),
            firstName: state.first.trim(),
            lastName: state.last.trim(),
            email: state.email.trim(),
            password: state.password,
          ),
        );
    if (_disposed) return;
    state = state.copyWith(
      busy: false,
      error: result,
      step: result == null ? 4 : 3,
      forward: true,
      password: result == null ? '' : null,
      errorTick: result == null ? null : state.errorTick + 1,
    );
  }
}
