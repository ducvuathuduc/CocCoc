import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/connectivity/application/connectivity_provider.dart';
import 'package:cocenglish/features/connectivity/data/connectivity_repository.dart';
import 'package:cocenglish/features/learning/presentation/learning_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';
import '../../support/settle_images.dart';

/// Visual evidence for audit row 8 (sc_12b09a6c, refs/gap/offline_banner.png).
void main() {
  setUpAll(loadAppFonts);
  testWidgets('offline banner and greyed path at 360', (t) async {
    t.view.physicalSize = const Size(360, 780);
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
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 56, bottom: 34),
                disableAnimations: true,
              ),
              child: const Scaffold(body: SafeArea(child: LearningPath())),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await settleImages(t);
    expect(find.text('YOU ARE OFFLINE'), findsOneWidget);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/gap/offline_path_360.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
  });
}
