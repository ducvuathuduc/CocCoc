import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/streak_repair/application/streak_repair_controller.dart';
import 'package:cocenglish/features/streak_repair/data/streak_repair_repository.dart';
import 'package:cocenglish/features/streak_repair/domain/streak_repair.dart';
import 'package:cocenglish/features/streak_repair/presentation/streak_repair_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fonts.dart';
import '../../support/settle_images.dart';
import 'screen_pump.dart';

const _offer = StreakRepairOffer(lostDays: 47, lostStreakDay: '2026-10-12');

Future<(ProviderContainer, MockStreakRepairRepository)> _pump(
  WidgetTester tester, {
  StreakRepairOffer? offer = _offer,
  bool succeed = true,
  bool fund = true,
  Size size = const Size(360, 800),
  double scale = 1,
}) async {
  final repo = MockStreakRepairRepository(offer: offer, succeed: succeed);
  final c = await pumpScreen(
    tester,
    StreakRepairScreen.route,
    const StreakRepairScreen(),
    overrides: [streakRepairRepositoryProvider.overrideWithValue(repo)],
    size: size,
    scale: scale,
  );
  if (fund) c.read(previewControllerProvider.notifier).useDemoBalance();
  await tester.pumpAndSettle();
  return (c, repo);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('lost streak shows repository copy and gem price', (t) async {
    await _pump(t);
    const content = StreakRepairContent();
    expect(find.text(content.lostTitle), findsOneWidget);
    expect(find.text(content.lostBody(47)), findsOneWidget);
    expect(find.text('REPAIR FOR 350'), findsOneWidget);
    expect(find.text('23h 40m'), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-repair-item')), findsNothing);
  });

  testWidgets('gems repair spends the price and restores', (t) async {
    final (c, repo) = await _pump(t);
    final before = c.read(previewWalletProvider);
    await t.tap(find.byKey(const ValueKey('streak-repair-gems')));
    await t.pumpAndSettle();
    expect(c.read(previewWalletProvider), before - 350);
    expect(repo.requests.single, ('2026-10-12', StreakRepairPayment.gems));
    expect(find.text('47 day streak restored!'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('streak-repair-continue')));
    await t.pumpAndSettle();
    expect(find.text('Stub /home'), findsOneWidget);
  });

  testWidgets('not enough gems shows an error and keeps the offer', (t) async {
    final (c, repo) = await _pump(t, fund: false);
    expect(c.read(previewWalletProvider), lessThan(350));
    await t.tap(find.byKey(const ValueKey('streak-repair-gems')));
    await t.pumpAndSettle();
    expect(
      find.text(const StreakRepairContent().notEnoughGems),
      findsOneWidget,
    );
    expect(repo.requests, isEmpty);
  });

  testWidgets('owned Streak Repair is offered first and free', (t) async {
    final (c, repo) = await _pump(
      t,
      offer: const StreakRepairOffer(
        lostDays: 12,
        lostStreakDay: '2026-10-12',
        repairItems: 1,
      ),
    );
    final before = c.read(previewWalletProvider);
    await t.tap(find.byKey(const ValueKey('streak-repair-item')));
    await t.pumpAndSettle();
    expect(c.read(previewWalletProvider), before);
    expect(repo.requests.single.$2, StreakRepairPayment.item);
    expect(find.text('12 day streak restored!'), findsOneWidget);
  });

  testWidgets('server refusal keeps gems and shows failure', (t) async {
    final (c, _) = await _pump(t, succeed: false);
    final before = c.read(previewWalletProvider);
    await t.tap(find.byKey(const ValueKey('streak-repair-gems')));
    await t.pumpAndSettle();
    expect(c.read(previewWalletProvider), before);
    expect(find.text(const StreakRepairContent().failed), findsOneWidget);
  });

  testWidgets('NO THANKS closes without repairing', (t) async {
    final (_, repo) = await _pump(t);
    await t.tap(find.byKey(const ValueKey('streak-repair-decline')));
    await t.pumpAndSettle();
    expect(find.text('Stub /home'), findsOneWidget);
    expect(repo.requests, isEmpty);
  });

  testWidgets('banner only appears while an offer exists', (t) async {
    for (final offer in [null, _offer]) {
      final repo = MockStreakRepairRepository(offer: offer);
      await t.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [streakRepairRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: Scaffold(body: StreakRepairBanner())),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('streak-repair-banner')),
        offer == null ? findsNothing : findsOneWidget,
      );
    }
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('no overflow at $size with 2x text', (t) async {
      await _pump(t, size: size, scale: 2);
      expect(t.takeException(), isNull);
    });
  }

  for (final repaired in [false, true]) {
    testWidgets('streak repair ${repaired ? 'restored' : 'offer'} golden', (
      t,
    ) async {
      await _pump(t);
      if (repaired) {
        await t.tap(find.byKey(const ValueKey('streak-repair-gems')));
        await t.pumpAndSettle();
        await settleImages(t);
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/gap/streak_repair_${repaired ? 'restored' : 'offer'}_360.png',
        ),
      );
    });
  }
}
