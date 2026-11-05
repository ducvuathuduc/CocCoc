import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';
import 'package:cocenglish/features/account/presentation/avatar_builder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AvatarBuilderScreen matches golden 430', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(avatarCatalogProvider.future));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: referenceTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: RepaintBoundary(
              key: ValueKey('avatar-screen'),
              child: AvatarBuilderScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    // The avatar is a Rive file decoded on real async IO: let it load, then
    // render, so the golden shows the avatar instead of placeholder icons.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('avatar-screen')),
      matchesGoldenFile('goldens/ui_master/sprint_avatar_screen_430.png'),
    );
  });
}
