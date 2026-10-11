import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/phone_models.dart';

/// Phone verification backend (SMS code delivery + check).
abstract class PhoneVerificationRepository {
  /// Countries offered by the Country/Region picker, default first.
  List<PhoneCountry> countries();
  PhoneCountry get defaultCountry;

  /// Returns a user-facing error for a malformed number, or null.
  String? validate(PhoneCountry country, String national);

  /// Sends an SMS code. Throws [PhoneVerificationFailure] on a server error.
  Future<void> sendCode(PhoneNumber number);

  /// Returns true when [code] is the one sent to [number].
  Future<bool> verifyCode(PhoneNumber number, String code);

  /// Seconds before "Didn't receive the code?" can be used again.
  int get resendCooldownSeconds;
}

final phoneVerificationRepositoryProvider =
    Provider<PhoneVerificationRepository>(
      (ref) => MockPhoneVerificationRepository(),
    );

/// In-memory mock: every code is [mockCode]; [unreachable] numbers fail with
/// the generic server error Duolingo shows.
class MockPhoneVerificationRepository implements PhoneVerificationRepository {
  MockPhoneVerificationRepository({
    this.mockCode = '123456',
    this.unreachable = const {'+16502137379'},
    this.latency = Duration.zero,
  });
  final String mockCode;
  final Set<String> unreachable;
  final Duration latency;
  final List<String> sent = [];

  static const _us = PhoneCountry(
    iso: 'US',
    name: 'United States',
    dialCode: '1',
    minDigits: 10,
    maxDigits: 10,
  );

  static const _all = <PhoneCountry>[
    PhoneCountry(
      iso: 'AF',
      name: 'Afghanistan',
      dialCode: '93',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(iso: 'AX', name: 'Åland Islands', dialCode: '358'),
    PhoneCountry(
      iso: 'AL',
      name: 'Albania',
      dialCode: '355',
      minDigits: 8,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'DZ',
      name: 'Algeria',
      dialCode: '213',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'AS',
      name: 'American Samoa',
      dialCode: '1',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'AD',
      name: 'Andorra',
      dialCode: '376',
      minDigits: 6,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'AO',
      name: 'Angola',
      dialCode: '244',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'AI',
      name: 'Anguilla',
      dialCode: '1',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'AG',
      name: 'Antigua & Barbuda',
      dialCode: '1',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'AR',
      name: 'Argentina',
      dialCode: '54',
      minDigits: 10,
      maxDigits: 11,
    ),
    PhoneCountry(
      iso: 'AM',
      name: 'Armenia',
      dialCode: '374',
      minDigits: 8,
      maxDigits: 8,
    ),
    PhoneCountry(
      iso: 'AW',
      name: 'Aruba',
      dialCode: '297',
      minDigits: 7,
      maxDigits: 7,
    ),
    PhoneCountry(
      iso: 'AU',
      name: 'Australia',
      dialCode: '61',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'AT',
      name: 'Austria',
      dialCode: '43',
      minDigits: 10,
      maxDigits: 13,
    ),
    PhoneCountry(
      iso: 'BD',
      name: 'Bangladesh',
      dialCode: '880',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'BE',
      name: 'Belgium',
      dialCode: '32',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'BR',
      name: 'Brazil',
      dialCode: '55',
      minDigits: 10,
      maxDigits: 11,
    ),
    PhoneCountry(
      iso: 'KH',
      name: 'Cambodia',
      dialCode: '855',
      minDigits: 8,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'CA',
      name: 'Canada',
      dialCode: '1',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'CN',
      name: 'China',
      dialCode: '86',
      minDigits: 11,
      maxDigits: 11,
    ),
    PhoneCountry(
      iso: 'CO',
      name: 'Colombia',
      dialCode: '57',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'DK',
      name: 'Denmark',
      dialCode: '45',
      minDigits: 8,
      maxDigits: 8,
    ),
    PhoneCountry(
      iso: 'EG',
      name: 'Egypt',
      dialCode: '20',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'FR',
      name: 'France',
      dialCode: '33',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'DE',
      name: 'Germany',
      dialCode: '49',
      minDigits: 10,
      maxDigits: 11,
    ),
    PhoneCountry(
      iso: 'HK',
      name: 'Hong Kong',
      dialCode: '852',
      minDigits: 8,
      maxDigits: 8,
    ),
    PhoneCountry(
      iso: 'IN',
      name: 'India',
      dialCode: '91',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'ID',
      name: 'Indonesia',
      dialCode: '62',
      minDigits: 9,
      maxDigits: 12,
    ),
    PhoneCountry(
      iso: 'IT',
      name: 'Italy',
      dialCode: '39',
      minDigits: 9,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'JP',
      name: 'Japan',
      dialCode: '81',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'LA',
      name: 'Laos',
      dialCode: '856',
      minDigits: 8,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'MY',
      name: 'Malaysia',
      dialCode: '60',
      minDigits: 9,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'MX',
      name: 'Mexico',
      dialCode: '52',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'NL',
      name: 'Netherlands',
      dialCode: '31',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'PH',
      name: 'Philippines',
      dialCode: '63',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'SG',
      name: 'Singapore',
      dialCode: '65',
      minDigits: 8,
      maxDigits: 8,
    ),
    PhoneCountry(
      iso: 'KR',
      name: 'South Korea',
      dialCode: '82',
      minDigits: 9,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'ES',
      name: 'Spain',
      dialCode: '34',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'TW',
      name: 'Taiwan',
      dialCode: '886',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'TH',
      name: 'Thailand',
      dialCode: '66',
      minDigits: 9,
      maxDigits: 9,
    ),
    PhoneCountry(
      iso: 'GB',
      name: 'United Kingdom',
      dialCode: '44',
      minDigits: 10,
      maxDigits: 10,
    ),
    PhoneCountry(
      iso: 'VN',
      name: 'Vietnam',
      dialCode: '84',
      minDigits: 9,
      maxDigits: 10,
    ),
  ];

  @override
  PhoneCountry get defaultCountry => _us;

  @override
  List<PhoneCountry> countries() => const [_us, ..._all];

  @override
  int get resendCooldownSeconds => 30;

  @override
  String? validate(PhoneCountry country, String national) {
    final digits = national.replaceAll(RegExp(r'\D'), '');
    var ok =
        digits.isNotEmpty &&
        digits == national &&
        digits.length >= country.minDigits &&
        digits.length <= country.maxDigits;
    // North American Numbering Plan: area code and exchange start 2-9, and
    // the N11/N9X area codes (e.g. 653 is unassigned) are not dialable.
    if (ok && country.dialCode == '1') {
      ok =
          RegExp(r'^[2-9]\d{2}[2-9]\d{6}$').hasMatch(digits) &&
          !_unassignedNanp.contains(digits.substring(0, 3));
    }
    return ok ? null : 'Enter a valid phone number';
  }

  static const _unassignedNanp = {'653', '654', '655', '656', '911', '411'};

  @override
  Future<void> sendCode(PhoneNumber number) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (unreachable.contains(number.e164)) {
      throw const PhoneVerificationFailure(
        'An unknown error occurred. Please try again later.',
      );
    }
    sent.add(number.e164);
  }

  @override
  Future<bool> verifyCode(PhoneNumber number, String code) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return code == mockCode;
  }
}
