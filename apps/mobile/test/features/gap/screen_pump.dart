import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/settle_images.dart';

/// Pumps [screen] at [path] behind a launcher ('/') with stub destinations,
/// so pops and pushes are observable. Returns the container.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  String path,
  Widget screen, {
  List<Override> overrides = const [],
  Size size = const Size(360, 800),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Launcher')),
        routes: const [],
      ),
      GoRoute(path: path, builder: (_, _) => screen),
      for (final stub in [
        '/super',
        '/home',
        '/streak/repair',
        '/settings/promo',
        '/settings/super-features',
      ])
        if (stub != path)
          GoRoute(
            path: stub,
            builder: (_, _) => Scaffold(body: Text('Stub $stub')),
          ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: referenceTheme(),
        routerConfig: router,
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await settleImages(tester);
  return container;
}
