import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/phone_verification_repository.dart';
import '../domain/phone_models.dart';

class PhoneVerificationState {
  const PhoneVerificationState({
    required this.country,
    this.national = '',
    this.numberError,
    this.sending = false,
    this.serverError,
    this.pending,
    this.code = '',
    this.codeError,
    this.verifying = false,
    this.resendSeconds = 0,
    this.resent = false,
    this.verified,
  });
  final PhoneCountry country;
  final String national;
  final String? numberError;
  final bool sending;

  /// Generic failure shown as an alert ("An unknown error occurred...").
  final String? serverError;

  /// Number the code was sent to (code step active).
  final PhoneNumber? pending;
  final String code;
  final String? codeError;
  final bool verifying;
  final int resendSeconds;
  final bool resent;

  /// The number linked to the account after a successful check.
  final PhoneNumber? verified;

  bool get canSend => national.isNotEmpty && !sending;
  bool get canVerify => code.length == 6 && !verifying;
  bool get canResend => resendSeconds == 0 && !sending && pending != null;

  PhoneVerificationState copyWith({
    PhoneCountry? country,
    String? national,
    String? Function()? numberError,
    bool? sending,
    String? Function()? serverError,
    PhoneNumber? Function()? pending,
    String? code,
    String? Function()? codeError,
    bool? verifying,
    int? resendSeconds,
    bool? resent,
    PhoneNumber? Function()? verified,
  }) => PhoneVerificationState(
    country: country ?? this.country,
    national: national ?? this.national,
    numberError: numberError != null ? numberError() : this.numberError,
    sending: sending ?? this.sending,
    serverError: serverError != null ? serverError() : this.serverError,
    pending: pending != null ? pending() : this.pending,
    code: code ?? this.code,
    codeError: codeError != null ? codeError() : this.codeError,
    verifying: verifying ?? this.verifying,
    resendSeconds: resendSeconds ?? this.resendSeconds,
    resent: resent ?? this.resent,
    verified: verified != null ? verified() : this.verified,
  );
}

final phoneVerificationControllerProvider =
    NotifierProvider<PhoneVerificationController, PhoneVerificationState>(
      PhoneVerificationController.new,
    );

/// Drives Settings > Profile > Phone number: number entry, country picker,
/// SMS code entry with resend countdown, and the verified result.
class PhoneVerificationController extends Notifier<PhoneVerificationState> {
  Timer? _timer;
  PhoneVerificationRepository get _repo =>
      ref.read(phoneVerificationRepositoryProvider);

  @override
  PhoneVerificationState build() {
    ref.onDispose(() => _timer?.cancel());
    return PhoneVerificationState(
      country: ref.read(phoneVerificationRepositoryProvider).defaultCountry,
    );
  }

  List<PhoneCountry> countries([String query = '']) {
    final q = query.trim().toLowerCase().replaceFirst('+', '');
    final all = _repo.countries();
    final selected = state.country;
    final ordered = [selected, ...all.where((c) => c != selected)];
    if (q.isEmpty) return ordered;
    return ordered
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.dialCode.startsWith(q) ||
              c.iso.toLowerCase() == q,
        )
        .toList();
  }

  /// Fresh flow each time the Profile row is opened; keeps [verified].
  void begin() {
    _timer?.cancel();
    state = PhoneVerificationState(
      country: _repo.defaultCountry,
      verified: state.verified,
    );
  }

  void selectCountry(PhoneCountry country) =>
      state = state.copyWith(country: country, numberError: () => null);

  void editNumber(String value) => state = state.copyWith(
    national: value.replaceAll(RegExp(r'\D'), ''),
    numberError: () => null,
  );

  void dismissServerError() => state = state.copyWith(serverError: () => null);

  /// Validates and sends the SMS; true when the code step should open.
  Future<bool> sendCode() async {
    if (!state.canSend) return false;
    final error = _repo.validate(state.country, state.national);
    if (error != null) {
      state = state.copyWith(numberError: () => error);
      return false;
    }
    final number = PhoneNumber(state.country, state.national);
    state = state.copyWith(sending: true, serverError: () => null);
    try {
      await _repo.sendCode(number);
    } on PhoneVerificationFailure catch (e) {
      state = state.copyWith(sending: false, serverError: () => e.message);
      return false;
    }
    _timer?.cancel();
    state = state.copyWith(
      sending: false,
      pending: () => number,
      code: '',
      codeError: () => null,
      resendSeconds: 0,
      resent: false,
    );
    return true;
  }

  void editCode(String value) => state = state.copyWith(
    code: value.replaceAll(RegExp(r'\D'), ''),
    codeError: () => null,
  );

  Future<void> resend() async {
    final number = state.pending;
    if (number == null || !state.canResend) return;
    state = state.copyWith(sending: true);
    try {
      await _repo.sendCode(number);
    } on PhoneVerificationFailure catch (e) {
      state = state.copyWith(sending: false, serverError: () => e.message);
      return;
    }
    state = state.copyWith(
      sending: false,
      resent: true,
      code: '',
      codeError: () => null,
      resendSeconds: _repo.resendCooldownSeconds,
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.resendSeconds - 1;
      state = state.copyWith(resendSeconds: left < 0 ? 0 : left);
      if (left <= 0) t.cancel();
    });
  }

  /// True when the code matched and the number is now verified.
  Future<bool> verify() async {
    final number = state.pending;
    if (number == null || !state.canVerify) return false;
    state = state.copyWith(verifying: true);
    final ok = await _repo.verifyCode(number, state.code);
    if (!ok) {
      state = state.copyWith(
        verifying: false,
        codeError: () => 'That code is incorrect. Try again.',
      );
      return false;
    }
    _timer?.cancel();
    state = state.copyWith(
      verifying: false,
      verified: () => number,
      resendSeconds: 0,
    );
    return true;
  }
}
