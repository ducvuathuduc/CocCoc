enum AuthStage {
  choice,
  details,
  forgot,
  reset,
  busy,
  signedIn,

  /// Passwordless sign-in: enter the email that receives a 6-digit code.
  emailCode,

  /// Passwordless sign-in: enter the 6-digit code from the email.
  emailCodeVerify,
}

enum AuthProvider { google }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.guest = false,
  });

  final String id;
  final String email;
  final String name;

  /// Anonymous session (P3-AUTH-001 guest); no email, upgradeable later.
  final bool guest;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.id == id &&
          other.email == email &&
          other.name == name &&
          other.guest == guest;

  @override
  int get hashCode => Object.hash(id, email, name, guest);
}

class AuthState {
  const AuthState({
    this.stage = AuthStage.choice,
    this.email = '',
    this.password = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.hidden = true,
    this.confirmHidden = true,
    this.busy = false,
    this.error,
    this.user,
    this.remembered,
    this.recoverySent = false,
    this.resetComplete = false,
    this.recoveryUserId = '',
    this.recoverySecret = '',
    this.code = '',
    this.codeUserId = '',
    this.codeResent = false,
  });

  final AuthStage stage;
  final String email;
  final String password;
  final String newPassword;
  final String confirmPassword;
  final bool hidden;
  final bool confirmHidden;
  final bool busy;
  final String? error;
  final AuthUser? user;
  final AuthUser? remembered;
  final bool recoverySent;
  final bool resetComplete;
  final String recoveryUserId;
  final String recoverySecret;

  /// Digits typed on the email-code screen.
  final String code;

  /// Appwrite user id returned with the emailed token (createEmailToken).
  final String codeUserId;

  /// A fresh code was sent from the code screen.
  final bool codeResent;

  bool get canSignIn => email.trim().isNotEmpty && password.isNotEmpty;

  bool get canRecover {
    final value = email.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  bool get canVerifyCode =>
      codeUserId.isNotEmpty && RegExp(r'^\d{6}$').hasMatch(code);

  bool get canReset =>
      recoveryUserId.isNotEmpty &&
      recoverySecret.isNotEmpty &&
      newPassword.length >= 12 &&
      newPassword == confirmPassword;

  AuthState copyWith({
    AuthStage? stage,
    String? email,
    String? password,
    String? newPassword,
    String? confirmPassword,
    bool? hidden,
    bool? confirmHidden,
    bool? busy,
    String? error,
    bool clearError = false,
    AuthUser? user,
    bool clearUser = false,
    AuthUser? remembered,
    bool clearRemembered = false,
    bool? recoverySent,
    bool? resetComplete,
    String? recoveryUserId,
    String? recoverySecret,
    String? code,
    String? codeUserId,
    bool? codeResent,
  }) => AuthState(
    stage: stage ?? this.stage,
    email: email ?? this.email,
    password: password ?? this.password,
    newPassword: newPassword ?? this.newPassword,
    confirmPassword: confirmPassword ?? this.confirmPassword,
    hidden: hidden ?? this.hidden,
    confirmHidden: confirmHidden ?? this.confirmHidden,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
    user: clearUser ? null : user ?? this.user,
    remembered: clearRemembered ? null : remembered ?? this.remembered,
    recoverySent: recoverySent ?? this.recoverySent,
    resetComplete: resetComplete ?? this.resetComplete,
    recoveryUserId: recoveryUserId ?? this.recoveryUserId,
    recoverySecret: recoverySecret ?? this.recoverySecret,
    code: code ?? this.code,
    codeUserId: codeUserId ?? this.codeUserId,
    codeResent: codeResent ?? this.codeResent,
  );
}
