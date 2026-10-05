import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/application/preview_controller.dart';

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
  });
  final int step;
  final String age, first, last, email, password;
  final String? error;
  final bool busy, hidden;
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

  void back() {
    if (state.busy || state.step == 0) return;
    state = state.copyWith(step: state.step - 1);
  }

  void toggleHidden() => state = state.copyWith(hidden: !state.hidden);
  Future<void> next() async {
    if (state.busy || state.step == 4) return;
    String? error;
    if (state.step == 0 &&
        (int.tryParse(state.age) == null ||
            int.parse(state.age) < 1 ||
            int.parse(state.age) > 120)) {
      error = 'Enter an age between 1 and 120.';
    }
    if (state.step == 1 &&
        (state.first.trim().isEmpty ||
            state.first.length + state.last.length > 59)) {
      error = 'Enter your name (up to 60 characters).';
    }
    if (state.step == 2 &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(state.email.trim())) {
      error = 'Enter a valid email address.';
    }
    if (state.step == 3 && state.password.length < 12) {
      error = 'Use at least 12 characters.';
    }
    if (error != null) {
      state = state.copyWith(error: error);
      return;
    }
    if (state.step < 3) {
      state = state.copyWith(step: state.step + 1);
      return;
    }
    state = state.copyWith(busy: true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (_disposed) return;
    error = ref
        .read(previewControllerProvider.notifier)
        .saveProfile(
          '${state.first.trim()} ${state.last.trim()}'.trim(),
          state.email,
          register: true,
        );
    state = state.copyWith(
      busy: false,
      error: error,
      step: error == null ? 4 : 3,
      password: error == null ? '' : null,
    );
  }
}
