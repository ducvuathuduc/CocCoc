import 'package:cocenglish/core/api/client/api_endpoints.g.dart';
import 'package:cocenglish/core/api/client/api_providers.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/domain/auth_state.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/domain/preview_state.dart';
import 'package:cocenglish/features/progress/presentation/own_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_transport.dart';
import 'support/real_profile.dart';

class _Identity extends AuthController {
  @override
  AuthState build() => const AuthState(
    user: AuthUser(id: 'a', email: 'a@example.test', name: 'Verified A'),
  );
}

class _NoPreview extends PreviewController {
  @override
  PreviewState build() => throw StateError('Real profile read preview');
}

class _SectionProgress extends LearningStateController {
  @override
  LearningState build() => const LearningState();
}

void main() {
  testWidgets('reachable API profile never reads preview identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(realTestConfig),
          authControllerProvider.overrideWith(_Identity.new),
          apiEndpointsProvider.overrideWithValue(
            ApiEndpoints(fakeClient(FakeApiTransport())),
          ),
          snapshotStoreProvider.overrideWithValue(MemorySnapshotStore()),
          previewControllerProvider.overrideWith(_NoPreview.new),
          learningStateProvider.overrideWith(_SectionProgress.new),
        ],
        child: const MaterialApp(home: OwnProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Verified A'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
