import 'package:cocenglish/core/api/client/api_exception.dart';
import 'package:cocenglish/core/api/client/api_transport.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/connectivity/application/connectivity_provider.dart';
import 'package:cocenglish/features/connectivity/data/api_connectivity_repository.dart';
import 'package:cocenglish/features/connectivity/data/connectivity_repository.dart';
import 'package:cocenglish/features/connectivity/presentation/offline_banner.dart';
import 'package:cocenglish/features/learning/presentation/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('path toggles offline banner, reduced=$reduced', (t) async {
      final repository = MockConnectivityRepository();
      addTearDown(repository.dispose);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: referenceTheme(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: const Scaffold(body: LearningPath()),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('YOU ARE OFFLINE'), findsNothing);
      expect(find.byType(OfflinePathTint), findsNothing);
      repository.setOnline(false);
      await t.pump();
      await t.pump();
      expect(find.text('YOU ARE OFFLINE'), findsOneWidget);
      final animated = find.descendant(
        of: find.byType(OfflineBanner),
        matching: find.byType(AnimatedSize),
      );
      if (reduced) {
        expect(animated, findsNothing);
      } else {
        expect(
          t.widget<AnimatedSize>(animated).duration,
          const Duration(milliseconds: 250),
        );
      }
      await t.pumpAndSettle();
      expect(find.byType(OfflinePathTint), findsWidgets);
      // The current lesson stays usable; filtering must not block gestures.
      await t.tap(find.byTooltip('Start lesson 1'));
      await t.pumpAndSettle();
      expect(find.text('START +20 XP'), findsOneWidget);
      repository.setOnline(true);
      await t.pumpAndSettle();
      expect(find.text('YOU ARE OFFLINE'), findsNothing);
      expect(find.byType(OfflinePathTint), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('offline banner and path fit text scale 2 at 360', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repository = MockConnectivityRepository(initialOnline: false);
    addTearDown(repository.dispose);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: referenceTheme(),
          home: const MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(body: LearningPath()),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('YOU ARE OFFLINE'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  test(
    'API transport failure signals offline and any HTTP response recovers',
    () async {
      final repository = ApiConnectivityRepository();
      addTearDown(repository.dispose);
      final transport = _Transport();
      final observed = repository.observe(transport);
      final changes = <bool>[];
      final sub = repository.online.listen(changes.add);
      addTearDown(sub.cancel);
      final request = ApiHttpRequest(
        method: 'GET',
        uri: Uri.parse('https://example.test/path'),
      );
      transport.failure = const ApiTransportException('no network');
      await expectLater(
        observed.send(request),
        throwsA(isA<ApiTransportException>()),
      );
      expect(repository.currentOnline, isFalse);
      repository.reportFailure(
        const ApiException(
          code: 'UNAUTHENTICATED',
          message: 'expired',
          statusCode: 401,
        ),
      );
      expect(repository.currentOnline, isFalse);
      transport.failure = null;
      await observed.send(request);
      expect(repository.currentOnline, isTrue);
      repository.reportFailure(
        const ApiException(code: 'TIMEOUT', message: 'timeout'),
      );
      expect(repository.currentOnline, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(changes, [false, true, false]);
    },
  );
}

class _Transport implements ApiTransport {
  ApiTransportException? failure;
  @override
  Future<ApiHttpResponse> send(
    ApiHttpRequest request, {
    Duration? timeout,
  }) async {
    if (failure != null) throw failure!;
    return const ApiHttpResponse(401, '{}');
  }
}
