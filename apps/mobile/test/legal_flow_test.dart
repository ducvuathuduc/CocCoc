import 'package:cocenglish/features/legal/data/legal_repository.dart';
import 'package:cocenglish/features/legal/domain/legal_models.dart';
import 'package:cocenglish/features/legal/presentation/legal_document_screen.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<GoRouter> boot(WidgetTester t) async {
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
    return GoRouter.of(t.element(find.byTooltip('Practice')));
  }

  Future<void> tapLink(WidgetTester t, String text) async {
    final target = find.text(text);
    await t.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  const cases = {
    'TERMS': ('Terms', LegalDocumentKind.terms, '1. About COC English'),
    'PRIVACY POLICY': (
      'Privacy Policy',
      LegalDocumentKind.privacy,
      'Information we collect',
    ),
    'ACKNOWLEDGEMENTS': (
      'Acknowledgements',
      LegalDocumentKind.acknowledgements,
      'flutter_riverpod',
    ),
  };

  for (final e in cases.entries) {
    testWidgets('Settings ${e.key} opens its reader and closes back', (
      t,
    ) async {
      final router = await boot(t);
      router.push('/settings');
      await t.pumpAndSettle();
      await tapLink(t, e.key);
      final screen = t.widget<LegalDocumentScreen>(
        find.byType(LegalDocumentScreen),
      );
      expect(screen.kind, e.value.$2);
      expect(find.text(e.value.$1), findsOneWidget);
      expect(find.text(e.value.$3), findsOneWidget);
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
      expect(find.byType(LegalDocumentScreen), findsNothing);
      expect(find.text(e.key), findsOneWidget);
    });
  }

  testWidgets('direct routes resolve to the right documents', (t) async {
    final router = await boot(t);
    for (final p in ['terms', 'privacy', 'acknowledgements']) {
      router.go('/settings/legal/$p');
      await t.pumpAndSettle();
      expect(
        t.widget<LegalDocumentScreen>(find.byType(LegalDocumentScreen)).kind,
        LegalDocumentKind.values.byName(p),
      );
    }
  });

  testWidgets('acknowledgements scrolls and opens the full license page', (
    t,
  ) async {
    final router = await boot(t);
    router.push('/settings/legal/acknowledgements');
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('VIEW ALL LICENSES'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('shared_preferences'), findsOneWidget);
    await t.tap(find.text('VIEW ALL LICENSES'));
    await t.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  test('acknowledgements list every pubspec dependency', () {
    const repo = MockLegalRepository();
    final names = repo.packages().map((p) => p.name).toSet();
    for (final dep in [
      'appwrite',
      'cupertino_icons',
      'flutter_riverpod',
      'flutter_svg',
      'go_router',
      'lottie',
      'qr_flutter',
      'rive',
      'shared_preferences',
    ]) {
      expect(names, contains(dep));
    }
    final ack = repo.document(LegalDocumentKind.acknowledgements);
    expect(ack.sections.length, repo.packages().length);
  });
}
