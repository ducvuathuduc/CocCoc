import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/appearance/application/appearance_controller.dart';
import 'package:cocenglish/features/appearance/data/appearance_repository.dart';
import 'package:cocenglish/features/appearance/domain/appearance_preference.dart';
import 'package:cocenglish/features/appearance/presentation/dark_mode_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements AppearanceRepository {
  _Store({this.failSave = false});
  final bool failSave;
  AppearancePreference value = AppearancePreference.system;
  @override
  Future<AppearancePreference> load() async => value;
  @override
  Future<void> save(AppearancePreference preference) async {
    if (failSave) throw StateError('disk full');
    value = preference;
  }
}

void main() {
  testWidgets(
    'dialog offers source choices and persists dark mode at text scale 2',
    (tester) async {
      final store = _Store();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appearanceRepositoryProvider.overrideWithValue(store)],
          child: MaterialApp(
            theme: referenceTheme(),
            darkTheme: referenceTheme(brightness: Brightness.dark),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(body: DarkModeSetting()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dark-mode-setting')));
      await tester.pumpAndSettle();

      expect(find.text('System Default'), findsWidgets);
      expect(find.text('On'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      final title = tester.widget<Text>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Dark mode'),
        ),
      );
      expect(title.style?.color, ReferencePalette.light.ink);

      await tester.tap(find.text('On'));
      await tester.pumpAndSettle();
      expect(store.value, AppearancePreference.dark);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dark theme exposes sampled source palette to common surfaces', (
    tester,
  ) async {
    late ReferencePalette palette;
    await tester.pumpWidget(
      MaterialApp(
        theme: referenceTheme(brightness: Brightness.dark),
        home: Builder(
          builder: (context) {
            palette = context.referencePalette;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    expect(palette.surface, const Color(0xFF172021));
    expect(palette.raisedSurface, const Color(0xFF233034));
    expect(palette.border, const Color(0xFF3A464E));
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('dark dialog title uses the dark foreground palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appearanceRepositoryProvider.overrideWithValue(_Store())],
        child: MaterialApp(
          theme: referenceTheme(brightness: Brightness.dark),
          home: const Scaffold(body: DarkModeSetting()),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dark-mode-setting')));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Dark mode'),
      ),
    );
    expect(title.style?.color, ReferencePalette.dark.ink);
  });

  testWidgets('save failure keeps dialog open and shows an actionable error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceRepositoryProvider.overrideWithValue(
            _Store(failSave: true),
          ),
        ],
        child: MaterialApp(
          theme: referenceTheme(),
          home: const Scaffold(body: DarkModeSetting()),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dark-mode-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Couldn’t save this setting. Try again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
