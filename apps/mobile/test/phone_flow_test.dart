import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/phone/application/phone_verification_controller.dart';
import 'package:cocenglish/features/phone/data/phone_verification_repository.dart';
import 'package:cocenglish/features/phone/domain/phone_models.dart';
import 'package:cocenglish/features/phone/presentation/phone_verification_screens.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('MockPhoneVerificationRepository', () {
    final repo = MockPhoneVerificationRepository();
    final us = repo.defaultCountry;
    test('validates NANP numbers like Duolingo refs', () {
      expect(repo.validate(us, '6502137552'), isNull);
      expect(repo.validate(us, '6532137379'), 'Enter a valid phone number');
      expect(repo.validate(us, '12345'), isNotNull);
      final vn = repo.countries().firstWhere((c) => c.iso == 'VN');
      expect(repo.validate(vn, '912345678'), isNull);
    });
    test(
      'code 123456 verifies, others fail; unreachable number throws',
      () async {
        final n = PhoneNumber(us, '6502137552');
        expect(await repo.verifyCode(n, '123456'), isTrue);
        expect(await repo.verifyCode(n, '725719'), isFalse);
        expect(
          repo.sendCode(PhoneNumber(us, '6502137379')),
          throwsA(isA<PhoneVerificationFailure>()),
        );
      },
    );
    test('masks like the Profile ref', () {
      expect(PhoneNumber(us, '6502137552').masked, '(XXX) XXX-7552');
    });
  });

  group('PhoneVerificationController', () {
    test('country search filters by name and dial code', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final vm = c.read(phoneVerificationControllerProvider.notifier);
      expect(vm.countries().first.name, 'United States');
      expect(vm.countries('viet').single.iso, 'VN');
      expect(vm.countries('+84').map((e) => e.iso), contains('VN'));
      expect(vm.countries('zzzz'), isEmpty);
      final vn = vm.countries('viet').single;
      vm.selectCountry(vn);
      expect(c.read(phoneVerificationControllerProvider).country, vn);
      expect(vm.countries().first, vn);
    });
  });

  Widget harness({List<Override> overrides = const []}) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () {
                  ref
                      .read(phoneVerificationControllerProvider.notifier)
                      .begin();
                  context.push(phoneRoute);
                },
                child: Text(
                  ref
                          .watch(phoneVerificationControllerProvider)
                          .verified
                          ?.masked ??
                      'OPEN',
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: phoneRoute,
          builder: (context, state) =>
              const PhoneNumberScreen(autofocus: false),
        ),
        GoRoute(
          path: phoneCountryRoute,
          builder: (context, state) => const PhoneCountryScreen(),
        ),
        GoRoute(
          path: phoneCodeRoute,
          builder: (context, state) => const PhoneCodeScreen(autofocus: false),
        ),
      ],
    );
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: referenceTheme(), routerConfig: router),
    );
  }

  Future<void> tapText(WidgetTester t, String text) async {
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  testWidgets('number entry: NEXT disabled until typed, invalid error clears', (
    t,
  ) async {
    await t.pumpWidget(harness());
    await tapText(t, 'OPEN');
    expect(find.text('What’s your phone number?'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('phone-next')));
    await t.pumpAndSettle();
    expect(find.text('Enter the 6-digit code'), findsNothing);
    await t.enterText(find.byKey(const ValueKey('phone-number')), '6532137379');
    await t.pump();
    await tapText(t, 'NEXT');
    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('phone-number')), '6502137552');
    await t.pump();
    expect(find.text('Enter a valid phone number'), findsNothing);
  });

  testWidgets('server failure shows the unknown error alert', (t) async {
    await t.pumpWidget(harness());
    await tapText(t, 'OPEN');
    await t.enterText(find.byKey(const ValueKey('phone-number')), '6502137379');
    await t.pump();
    await tapText(t, 'NEXT');
    expect(
      find.text('An unknown error occurred. Please try again later.'),
      findsOneWidget,
    );
    await tapText(t, 'OK');
    expect(find.byKey(const ValueKey('phone-server-error')), findsNothing);
    expect(find.text('What’s your phone number?'), findsOneWidget);
  });

  testWidgets('country picker: search, pick, code updates', (t) async {
    await t.pumpWidget(harness());
    await tapText(t, 'OPEN');
    await t.tap(find.byKey(const ValueKey('phone-country')));
    await t.pumpAndSettle();
    expect(find.text('Country/Region'), findsOneWidget);
    expect(find.text('Afghanistan'), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('phone-country-search')),
      'zzz',
    );
    await t.pump();
    expect(find.text('No countries found'), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('phone-country-search')),
      'viet',
    );
    await t.pump();
    expect(find.text('Afghanistan'), findsNothing);
    await t.tap(find.byKey(const ValueKey('phone-country-VN')));
    await t.pumpAndSettle();
    expect(find.text('What’s your phone number?'), findsOneWidget);
    expect(find.text('+84'), findsOneWidget);
  });

  testWidgets(
    'code: wrong code error, resend countdown, 123456 success returns',
    (t) async {
      final repo = MockPhoneVerificationRepository();
      await t.pumpWidget(
        harness(
          overrides: [
            phoneVerificationRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      await tapText(t, 'OPEN');
      await t.enterText(
        find.byKey(const ValueKey('phone-number')),
        '6502137552',
      );
      await t.pump();
      await tapText(t, 'NEXT');
      expect(find.text('Enter the 6-digit code'), findsOneWidget);
      expect(
        find.text('We sent a code to +16502137552 to verify your phone number'),
        findsOneWidget,
      );
      expect(repo.sent, ['+16502137552']);

      await t.enterText(find.byKey(const ValueKey('phone-code')), '725719');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('phone-code-next')));
      await t.pumpAndSettle();
      expect(find.text('That code is incorrect. Try again.'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('phone-code')), '72571');
      await t.pump();
      expect(find.text('That code is incorrect. Try again.'), findsNothing);

      await tapText(t, 'DIDN’T RECEIVE THE CODE?');
      expect(repo.sent.length, 2);
      expect(find.text('RESEND CODE IN 0:30'), findsOneWidget);
      expect(find.text('We sent a new code to +16502137552.'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(find.text('RESEND CODE IN 0:29'), findsOneWidget);
      // Disabled while counting down.
      await t.tap(find.byKey(const ValueKey('phone-resend')));
      await t.pump();
      expect(repo.sent.length, 2);
      await t.pump(const Duration(seconds: 29));
      expect(find.text('DIDN’T RECEIVE THE CODE?'), findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('phone-code')), '123456');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('phone-code-next')));
      await t.pumpAndSettle();
      expect(find.text('Phone number verified'), findsOneWidget);
      await tapText(t, 'CONTINUE');
      expect(find.text('(XXX) XXX-7552'), findsOneWidget);
    },
  );

  testWidgets('Settings > Profile phone row opens the flow in the real app', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MainApp(
        initial: OnboardingState(
          step: OnboardingStep.lessonEntry,
          language: 'English',
        ),
      ),
    );
    await t.pumpAndSettle();
    final router = GoRouter.of(t.element(find.byTooltip('Practice')));
    router.push('/settings/profile');
    await t.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('profile-phone')));
    expect(find.text('Add phone number'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('profile-phone')));
    await t.pumpAndSettle();
    expect(find.byType(PhoneNumberScreen), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('phone-number')), '6502137552');
    await t.pump();
    await tapText(t, 'NEXT');
    expect(find.byType(PhoneCodeScreen), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('phone-code')), '123456');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('phone-code-next')));
    await t.pumpAndSettle();
    await tapText(t, 'CONTINUE');
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('(XXX) XXX-7552'), findsOneWidget);
    final c = ProviderScope.containerOf(
      t.element(find.byType(EditProfileScreen)),
    );
    expect(
      c.read(phoneVerificationControllerProvider).verified?.e164,
      '+16502137552',
    );
  });
}
