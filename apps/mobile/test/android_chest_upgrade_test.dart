import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/quests/domain/upgrade_chest.dart';
import 'package:cocenglish/features/quests/presentation/upgrade_chest_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const receipt = UpgradeChestReward(
  receiptId: 'test-receipt',
  tiers: [
    ChestRarity.common,
    ChestRarity.rare,
    ChestRarity.rare,
    ChestRarity.epic,
  ],
  gems: 20,
);

void main() {
  testWidgets('Mega receipt opens and CONTINUE closes the real reward dialog', (
    t,
  ) async {
    const mega = UpgradeChestReward(
      receiptId: 'mega',
      tiers: [
        ChestRarity.common,
        ChestRarity.rare,
        ChestRarity.epic,
        ChestRarity.mega,
      ],
      gems: 40,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: referenceTheme(),
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showUpgradeChest(context, mega),
              child: const Text('Open reward'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open reward'));
    await t.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
      await t.pumpAndSettle();
    }
    expect(find.text('MEGA'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
    await t.pumpAndSettle();
    expect(find.text('+40 gems'), findsOneWidget);
    await t.tap(find.text('CONTINUE'));
    await t.pumpAndSettle();
    expect(find.byType(UpgradeChestScreen), findsNothing);
    expect(find.text('Open reward'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  test(
    'receipt rejects impossible tiers and the server amount stays immutable',
    () {
      expect(
        () => UpgradeChestReward.checked('x', [
          'COMMON',
          'EPIC',
          'EPIC',
          'EPIC',
        ], 20),
        throwsFormatException,
      );
      expect(
        () => UpgradeChestReward.checked('x', ['COMMON'], 20),
        throwsFormatException,
      );
      final state = UpgradeChestProgress(receipt);
      for (var i = 0; i < 10; i++) {
        state.tap();
      }
      expect(state.rarity, ChestRarity.epic);
      expect(state.revealed, isTrue);
      expect(state.reward.gems, 20);
      expect(state.attempts, 3);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets('three guarded upgrades then open, reduced=$reduced', (
      t,
    ) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: referenceTheme(),
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: child!,
          ),
          home: const UpgradeChestScreen(reward: receipt),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('COMMON'), findsOneWidget);
      expect(find.text('CONTINUE'), findsNothing);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
        if (!reduced) {
          await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
          await t.pump(const Duration(milliseconds: 60));
          expect(find.text('+20 gems'), findsNothing);
        }
        await t.pumpAndSettle();
      }
      expect(find.text('EPIC'), findsOneWidget);
      expect(find.text('Tap to open!'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
      if (!reduced) {
        await t.pump(const Duration(milliseconds: 60));
        expect(find.text('+20 gems'), findsNothing);
      }
      await t.pumpAndSettle();
      expect(find.text('+20 gems'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
      expect(t.takeException(), isNull);
    });
  }
}
