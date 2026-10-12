import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/data/auth_repository.dart';
import 'package:cocenglish/features/auth/data/mock_auth_repository.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/auth/services/appwrite_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock session: sign-up, JWT only while signed in, logout', () async {
    final repo = MockAuthRepository(delay: Duration.zero);
    expect(await repo.accessToken(), isNull);
    final user = await repo.signUp('new@cocenglish.test', 'longpassword', 'An');
    expect(user.name, 'An');
    expect(await repo.accessToken(), isNotNull);
    await expectLater(
      repo.signUp('new@cocenglish.test', 'longpassword', 'An'),
      throwsA(isA<AuthFailure>()),
    );
    await repo.signOut();
    expect(await repo.accessToken(), isNull);
    expect(await repo.rememberedAccount(), user, reason: 'hint survives');
    final signedIn = await repo.signIn('new@cocenglish.test', 'longpassword');
    expect(signedIn.email, 'new@cocenglish.test');
  });

  test('guest session is flagged and never remembered', () async {
    final repo = MockAuthRepository(delay: Duration.zero);
    final guest = await repo.continueAsGuest();
    expect(guest.guest, isTrue);
    expect(await repo.rememberedAccount(), isNull);
  });

  test('controller guest + signOut keep remembered hint', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    await controller.continueAsGuest();
    expect(container.read(authControllerProvider).stage, AuthStage.signedIn);
    expect(container.read(authControllerProvider).user!.guest, isTrue);
    await controller.signOut();
    final state = container.read(authControllerProvider);
    expect(state.stage, AuthStage.choice);
    expect(state.user, isNull);
  });

  test('API data source selects the Appwrite repository', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(dataSource: DataSource.api),
        ),
        appwriteAuthServiceProvider.overrideWithValue(
          AppwriteAuthService.withAccount(null),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(authRepositoryProvider),
      isA<AppwriteAuthRepository>(),
    );
    expect(container.read(authSessionRepositoryProvider), isNotNull);
  });

  test('MOCK data source keeps the mock repository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(authRepositoryProvider), isA<MockAuthRepository>());
  });
}
