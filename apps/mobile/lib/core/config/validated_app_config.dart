import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client/api_exception.dart';
import 'app_config.dart';
import 'real_profile_validation.dart';

/// Shared admission boundary before SDK/HTTP construction and session I/O.
final validatedAppConfigProvider = Provider<AppConfig>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.isApi) return config;
  final issues = validateRealProfile(
    config,
    target: kReleaseMode
        ? RealProfileTarget.releaseNative
        : RealProfileTarget.localNative,
  );
  if (issues.isNotEmpty) {
    throw ApiException(
      code: 'NOT_CONFIGURED',
      message: 'Real profile is unavailable.',
      details: {'issues': issues},
    );
  }
  return config;
});
