import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/legal/domain/legal_models.dart';
import 'package:cocenglish/features/legal/presentation/legal_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final kind in LegalDocumentKind.values) {
    testWidgets('legal ${kind.name} golden', (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: referenceTheme(),
            home: RepaintBoundary(
              key: const ValueKey('page'),
              child: LegalDocumentScreen(kind: kind),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('page')),
        matchesGoldenFile('goldens/legal/legal_${kind.name}.png'),
      );
    });
  }
}
