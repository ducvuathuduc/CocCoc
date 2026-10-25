import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/services/appwrite_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedClient implements Client {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Account extends Account {
  _Account() : super(_UnusedClient());
  String userId = 'a';
  bool verified = false, fail = false;
  int sends = 0, confirmations = 0;
  String? sentUrl;

  models.Token token() => models.Token(
    $id: 'fixture',
    $createdAt: '',
    userId: 'a',
    secret: '',
    expire: '',
    phrase: '',
  );

  @override
  Future<models.User> get() async {
    if (fail) throw AppwriteException('private response', 401);
    return models.User(
      $id: userId,
      $createdAt: '',
      $updatedAt: '',
      name: 'A',
      registration: '',
      status: true,
      labels: [],
      passwordUpdate: '',
      email: '$userId@example.test',
      phone: '',
      emailVerification: verified,
      phoneVerification: false,
      mfa: false,
      prefs: models.Preferences(data: {}),
      targets: [],
      accessedAt: '',
    );
  }

  @override
  Future<models.Token> createEmailVerification({required String url}) async {
    sends++;
    sentUrl = url;
    if (fail) throw AppwriteException('private response', 429);
    return token();
  }

  @override
  Future<models.Token> updateEmailVerification({
    required String userId,
    required String secret,
  }) async {
    confirmations++;
    if (fail) throw AppwriteException('private response', 401);
    verified = true;
    return token();
  }
}

void main() {
  test('SDK returns actual account email verification status', () async {
    final account = _Account();
    final repository = AppwriteAuthRepository(
      AppwriteAuthService.withAccount(account),
    );
    expect((await repository.readEmailVerification()).verified, isFalse);
    account.verified = true;
    final status = await repository.readEmailVerification();
    expect(status.userId, 'a');
    expect(status.email, 'a@example.test');
    expect(status.verified, isTrue);
  });

  for (final url in [
    '',
    'http://example.test/auth/verify',
    'https://user@example.test/auth/verify',
    'https://example.test/auth/verify?q=x',
    'https://example.test/auth/verify#x',
  ]) {
    test(
      'invalid verification callback URL refuses provider write: $url',
      () async {
        final account = _Account();
        final service = AppwriteAuthService.withAccount(
          account,
          verificationUrl: url,
        );
        await expectLater(
          service.sendEmailVerification(),
          throwsA(isA<AppwriteAuthServiceException>()),
        );
        expect(account.sends, 0);
      },
    );
  }

  test(
    'SDK sends configured callback and confirms with server readback',
    () async {
      final account = _Account();
      final service = AppwriteAuthService.withAccount(
        account,
        verificationUrl: 'https://example.test/auth/verify',
      );
      final repository = AppwriteAuthRepository(service);
      await repository.sendEmailVerification();
      expect(account.sends, 1);
      expect(account.sentUrl, 'https://example.test/auth/verify');
      final status = await repository.completeEmailVerification(
        'a',
        'fixture-code',
      );
      expect(account.confirmations, 1);
      expect(status.verified, isTrue);
    },
  );

  test(
    'SDK blocks a different active account before consuming callback',
    () async {
      final account = _Account()..userId = 'b';
      final service = AppwriteAuthService.withAccount(account);
      await expectLater(
        service.completeEmailVerification('a', 'fixture-code'),
        throwsA(isA<AppwriteAuthServiceException>()),
      );
      expect(account.confirmations, 0);
    },
  );

  test('SDK/provider error is redacted by repository', () async {
    final account = _Account()..fail = true;
    final repository = AppwriteAuthRepository(
      AppwriteAuthService.withAccount(
        account,
        verificationUrl: 'https://example.test/auth/verify',
      ),
    );
    await expectLater(
      repository.sendEmailVerification(),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          AppwriteAuthService.requestMessage,
        ),
      ),
    );
  });
}
