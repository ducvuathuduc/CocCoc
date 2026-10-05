import 'package:cocenglish/main.dart';
import 'package:cocenglish/features/onboarding/data/onboarding_repository.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Android onboarding taps, disk persistence and restart', (
    tester,
  ) async {
    final repository = PreferencesOnboardingRepository(
      SharedPreferencesAsync(),
      storageKey: 'onboarding.integration.v1',
    );
    await repository.save(OnboardingState());
    await tester.pumpWidget(AppBootstrap(repository: repository));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    Future<void> tap(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await binding.takeScreenshot('android-welcome');
    await tap('GET STARTED');
    await tap('CONTINUE');
    await tap('CONTINUE');
    await tap('French');
    await binding.takeScreenshot('android-language');
    await tap('CONTINUE');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tap('I know some common words');
    await tap('CONTINUE');
    await tap('Just for fun');
    await tap('Spend time productively');
    await tap('CONTINUE');
    await tap('CONTINUE');
    await binding.takeScreenshot('android-goal');
    await tap('I’M COMMITTED');
    await tap('CONTINUE');
    await tap('REMIND ME TO PRACTICE');
    await tap('Not now');
    await tap('NOT NOW');
    await binding.takeScreenshot('android-benefits');
    await tap('CONTINUE');
    await tap('Learn for free');
    await tap('CONTINUE');
    await tap('CONTINUE');
    await binding.takeScreenshot('android-level');
    await tap('CONTINUE');
    expect(find.text('Use basic phrases'), findsOneWidget);
    final saved = await repository.load();
    expect(saved.step, OnboardingStep.lessonEntry);
    expect(saved.language, 'French');
    expect(saved.goal, 10);
    expect(saved.reasonIds, {0, 2});
    expect(saved.reminders, false);
    expect(saved.widgetRequested, false);
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.pumpWidget(AppBootstrap(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Use basic phrases'), findsOneWidget);
    expect(find.byTooltip('Start lesson 1'), findsOneWidget);
  });
  testWidgets('native Android mock login, recovery, saved account and Back', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    Future<void> tap(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
    }

    await tap('I ALREADY HAVE AN ACCOUNT');
    await binding.takeScreenshot('android-login-choice');
    await tap('SIGN IN');
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'SIGN IN'))
          .onPressed,
      isNull,
    );
    await binding.takeScreenshot('android-login-details');
    await tester.enterText(find.byType(TextField).first, 'learner@example.com');
    await tester.enterText(
      find.byType(TextField).last,
      'fixture-password-only',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show Password'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Hide Password'));
    await tester.pumpAndSettle();
    await tap('SIGN IN');
    expect(
      find.text(
        'We couldn’t sign you in. Check your email and password and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('learner@example.com'), findsOneWidget);
    await binding.takeScreenshot('android-login-error');
    await tap('FORGOT PASSWORD');
    expect(find.text('learner@example.com'), findsOneWidget);
    await tap('NEXT');
    expect(find.text('Check your email!'), findsOneWidget);
    await binding.takeScreenshot('android-login-recovery-sheet');
    await tap('OKAY');
    expect(find.text('Reset your password'), findsOneWidget);
    await binding.takeScreenshot('android-login-reset');
    await tester.enterText(find.byType(TextField).first, 'changed-password-12');
    await tester.enterText(find.byType(TextField).last, 'changed-password-12');
    await tester.pumpAndSettle();
    await tap('RESET PASSWORD');
    expect(find.text('Success!'), findsOneWidget);
    await binding.takeScreenshot('android-login-reset-success');
    await tap('CONTINUE');
    expect(find.text('Enter your details'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'changed-password-12');
    await tester.pumpAndSettle();
    await tap('SIGN IN');
    expect(find.text('Welcome back!'), findsOneWidget);
    await binding.takeScreenshot('android-login-success');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Sign back in'), findsOneWidget);
    await binding.takeScreenshot('android-login-saved');
    await tap('Add another account');
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      isEmpty,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Learn for free. Forever.'), findsOneWidget);
  });
}
