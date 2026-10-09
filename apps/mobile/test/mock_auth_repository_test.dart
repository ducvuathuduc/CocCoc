import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/data/mock_auth_repository.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo sign-in stays asynchronous and remembers metadata only', () async {
    final repository = MockAuthRepository();
    var completed = false;

    final signIn = repository
        .signIn('learner@example.com', 'duolingo-demo')
        .then((user) {
          completed = true;
          return user;
        });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(completed, false);

    final user = await signIn;
    expect(user.id, 'demo-user-001');
    expect(user.email, 'learner@example.com');
    expect(user.name, 'Sam Lee');
    expect(await repository.rememberedAccount(), user);
    expect(await repository.restoreSession(), isNull);
  });

  test(
    'wrong demo credentials fail generically and create no remembered account',
    () async {
      final repository = MockAuthRepository(delay: Duration.zero);

      await expectLater(
        repository.signIn('learner@example.com', 'wrong-password'),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'message',
            isNot(contains('wrong-password')),
          ),
        ),
      );
      expect(await repository.rememberedAccount(), isNull);
    },
  );

  test(
    'social mock returns the demo fixture without creating a session',
    () async {
      final repository = MockAuthRepository(delay: Duration.zero);

      final user = await repository.socialSignIn(AuthProvider.apple);

      expect(user, MockAuthRepository.demoUser);
      expect(await repository.rememberedAccount(), MockAuthRepository.demoUser);
      expect(await repository.restoreSession(), isNull);
      await repository.forgetAccount();
      expect(await repository.rememberedAccount(), isNull);
    },
  );

  test('recovery and reset enforce local fixture inputs', () async {
    final repository = MockAuthRepository(delay: Duration.zero);

    await expectLater(
      repository.sendRecovery('not-an-email'),
      throwsA(isA<AuthFailure>()),
    );
    await expectLater(
      repository.sendRecovery('learner@example.com'),
      completes,
    );
    await expectLater(
      repository.resetPassword(
        'wrong-user',
        'demo-recovery-token',
        'new-password-123',
      ),
      throwsA(isA<AuthFailure>()),
    );
    await expectLater(
      repository.resetPassword(
        'demo-user-001',
        'wrong-secret',
        'new-password-123',
      ),
      throwsA(isA<AuthFailure>()),
    );
    await expectLater(
      repository.resetPassword('demo-user-001', 'demo-recovery-token', 'short'),
      throwsA(isA<AuthFailure>()),
    );
    await expectLater(
      repository.resetPassword(
        'demo-user-001',
        'demo-recovery-token',
        'new-password-123',
      ),
      completes,
    );
    await expectLater(
      repository.signIn('learner@example.com', 'duolingo-demo'),
      throwsA(isA<AuthFailure>()),
    );
    expect(
      await repository.signIn('learner@example.com', 'new-password-123'),
      const AuthUser(
        id: 'demo-user-001',
        email: 'learner@example.com',
        name: 'Sam Lee',
      ),
    );
  });
}
