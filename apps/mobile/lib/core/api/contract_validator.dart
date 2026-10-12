import 'dart:convert';

import 'generated/api_schemas.g.dart';

/// Thrown when a payload does not satisfy its `docs/api/openapi.yaml` schema.
final class ContractViolation implements Exception {
  const ContractViolation(this.schema, this.errors);

  /// Component schema name the payload was checked against.
  final String schema;

  /// JSON-pointer-ish paths with the failed keyword, for diagnostics only.
  final List<String> errors;

  @override
  String toString() => 'ContractViolation($schema): ${errors.join('; ')}';
}

/// Distinguishes an absent optional property from one sent as explicit
/// `null` (for example `ProfilePatch.avatarId: null` clears the avatar while
/// omitting it leaves the avatar unchanged).
final class JsonPresence<T> {
  const JsonPresence.absent() : isPresent = false, value = null;

  const JsonPresence.value(this.value) : isPresent = true;

  final bool isPresent;
  final T? value;

  @override
  bool operator ==(Object other) =>
      other is JsonPresence<T> &&
      other.isPresent == isPresent &&
      other.value == value;

  @override
  int get hashCode => Object.hash(isPresent, value);
}

/// JSON Schema 2020-12 subset validator over the generated copy of
/// `components.schemas`. It implements exactly the keywords the generator
/// admits (the generator fails on anything else) with Ajv semantics:
/// `allErrors`, formats `uuid` and `date-time` as in ajv-formats "full" mode,
/// string lengths in Unicode code points, and annotation keywords
/// (`discriminator`, `contentEncoding`) ignored as Ajv `strict:false` does.
final class ContractValidator {
  ContractValidator._(this._schemas);

  static final ContractValidator instance = ContractValidator._(
    Map<String, Object?>.unmodifiable(
      jsonDecode(apiSchemasJson) as Map<String, Object?>,
    ),
  );

  final Map<String, Object?> _schemas;
  final Map<String, RegExp> _patterns = <String, RegExp>{};

  /// Every component schema name known to the validator.
  Iterable<String> get schemaNames => _schemas.keys;

  /// Throws [ContractViolation] unless [json] matches schema [name].
  void check(String name, Object? json) {
    final List<String> errors = validate(name, json);
    if (errors.isNotEmpty) throw ContractViolation(name, errors);
  }

  /// Returns validation errors for [json] against schema [name] (empty = valid).
  List<String> validate(String name, Object? json) {
    final Object? schema = _schemas[name];
    if (schema == null) {
      throw ArgumentError.value(name, 'name', 'Unknown contract schema');
    }
    final List<String> errors = <String>[];
    _validate(schema, json, r'$', errors);
    return errors;
  }

  bool _valid(Object? schema, Object? value) {
    final List<String> errors = <String>[];
    _validate(schema, value, r'$', errors);
    return errors.isEmpty;
  }

  void _validate(
    Object? schema,
    Object? value,
    String at,
    List<String> errors,
  ) {
    if (schema == true) return;
    if (schema == false) {
      errors.add('$at: false schema');
      return;
    }
    final Map<Object?, Object?> s = schema! as Map<Object?, Object?>;

    final Object? ref = s[r'$ref'];
    if (ref is String) {
      const String prefix = '#/components/schemas/';
      if (!ref.startsWith(prefix)) {
        throw StateError('Unsupported \$ref $ref');
      }
      _validate(_schemas[ref.substring(prefix.length)], value, at, errors);
    }

    final Object? type = s['type'];
    if (type != null) {
      final List<Object?> types = type is List ? type : <Object?>[type];
      if (!types.any((Object? t) => _typeMatches(t! as String, value))) {
        errors.add('$at: expected type $type');
        return;
      }
    }

    if (s.containsKey('enum')) {
      final List<Object?> options = s['enum']! as List<Object?>;
      if (!options.any((Object? o) => _deepEquals(o, value))) {
        errors.add('$at: not in enum $options');
      }
    }
    if (s.containsKey('const') && !_deepEquals(s['const'], value)) {
      errors.add('$at: expected const ${s['const']}');
    }

    if (value is Map) _validateObject(s, value, at, errors);
    if (value is List) _validateArray(s, value, at, errors);
    if (value is String) _validateString(s, value, at, errors);
    if (value is num) _validateNumber(s, value, at, errors);

    final Object? anyOf = s['anyOf'];
    if (anyOf is List && !anyOf.any((Object? sub) => _valid(sub, value))) {
      errors.add('$at: matches no anyOf branch');
    }
    final Object? oneOf = s['oneOf'];
    if (oneOf is List) {
      final int matches = oneOf.where((Object? sub) => _valid(sub, value)).length;
      if (matches != 1) {
        errors.add('$at: matches $matches oneOf branches (expected exactly 1)');
      }
    }
    final Object? allOf = s['allOf'];
    if (allOf is List) {
      for (final Object? sub in allOf) {
        _validate(sub, value, at, errors);
      }
    }
    if (s.containsKey('if')) {
      if (_valid(s['if'], value)) {
        if (s.containsKey('then')) _validate(s['then'], value, at, errors);
      } else if (s.containsKey('else')) {
        _validate(s['else'], value, at, errors);
      }
    }
  }

  void _validateObject(
    Map<Object?, Object?> s,
    Map<Object?, Object?> value,
    String at,
    List<String> errors,
  ) {
    if (value.keys.any((Object? k) => k is! String)) {
      errors.add('$at: object keys must be strings');
      return;
    }
    final Object? required = s['required'];
    if (required is List) {
      for (final Object? key in required) {
        if (!value.containsKey(key)) errors.add('$at: missing required $key');
      }
    }
    final Map<Object?, Object?> properties =
        (s['properties'] as Map<Object?, Object?>?) ??
        const <Object?, Object?>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final String key = entry.key! as String;
      if (properties.containsKey(key)) {
        _validate(properties[key], entry.value, '$at.$key', errors);
      } else if (s.containsKey('additionalProperties')) {
        final Object? extra = s['additionalProperties'];
        if (extra == false) {
          errors.add('$at: unexpected property $key');
        } else {
          _validate(extra, entry.value, '$at.$key', errors);
        }
      }
    }
  }

  void _validateArray(
    Map<Object?, Object?> s,
    List<Object?> value,
    String at,
    List<String> errors,
  ) {
    final Object? minItems = s['minItems'];
    if (minItems is num && value.length < minItems) {
      errors.add('$at: fewer than $minItems items');
    }
    final Object? maxItems = s['maxItems'];
    if (maxItems is num && value.length > maxItems) {
      errors.add('$at: more than $maxItems items');
    }
    if (s.containsKey('items')) {
      for (int i = 0; i < value.length; i++) {
        _validate(s['items'], value[i], '$at[$i]', errors);
      }
    }
  }

  void _validateString(
    Map<Object?, Object?> s,
    String value,
    String at,
    List<String> errors,
  ) {
    final int length = value.runes.length;
    final Object? minLength = s['minLength'];
    if (minLength is num && length < minLength) {
      errors.add('$at: shorter than $minLength');
    }
    final Object? maxLength = s['maxLength'];
    if (maxLength is num && length > maxLength) {
      errors.add('$at: longer than $maxLength');
    }
    final Object? pattern = s['pattern'];
    if (pattern is String) {
      final RegExp regExp = _patterns.putIfAbsent(
        pattern,
        () => RegExp(pattern, unicode: true),
      );
      if (!regExp.hasMatch(value)) errors.add('$at: does not match $pattern');
    }
    final Object? format = s['format'];
    if (format == 'uuid' && !_uuid.hasMatch(value)) {
      errors.add('$at: not a uuid');
    } else if (format == 'date-time' && !_isDateTime(value)) {
      errors.add('$at: not an RFC 3339 date-time');
    }
  }

  void _validateNumber(
    Map<Object?, Object?> s,
    num value,
    String at,
    List<String> errors,
  ) {
    final Object? minimum = s['minimum'];
    if (minimum is num && value < minimum) errors.add('$at: below $minimum');
    final Object? maximum = s['maximum'];
    if (maximum is num && value > maximum) errors.add('$at: above $maximum');
  }

  static bool _typeMatches(String type, Object? value) => switch (type) {
    'null' => value == null,
    'boolean' => value is bool,
    'object' => value is Map,
    'array' => value is List,
    'string' => value is String,
    'number' => value is num && value.isFinite,
    'integer' =>
      value is int ||
          (value is double && value.isFinite && value == value.truncateToDouble()),
    _ => throw StateError('Unsupported JSON Schema type $type'),
  };

  static bool _deepEquals(Object? a, Object? b) {
    if (a is num && b is num) return a == b;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final Object? key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    return a == b;
  }

  // ajv-formats "full" mode definitions.
  static final RegExp _uuid = RegExp(
    r'^(?:urn:uuid:)?[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final RegExp _date = RegExp(r'^(\d\d\d\d)-(\d\d)-(\d\d)$');
  static final RegExp _time = RegExp(
    r'^(\d\d):(\d\d):(\d\d(?:\.\d+)?)(z|([+-])(\d\d)(?::?(\d\d))?)?$',
    caseSensitive: false,
  );
  static final RegExp _dateTimeSeparator = RegExp(r't|\s', caseSensitive: false);
  static const List<int> _days = <int>[0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  static bool _isDateTime(String value) {
    final List<String> parts = value.split(_dateTimeSeparator);
    return parts.length == 2 && _isDate(parts[0]) && _isTime(parts[1]);
  }

  static bool _isDate(String value) {
    final RegExpMatch? m = _date.firstMatch(value);
    if (m == null) return false;
    final int year = int.parse(m[1]!);
    final int month = int.parse(m[2]!);
    final int day = int.parse(m[3]!);
    final bool leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    return month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= (month == 2 && leap ? 29 : _days[month]);
  }

  static bool _isTime(String value) {
    final RegExpMatch? m = _time.firstMatch(value);
    if (m == null) return false;
    final int hour = int.parse(m[1]!);
    final int minute = int.parse(m[2]!);
    final double second = double.parse(m[3]!);
    final String? zone = m[4];
    final int sign = m[5] == '-' ? -1 : 1;
    final int zoneHour = int.parse(m[6] ?? '0');
    final int zoneMinute = int.parse(m[7] ?? '0');
    if (zoneHour > 23 || zoneMinute > 59 || zone == null) return false;
    if (hour <= 23 && minute <= 59 && second < 60) return true;
    final int utcMinute = minute - zoneMinute * sign;
    final int utcHour = hour - zoneHour * sign - (utcMinute < 0 ? 1 : 0);
    return (utcHour == 23 || utcHour == -1) &&
        (utcMinute == 59 || utcMinute == -1) &&
        second < 61;
  }
}
