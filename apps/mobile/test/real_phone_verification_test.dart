import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/phone/data/phone_verification_repository.dart';
import 'package:cocenglish/features/phone/domain/phone_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real phone flow never accepts the preview OTP without a provider',
    () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(phoneVerificationRepositoryProvider);
      final number = PhoneNumber(repository.defaultCountry, '6502530000');
      await expectLater(
        repository.sendCode(number),
        throwsA(isA<PhoneVerificationFailure>()),
      );
      expect(await repository.verifyCode(number, '123456'), isFalse);
      expect(repository.countries().length, greaterThan(20));
    },
  );
}
