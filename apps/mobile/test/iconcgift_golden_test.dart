import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/app_icon/data/app_icon_repository.dart';
import 'package:cocenglish/features/app_icon/domain/app_icon_choice.dart';
import 'package:cocenglish/features/gift/application/gift_controller.dart';
import 'package:cocenglish/features/gift/data/gift_repository.dart';
import 'package:cocenglish/features/gift/presentation/gift_screens.dart';
import 'package:cocenglish/features/progress/application/streak_controller.dart';
import 'package:cocenglish/features/progress/presentation/streak_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

// The test renderer has no emoji font, so the ref's ❤️ is omitted.
const _note = 'Surprise! Can’t wait to see you flex those new phrases';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await ReferenceArt.preloadFiles([
      'app-icon-select',
      'gift-subscription',
      'gift-intro',
      'gift-note',
      '01',
      'streak-protection',
    ]);
  });

  Future<ProviderContainer> pump(
    WidgetTester t,
    Widget home, {
    required double width,
    required double scale,
    void Function(ProviderContainer c)? prepare,
    Future<void> Function(ProviderContainer c)? prepareAsync,
  }) async {
    t.view.physicalSize = Size(width, width == 430 ? 932 : 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = ProviderContainer(
      overrides: [
        giftRepositoryProvider.overrideWithValue(
          MockGiftRepository(latency: Duration.zero),
        ),
        appIconRepositoryProvider.overrideWithValue(MockAppIconRepository()),
        streakFixtureProvider.overrideWithValue(
          StreakFixture(
            days: 12,
            month: DateTime(2026, 10),
            practiced: {for (var d = 1; d <= 11; d++) d},
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    prepare?.call(c);
    if (prepareAsync != null) await prepareAsync(c);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: referenceTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
              padding: const EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: RepaintBoundary(
              key: const ValueKey('iconcgift-screen'),
              child: child!,
            ),
          ),
          home: home,
        ),
      ),
    );
    await t.pumpAndSettle();
    await settleImages(t);
    return c;
  }

  Future<void> openIconSheet(WidgetTester t) async {
    final change = find.text('CHANGE APP ICON');
    if (change.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        change,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(change);
    await t.pumpAndSettle();
    await t.tap(change);
    await t.pumpAndSettle();
    await settleImages(t);
  }

  void selectMaya(ProviderContainer c) {
    final vm = c.read(giftControllerProvider.notifier);
    vm.selectRecipient('maya');
  }

  final cases =
      <
        String,
        (
          Widget,
          void Function(ProviderContainer)?,
          Future<void> Function(ProviderContainer)?,
          Future<void> Function(WidgetTester)?,
        )
      >{
        'icon_sheet': (const StreakScreen(), null, null, openIconSheet),
        'icon_dialog': (
          const StreakScreen(),
          null,
          null,
          (t) async {
            await openIconSheet(t);
            await t.tap(find.byKey(const ValueKey('app-icon-max')));
            await t.pumpAndSettle();
            await settleImages(t);
          },
        ),
        'icon_selected': (
          const StreakScreen(),
          null,
          (c) async => c
              .read(appIconRepositoryProvider)
              .setIcon(AppIconChoice.streakSociety),
          openIconSheet,
        ),
        'gift_hub': (const GiftSubscriptionScreen(), null, null, null),
        'gift_intro': (const GiftSuperIntroScreen(), null, null, null),
        'gift_recipient': (const GiftRecipientScreen(), selectMaya, null, null),
        'gift_note_empty': (const GiftNoteScreen(), selectMaya, null, null),
        'gift_note_filled': (
          const GiftNoteScreen(),
          (c) {
            selectMaya(c);
            c.read(giftControllerProvider.notifier).setNote(_note);
          },
          null,
          null,
        ),
        'gift_checkout': (
          const GiftNoteScreen(),
          (c) {
            selectMaya(c);
            c.read(giftControllerProvider.notifier).setNote(_note);
          },
          null,
          (t) async {
            await t.tap(find.byKey(const ValueKey('gift-continue-payment')));
            await t.pumpAndSettle();
          },
        ),
        'gift_sent': (
          const GiftSentScreen(),
          null,
          (c) async {
            selectMaya(c);
            final vm = c.read(giftControllerProvider.notifier);
            vm.setNote(_note);
            await vm.purchase();
          },
          null,
        ),
      };

  for (final MapEntry(key: name, value: (home, prep, prepAsync, act))
      in cases.entries) {
    for (final (width, scale) in const [(430.0, 1.0), (360.0, 2.0)]) {
      testWidgets('$name ${width.toInt()} text${scale.toInt()}', (t) async {
        await pump(
          t,
          home,
          width: width,
          scale: scale,
          prepare: prep,
          prepareAsync: prepAsync,
        );
        if (act != null) await act(t);
        expect(t.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('iconcgift-screen')),
          matchesGoldenFile(
            'goldens/iconcgift/${name}_${width.toInt()}_text${scale.toInt()}.png',
          ),
        );
      });
    }
  }
}
