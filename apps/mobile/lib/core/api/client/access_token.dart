/// Supplies the bearer token for API calls (an Appwrite JWT).
abstract interface class AccessTokenProvider {
  /// Current JWT, minting a new one when needed. Null when signed out.
  Future<String?> token();

  /// Drops any cached token (after a 401 or sign-out).
  void invalidate();
}

/// Caches JWTs minted by [mint] until shortly before they expire.
///
/// Appwrite account JWTs are valid for 15 minutes; refresh after [lifetime].
final class CachingTokenProvider implements AccessTokenProvider {
  CachingTokenProvider(
    this.mint, {
    this.lifetime = const Duration(minutes: 13),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Future<String?> Function() mint;
  final Duration lifetime;
  final DateTime Function() _clock;

  String? _token;
  DateTime? _mintedAt;
  Future<String?>? _inFlight;

  @override
  Future<String?> token() {
    final cached = _token;
    final mintedAt = _mintedAt;
    if (cached != null &&
        mintedAt != null &&
        _clock().difference(mintedAt) < lifetime) {
      return Future.value(cached);
    }
    return _inFlight ??= _mint();
  }

  Future<String?> _mint() async {
    try {
      final value = await mint();
      _token = value;
      _mintedAt = value == null ? null : _clock();
      return value;
    } finally {
      _inFlight = null;
    }
  }

  @override
  void invalidate() {
    _token = null;
    _mintedAt = null;
  }
}

/// Fixed token, for tests and local dev services.
final class StaticTokenProvider implements AccessTokenProvider {
  const StaticTokenProvider(this.value);

  final String? value;

  @override
  Future<String?> token() async => value;

  @override
  void invalidate() {}
}
