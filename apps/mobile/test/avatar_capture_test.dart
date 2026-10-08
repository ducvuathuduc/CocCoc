import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/application/avatar_controller.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';
import 'package:cocenglish/features/account/presentation/avatar_builder_screen.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/progress/presentation/hub_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('original avatar builder source sized captures', (t) async {
    if (!const bool.fromEnvironment('CAPTURE_AVATAR_UI')) return;
    const ratio = 1180 / 390;
    t.view.physicalSize = const Size(1180, 2556);
    t.view.devicePixelRatio = ratio;
    t.view.padding = const FakeViewPadding(top: 59 * ratio, bottom: 34 * ratio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPadding);
    await t.runAsync(() async {
      await (FontLoader('DuolingoSans')
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final c = ProviderContainer();
    final catalog = await t.runAsync(
      () => c.read(avatarCatalogProvider.future),
    );
    final vm = c.read(avatarControllerProvider.notifier);
    vm.attachCatalog(catalog!);
    final key = GlobalKey();
    final output = Directory('../../docs/design/qa/avatar');
    await t.runAsync(() => output.create(recursive: true));
    for (var scene = 0; scene < 10; scene++) {
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: referenceTheme(),
            home: RepaintBoundary(
              key: key,
              child: scene == 8
                  ? const EditProfileScreen()
                  : scene == 9
                  ? const ProfileScreen()
                  : const AvatarBuilderScreen(),
            ),
          ),
        ),
      );
      await t.pump();
      if (scene < 8) {
        vm.selectTab(scene);
        if (scene == 1) vm.select('SkinTone', 5);
        if (scene == 2) vm.select('Expression', 32);
        if (scene == 3) vm.select('MainHair', 40);
        if (scene == 4) vm.select('Glasses', 1);
        if (scene == 5) vm.select('FacialHair', 1);
        if (scene == 6) vm.select('Headwear', 10);
        if (scene == 7) {
          vm.select('ClothingColor', 4);
          vm.select('BackgroundColor', 19);
        }
      }
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final frame = await boundary.toImage(pixelRatio: ratio);
        final bytes = (await frame.toByteData(format: ui.ImageByteFormat.png))!;
        await File('${output.path}/state-$scene.png')
            .writeAsBytes(bytes.buffer.asUint8List());
        frame.dispose();
      });
      expect(t.takeException(), isNull);
      if (scene == 7) vm.save();
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    c.dispose();
  });
}
