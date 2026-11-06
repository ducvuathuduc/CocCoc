import 'package:cocenglish/core/design/cocenglish_brand.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/core/design/reference_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('orange controls retain the dark palette and remain actionable', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: referenceTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: Column(
            children: [
              ReferenceButton(label: 'CONTINUE', onPressed: () => presses++),
              const ReferenceArt(
                ReferenceArtRegions.welcomeDuo,
                width: 100,
                height: 100,
                blendMode: BlendMode.lighten,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(ReferenceColors.primary, CocEnglishBrand.actionOrange);
    final context = tester.element(find.text('CONTINUE'));
    expect(context.referencePalette.surface, ReferencePalette.dark.surface);
    await tester.tap(find.text('CONTINUE'));
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });
}
