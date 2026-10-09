import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/mock_auth_repository.dart';

final passwordChangeWriterProvider =
    Provider<Future<void> Function(String, String)>((ref) {
      final repository = ref.watch(authRepositoryProvider);
      return (oldPassword, newPassword) async {
        if (repository is! MockAuthRepository) {
          throw const AuthFailure(
            'Password changes are unavailable. Try again later.',
          );
        }
        await repository.changePassword(oldPassword, newPassword);
      };
    });

class PasswordChangeState {
  const PasswordChangeState({
    this.values = const ['', '', ''],
    this.hidden = const [true, true, true],
    this.busy = false,
    this.error,
  });
  final List<String> values;
  final List<bool> hidden;
  final bool busy;
  final String? error;
  String? get validationMessage {
    if (values[1].isEmpty || values[2].isEmpty) return null;
    if (values[1].length < 12 || values[1].length > 128) {
      return 'Use 12 to 128 characters for the new password.';
    }
    if (values[1] != values[2]) return 'Passwords do not match.';
    return null;
  }

  bool get canSave =>
      !busy &&
      values[0].isNotEmpty &&
      values[1].length >= 12 &&
      values[1].length <= 128 &&
      values[1] == values[2];
}

final passwordChangeProvider =
    NotifierProvider.autoDispose<PasswordChangeController, PasswordChangeState>(
      PasswordChangeController.new,
    );

class PasswordChangeController extends Notifier<PasswordChangeState> {
  @override
  PasswordChangeState build() => const PasswordChangeState();
  void edit(int index, String value) {
    if (state.busy || index < 0 || index > 2) return;
    final values = [...state.values];
    values[index] = value;
    state = PasswordChangeState(
      values: List.unmodifiable(values),
      hidden: state.hidden,
    );
  }

  void toggleHidden(int index) {
    if (state.busy || index < 0 || index > 2) return;
    final hidden = [...state.hidden];
    hidden[index] = !hidden[index];
    state = PasswordChangeState(
      values: state.values,
      hidden: List.unmodifiable(hidden),
      error: state.error,
    );
  }

  Future<bool> save() async {
    if (state.busy) return false;
    if (!state.canSave) {
      state = PasswordChangeState(
        values: state.values,
        hidden: state.hidden,
        error: state.validationMessage ?? 'Enter your old password and use 12 to 128 characters for the new password.',
      );
      return false;
    }
    final values = state.values;
    state = PasswordChangeState(
      values: values,
      hidden: state.hidden,
      busy: true,
    );
    try {
      await ref.read(passwordChangeWriterProvider)(values[0], values[1]);
      if (!ref.mounted) return false;
      state = const PasswordChangeState();
      return true;
    } catch (error) {
      if (!ref.mounted) return false;
      state = PasswordChangeState(
        values: values,
        hidden: state.hidden,
        error: error is AuthFailure
            ? error.message
            : 'Could not save. Try again.',
      );
      return false;
    }
  }
}
