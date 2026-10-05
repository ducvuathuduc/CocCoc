import '../domain/auth_state.dart';
import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
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
  String? _recoveryEmail;

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
    return demoUser;
  }

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser?> rememberedAccount() async => _remembered;

  @override
  Future<void> forgetAccount() async {
    _remembered = null;
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}
