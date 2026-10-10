import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/profile/application/profile_controller.dart';
import 'package:cocenglish/features/profile/presentation/profile_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _pumpPage() => ProviderScope(
  child: MaterialApp(theme: referenceTheme(), home: const ProfileTabPage()),
);

void main() {
  testWidgets('page shows new-user fixture then switches to rich', (
    tester,
  ) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: referenceTheme(),
          home: Builder(
            builder: (context) => Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const ProfileTabPage();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('@SAMLEE782112 · JOINED 2025'), findsOneWidget);
    expect(find.text('Finish your profile!'), findsOneWidget);
    expect(find.text('MAX FAMILY'), findsNothing);

    captured
        .read(profileTabControllerProvider.notifier)
        .select(ProfileVariant.rich);
    await tester.pumpAndSettle();

    expect(find.text('@SLMOBBIN · JOINED 2025'), findsOneWidget);
    expect(find.text('Finish your profile!'), findsNothing);
    expect(find.text('MAX FAMILY'), findsOneWidget);
    expect(find.text('MANAGE'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page pump helper renders without exceptions', (tester) async {
    await tester.pumpWidget(_pumpPage());
    await tester.pumpAndSettle();
    expect(find.text('ADD FRIENDS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
