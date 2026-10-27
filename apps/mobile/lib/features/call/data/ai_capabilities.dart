import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/config/app_config.dart';

/// Reads the server's actual AI capabilities in API mode.
///
/// The app never enables a provider from this value: it only hides speech
/// affordances the server says are unavailable. Mock mode performs no request,
/// and any transport or contract failure resolves to null so callers fail
/// closed (speech unavailable, never a paid adapter switched on locally).
final aiCapabilitiesProvider = FutureProvider<wire.Capabilities?>((ref) async {
  if (!ref.watch(appConfigProvider).isApi) return null;
  try {
    return await ref.watch(apiEndpointsProvider).getCapabilities();
  } catch (_) {
    return null;
  }
});
