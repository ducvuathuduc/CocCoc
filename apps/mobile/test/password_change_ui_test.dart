import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/application/password_change_controller.dart';
import 'package:cocenglish/features/account/presentation/password_change_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'save validates, retains input on failure and returns after retry',
    (t) async {
      var fail = true;
      var calls = 0;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            passwordChangeWriterProvider.overrideWithValue((_, _) async {
              calls++;
              if (fail) throw StateError('retry');
            }),
          ],
          child: MaterialApp(
            theme: referenceTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PasswordChangeScreen(),
                    ),
                  ),
                  child: const Text('EDITOR'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('EDITOR'));
      await t.pumpAndSettle();
      // Disabled fields do not submit when the visible footer is tapped.
      await t.tap(find.text('SAVE'));
      await t.pumpAndSettle();
      expect(calls, 0);
      await t.enterText(
        find.byKey(const ValueKey('password-old')),
        'duolingo-demo',
      );
      await t.enterText(
        find.byKey(const ValueKey('password-new')),
        'replacement-demo',
      );
      await t.enterText(
        find.byKey(const ValueKey('password-confirm')),
        'different-demo',
      );
      await t.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(calls, 0);
      await t.enterText(
        find.byKey(const ValueKey('password-confirm')),
        'replacement-demo',
      );
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Show new password'));
      await t.pump();
      expect(
        t
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('password-new')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isFalse,
      );
      expect(
        t
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('password-old')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isTrue,
      );
      await t.tap(find.text('SAVE'));
      await t.pumpAndSettle();
      expect(find.text('Could not save. Try again.'), findsOneWidget);
      expect(find.text('replacement-demo'), findsNWidgets(2));
      fail = false;
      await t.tap(find.text('SAVE'));
      await t.pumpAndSettle();
      expect(find.text('EDITOR'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expect(calls, 2);
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('password controls width$width text$scale remain reachable', (
        t,
      ) async {
        await t.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: referenceTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const PasswordChangeScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const ValueKey('password-confirm')));
        expect(find.byTooltip('Show confirm password'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
