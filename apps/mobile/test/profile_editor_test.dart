import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocenglish/features/account/application/profile_editor_controller.dart';

void main() {
  test('full name boundary rejects atomically with the canonical limit', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final before = c.read(profileEditorProvider);
    final error = c
        .read(profileEditorProvider.notifier)
        .save(
          ProfileDetails(
            first: 'A' * 40,
            last: 'B' * 40,
            username: 'valid.name',
            email: 'valid@example.test',
          ),
        );
    expect(error, 'Use a full name of up to 60 characters.');
    expect(c.read(profileEditorProvider), same(before));
    expect(c.read(previewControllerProvider).name, 'Sam');
  });
  test('profile save is atomic and rejects a phone with no digits', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vm = c.read(profileEditorProvider.notifier);
    expect(
      vm.save(
        const ProfileDetails(
          first: 'Alice',
          last: 'Nguyen',
          username: 'alice.nguyen',
          email: 'alice@example.test',
          phone: '------',
        ),
      ),
      isNotNull,
    );
    expect(c.read(previewControllerProvider).name, 'Sam');
    expect(
      vm.save(
        const ProfileDetails(
          first: 'Alice',
          last: 'Nguyen',
          username: 'alice.nguyen',
          email: 'alice@example.test',
          phone: '+84 912 345 678',
        ),
      ),
      isNull,
    );
    expect(c.read(previewControllerProvider).name, 'Alice Nguyen');
    expect(c.read(profileEditorProvider).username, 'alice.nguyen');
    expect(c.read(profileEditorProvider).phone, '+84 912 345 678');
  });
  testWidgets('full profile fields preserve draft on validation failure', (
    t,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: referenceTheme(),
          home: const EditProfileScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Last name'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('CHANGE AVATAR'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('profile-first')), 'Alice');
    final firstController = t
        .widget<TextField>(find.byKey(const ValueKey('profile-first')))
        .controller!;
    await t.enterText(find.byKey(const ValueKey('profile-last')), 'Nguyen');
    await t.ensureVisible(find.byKey(const ValueKey('profile-username')));
    await t.enterText(
      find.byKey(const ValueKey('profile-username')),
      'bad name!',
    );
    await t.ensureVisible(find.text('SAVE CHANGES'));
    await t.tap(find.text('SAVE CHANGES'));
    await t.pump();
    expect(c.read(previewControllerProvider).name, 'Sam');
    expect(find.textContaining('letters, numbers'), findsOneWidget);
    expect(firstController.text, 'Alice');
  });
}
