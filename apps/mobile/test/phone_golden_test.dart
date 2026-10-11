import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/phone/application/phone_verification_controller.dart';
import 'package:cocenglish/features/phone/presentation/phone_verification_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_fonts.dart';
import 'support/settle_images.dart';

typedef _Setup = Future<void> Function(
  WidgetTester t,
  PhoneVerificationController vm,
);

Future<void> _number(PhoneVerificationController vm, String n) async =>
    vm.editNumber(n);

Future<void> _toCode(PhoneVerificationController vm) async {
  vm.editNumber('6502137552');
  await vm.sendCode();
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await ReferenceArt.preloadFiles(['lesson-01']);
  });

  Future<void> shoot(
    WidgetTester t,
    String name,
    Widget screen, {
    _Setup? setup,
    double width = 393,
    double height = 852,
    double scale = 1,
    EdgeInsets padding = const EdgeInsets.only(top: 59, bottom: 34),
  }) async {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(phoneVerificationControllerProvider.notifier);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: RepaintBoundary(
          key: const ValueKey('page'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: referenceTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: padding,
                viewPadding: padding,
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: screen,
          ),
        ),
      ),
    );
    if (setup != null) await setup(t, vm);
    await t.pumpAndSettle();
    await settleImages(t);
    expect(t.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('page')),
      matchesGoldenFile('goldens/phone/$name.png'),
    );
    // Let any resend countdown run out before the container is disposed.
    await t.pump(const Duration(seconds: 31));
  }

  const number = PhoneNumberScreen(autofocus: false);
  const code = PhoneCodeScreen(autofocus: false);

  testWidgets('number empty', (t) => shoot(t, 'number_empty', number));
  testWidgets(
    'number filled',
    (t) => shoot(
      t,
      'number_filled',
      number,
      setup: (t, vm) async {
        await t.enterText(
          find.byKey(const ValueKey('phone-number')),
          '6502137552',
        );
      },
    ),
  );
  testWidgets(
    'number invalid',
    (t) => shoot(
      t,
      'number_invalid',
      number,
      setup: (t, vm) async {
        await t.enterText(
          find.byKey(const ValueKey('phone-number')),
          '6532137379',
        );
        await t.pump();
        await t.tap(find.text('NEXT'));
      },
    ),
  );
  testWidgets(
    'number server error',
    (t) => shoot(
      t,
      'number_server_error',
      number,
      setup: (t, vm) async {
        await t.enterText(
          find.byKey(const ValueKey('phone-number')),
          '6502137379',
        );
        await t.pump();
        await t.tap(find.text('NEXT'));
      },
    ),
  );
  testWidgets(
    'country list',
    (t) => shoot(t, 'country', const PhoneCountryScreen()),
  );
  testWidgets(
    'country search',
    (t) => shoot(
      t,
      'country_search',
      const PhoneCountryScreen(),
      setup: (t, vm) async {
        await t.enterText(
          find.byKey(const ValueKey('phone-country-search')),
          'an',
        );
      },
    ),
  );
  testWidgets(
    'code empty',
    (t) => shoot(t, 'code_empty', code, setup: (t, vm) => _toCode(vm)),
  );
  testWidgets(
    'code filled',
    (t) => shoot(
      t,
      'code_filled',
      code,
      setup: (t, vm) async {
        await _toCode(vm);
        await t.pump();
        await t.enterText(find.byKey(const ValueKey('phone-code')), '725719');
      },
    ),
  );
  testWidgets(
    'code wrong',
    (t) => shoot(
      t,
      'code_wrong',
      code,
      setup: (t, vm) async {
        await _toCode(vm);
        await t.pump();
        await t.enterText(find.byKey(const ValueKey('phone-code')), '725719');
        await t.pump();
        await t.tap(find.byKey(const ValueKey('phone-code-next')));
      },
    ),
  );
  testWidgets(
    'code resend countdown',
    (t) => shoot(
      t,
      'code_resend',
      code,
      setup: (t, vm) async {
        await _toCode(vm);
        await t.pump();
        await t.tap(find.byKey(const ValueKey('phone-resend')));
        await t.pump();
        await t.pump(const Duration(seconds: 12));
      },
    ),
  );
  testWidgets(
    'verified',
    (t) => shoot(
      t,
      'verified',
      code,
      setup: (t, vm) async {
        await _toCode(vm);
        await t.pump();
        await t.enterText(find.byKey(const ValueKey('phone-code')), '123456');
        await t.pump();
        await t.tap(find.byKey(const ValueKey('phone-code-next')));
      },
    ),
  );
  Future<void> toPhoneRow(WidgetTester t) async {
    await t.pumpAndSettle();
    await t.drag(
      find.byKey(const ValueKey('profile-editor-scroll')),
      const Offset(0, -150),
    );
  }

  testWidgets(
    'profile empty',
    (t) => shoot(
      t,
      'profile_empty',
      const EditProfileScreen(),
      setup: (t, vm) => toPhoneRow(t),
    ),
  );
  testWidgets(
    'profile verified',
    (t) => shoot(
      t,
      'profile_verified',
      const EditProfileScreen(),
      setup: (t, vm) async {
        await _toCode(vm);
        vm.editCode('123456');
        await vm.verify();
        await toPhoneRow(t);
      },
    ),
  );

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      final tag = '${width.toInt()}_text${scale.toInt()}';
      testWidgets(
        'number $tag',
        (t) => shoot(
          t,
          'number_$tag',
          number,
          width: width,
          height: 760,
          scale: scale,
          padding: EdgeInsets.zero,
          setup: (t, vm) => _number(vm, ''),
        ),
      );
      testWidgets(
        'code $tag',
        (t) => shoot(
          t,
          'code_$tag',
          code,
          width: width,
          height: 760,
          scale: scale,
          padding: EdgeInsets.zero,
          setup: (t, vm) => _toCode(vm),
        ),
      );
      testWidgets(
        'country $tag',
        (t) => shoot(
          t,
          'country_$tag',
          const PhoneCountryScreen(),
          width: width,
          height: 760,
          scale: scale,
          padding: EdgeInsets.zero,
        ),
      );
    }
  }
}
