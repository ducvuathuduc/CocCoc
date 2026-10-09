import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/application/avatar_controller.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';
import 'package:cocenglish/features/account/presentation/avatar_builder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> pumpAvatarBuilder(
  WidgetTester tester, {
  double width = 390,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const _Launcher(),
      ),
    ),
  );
  await tester.tap(find.text('Open builder'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return container;
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AvatarBuilderScreen()),
        ),
        child: const Text('Open builder'),
      ),
    ),
  );
}

void main() {
  testWidgets('shows all current categories and saves a valid choice', (
    tester,
  ) async {
    final container = await pumpAvatarBuilder(tester);

    expect(find.text('Create Avatar'), findsOneWidget);
    for (final label in [
      'Body',
      'Expression',
      'Hairstyle',
      'Accessories',
      'Facial hair',
      'Headwear',
      'Clothing',
      'Background',
    ]) {
      expect(find.bySemanticsLabel('$label category'), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Mask category'), findsNothing);
    expect(find.text('Skin tone'), findsOneWidget);
    expect(find.bySemanticsLabel('Done'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Body option 3'));
    await tester.pump();
    expect(container.read(avatarControllerProvider).dirty, isTrue);
    await tester.tap(find.bySemanticsLabel('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Open builder'), findsOneWidget);
    expect(container.read(avatarControllerProvider).saved['Body'], 3);
    expect(container.read(avatarControllerProvider).hasAvatar, isTrue);
  });

  testWidgets('close and system back discard an unsaved draft', (tester) async {
    final container = await pumpAvatarBuilder(tester);

    await tester.tap(find.bySemanticsLabel('Body option 3'));
    await tester.tap(find.bySemanticsLabel('Close avatar builder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(avatarControllerProvider).saved['Body'], 1);
    expect(container.read(avatarControllerProvider).dirty, isFalse);

    await tester.tap(find.text('Open builder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.bySemanticsLabel('Body option 4'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(avatarControllerProvider).saved['Body'], 1);
    expect(container.read(avatarControllerProvider).dirty, isFalse);
  });

  testWidgets('options remain reachable at narrow width and large text', (
    tester,
  ) async {
    await pumpAvatarBuilder(tester, width: 320, textScale: 2);

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.bySemanticsLabel('Background category'));
    await tester.tap(find.bySemanticsLabel('Background category'));
    await tester.pump();
    expect(find.text('Background color'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Background color option 24'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
