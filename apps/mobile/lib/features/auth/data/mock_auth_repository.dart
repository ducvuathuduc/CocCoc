import '../domain/auth_state.dart';
import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository, AuthSessionRepository {
  MockAuthRepository({this.delay = const Duration(milliseconds: 650)});

  static const demoUser = AuthUser(
    id: 'demo-user-001',
    email: 'demo@cocenglish.test',
    name: 'Sam Lee',
  );
  static const _initialPassword = 'duolingo-demo';
  static const _signInFailure =
      'We couldn’t sign you in. Check your email and password and try again.';
  static const _requestFailure =
      'We couldn’t complete that request. Please try again.';

  final Duration delay;
  final Map<String, String> _passwords = {};
  AuthUser? _remembered;
  AuthUser? _session;
  String? _recoveryEmail;
  int _guestSequence = 0;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    await Future<void>.delayed(delay);
    final normalizedEmail = email.trim();
    final expectedPassword = _passwords[normalizedEmail] ?? _initialPassword;
    if (!_validEmail(normalizedEmail) || password != expectedPassword) {
      throw const AuthFailure(_signInFailure);
    }
    final user = AuthUser(
      id: demoUser.id,
      email: normalizedEmail,
      name: demoUser.name,
    );
    _remembered = user;
    _session = user;
    return user;
  }

  @override
  Future<void> sendRecovery(String email) async {
    await Future<void>.delayed(delay);
    final normalizedEmail = email.trim();
    if (!_validEmail(normalizedEmail)) {
      throw const AuthFailure(_requestFailure);
    }
    _recoveryEmail = normalizedEmail;
  }

  @override
  Future<void> resetPassword(
    String userId,
    String secret,
    String password,
  ) async {
    await Future<void>.delayed(delay);
    final recoveryEmail = _recoveryEmail;
    if (userId != demoUser.id ||
        secret != 'demo-recovery-token' ||
        password.length < 12 ||
        recoveryEmail == null) {
      throw const AuthFailure(_requestFailure);
    }
    _passwords[recoveryEmail] = password;
    _recoveryEmail = null;
  }

  @override
  Future<AuthUser> socialSignIn(AuthProvider provider) async {
    await Future<void>.delayed(delay);
    _remembered = demoUser;
    _session = demoUser;
    return demoUser;
  }

  /// Mock sessions do not survive a restart (in-memory only).
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> signUp(String email, String password, String name) async {
    await Future<void>.delayed(delay);
    final normalizedEmail = email.trim();
    if (!_validEmail(normalizedEmail) ||
        password.length < 8 ||
        _passwords.containsKey(normalizedEmail)) {
      throw const AuthFailure(
        'We couldn’t create your account. Check your details and try again.',
      );
    }
    _passwords[normalizedEmail] = password;
    final user = AuthUser(
      id: 'demo-user-${normalizedEmail.hashCode.toUnsigned(32)}',
      email: normalizedEmail,
      name: name.trim().isEmpty ? demoUser.name : name.trim(),
    );
    _remembered = user;
    _session = user;
    return user;
  }

  @override
  Future<AuthUser> continueAsGuest() async {
    await Future<void>.delayed(delay);
    final guest = AuthUser(
      id: 'guest-${++_guestSequence}',
      email: '',
      name: '',
      guest: true,
    );
    _session = guest;
    return guest;
  }

  @override
  Future<void> signOut() async {
    _session = null;
  }

  /// Mock mode never calls the API; a token exists only while signed in.
  @override
  Future<String?> accessToken() async =>
      _session == null ? null : 'mock-jwt-${_session!.id}';

  /// Currently signed-in mock user, if any.
  AuthUser? get currentUser => _session;

  @override
  Future<AuthUser?> rememberedAccount() async => _remembered;

  @override
  Future<void> forgetAccount() async {
    _remembered = null;
  }

  // In-memory UI preview only; not part of the production auth contract.
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final email = _remembered?.email ?? demoUser.email;
    await Future<void>.delayed(delay);
    if (oldPassword != (_passwords[email] ?? _initialPassword)) {
      throw const AuthFailure('Old password is incorrect. Try again.');
    }
    if (newPassword.length < 12 || newPassword.length > 128) {
      throw const AuthFailure('Use 12 to 128 characters.');
    }
    _passwords[email] = newPassword;
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}
