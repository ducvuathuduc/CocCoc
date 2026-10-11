/// A selectable country/region with its international dialing code.
class PhoneCountry {
  const PhoneCountry({
    required this.iso,
    required this.name,
    required this.dialCode,
    this.minDigits = 6,
    this.maxDigits = 12,
  });
  final String iso;
  final String name;

  /// Digits only, without the leading "+".
  final String dialCode;

  /// Allowed national-number length (digits only).
  final int minDigits, maxDigits;

  String get prefix => '+$dialCode';

  @override
  bool operator ==(Object other) => other is PhoneCountry && other.iso == iso;
  @override
  int get hashCode => iso.hashCode;
}

/// A phone number the repository accepted and sent a code to.
class PhoneNumber {
  const PhoneNumber(this.country, this.national);
  final PhoneCountry country;
  final String national;
  String get e164 => '${country.prefix}$national';

  /// The masked form Duolingo shows on the Profile page, e.g. (XXX) XXX-7552.
  String get masked {
    final tail = national.length > 4
        ? national.substring(national.length - 4)
        : national;
    if (country.dialCode == '1' && national.length == 10) {
      return '(XXX) XXX-$tail';
    }
    return '${country.prefix} ${'X' * (national.length - tail.length)}$tail';
  }
}

/// Raised by a [PhoneVerificationRepository] when a request cannot be served.
class PhoneVerificationFailure implements Exception {
  const PhoneVerificationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
