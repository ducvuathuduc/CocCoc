import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/features/account/presentation/avatar_builder_screen.dart';

void main() {
  testWidgets('AvatarBuilderScreen matches golden', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AvatarBuilderScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AvatarBuilderScreen),
      matchesGoldenFile('goldens/ui_master/sprint_avatar_screen_430.png'),
    );
  });
}
