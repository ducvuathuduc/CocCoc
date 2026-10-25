import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/auth/application/auth_controller.dart';
import 'package:cocenglish/features/auth/presentation/auth_widgets.dart';
import 'package:cocenglish/features/auth/presentation/login_flow.dart';
import 'package:cocenglish/features/legal/domain/legal_models.dart';
import 'package:cocenglish/features/legal/presentation/legal_document_screen.dart';
import 'package:cocenglish/features/session/application/real_learning_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final kind in [LegalDocumentKind.terms, LegalDocumentKind.privacy]) {
    final label = kind == LegalDocumentKind.terms ? 'Terms' : 'Privacy Policy';
    test(
      'signed-out API user may read $label without opening private routes',
      () {
        expect(
          realLearningRedirect(
            path: '/settings/legal/${kind.name}',
            api: true,
            restoring: false,
            signedIn: false,
            ready: false,
          ),
          isNull,
        );
        expect(
          realLearningRedirect(
            path: '/settings',
            api: true,
            restoring: false,
            signedIn: false,
            ready: false,
          ),
          '/login',
        );
      },
    );

    testWidgets('login $label opens reader and returns to preserved draft', (
      t,
    ) async {
      t.view.physicalSize = const Size(430, 932);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authControllerProvider.notifier).showDetails();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                LoginFlow(initialize: false, onExit: () {}, onStart: () {}),
          ),
          GoRoute(
            path: '/settings/legal/${kind.name}',
            builder: (_, _) => LegalDocumentScreen(kind: kind),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: referenceTheme(),
            routerConfig: router,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'learner@example.test');
      await t.enterText(find.byType(TextField).at(1), 'preserved draft');
      t.testTextInput.hide();
      await t.pumpAndSettle();
      final footer = find.descendant(
        of: find.byType(AuthLegalFooter),
        matching: find.byType(RichText),
      );
      await t.ensureVisible(footer);
      final paragraph = t.renderObject<RenderParagraph>(footer);
      final text = paragraph.text.toPlainText();
      final start = text.indexOf(label);
      expect(start, greaterThanOrEqualTo(0));
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: start,
              extentOffset: start + label.length,
            ),
          )
          .first;
      await t.tapAt(paragraph.localToGlobal(box.toRect().center));
      await t.pumpAndSettle();
      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
      expect(find.byType(LoginFlow), findsOneWidget);
      expect(find.text('learner@example.test'), findsOneWidget);
      expect(find.text('preserved draft'), findsOneWidget);
    });
  }
}
