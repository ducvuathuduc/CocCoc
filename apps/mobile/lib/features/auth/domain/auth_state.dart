enum AuthStage { choice, details, forgot, reset, busy, signedIn }

enum AuthProvider { google, facebook, apple }

class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.id == id &&
          other.email == email &&
          other.name == name;

  @override
  int get hashCode => Object.hash(id, email, name);
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

  bool get canSignIn => email.trim().isNotEmpty && password.isNotEmpty;

  bool get canRecover {
    final value = email.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

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
  );
}
