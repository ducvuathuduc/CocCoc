import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/application/profile_appearance_provider.dart';
import 'package:cocenglish/features/progress/presentation/profile_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cocenglish/features/account/application/avatar_controller.dart';
import 'package:cocenglish/features/account/data/avatar_assets.dart';
import 'package:cocenglish/features/account/application/profile_editor_controller.dart';
import 'package:cocenglish/features/account/presentation/avatar_motion.dart';

void main() {
  testWidgets(
    'own profile QR uses saved avatar; foreign QR uses authored owner avatar',
    (t) async {
      final c = ProviderContainer();
      final catalog = await t.runAsync(
        () => c.read(avatarCatalogProvider.future),
      );
      final originalCatalog = catalog!;
      final vm = c.read(avatarControllerProvider.notifier)
        ..attachCatalog(originalCatalog);
      vm.begin();
      vm.select('Body', 3);
      vm.save();
      expect(
        c
            .read(profileEditorProvider.notifier)
            .save(
              const ProfileDetails(
                first: 'Sam',
                last: 'Lee',
                username: 'sam.english',
                email: 'sam@example.test',
              ),
            ),
        isNull,
      );
      Widget share(String id) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: referenceTheme(),
          home: ProfileShareDialog(userId: id, name: 'Sam Lee'),
        ),
      );
      await t.pumpWidget(share('me'));
      expect(find.text('@sam.english'), findsOneWidget);
      final avatar = t.widget<AvatarMotion>(find.byType(AvatarMotion));
      final learnerAvatar = c.read(avatarControllerProvider).saved;
      expect(avatar.values, learnerAvatar);
      expect(avatar.animate, isFalse);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pump();
      await t.pumpWidget(share('Alex'));
      final foreignAvatar = t.widget<AvatarMotion>(find.byType(AvatarMotion));
      final foreignAppearance = c
          .read(profileAppearanceProvider('Alex'))!
          .valuesFor(originalCatalog);
      expect(foreignAvatar.values, foreignAppearance);
      expect(foreignAvatar.values, isNot(equals(learnerAvatar)));
      expect(foreignAvatar.animate, isFalse);
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'QR data and copied link match; copy preserves dialog and can retry',
    (t) async {
      final urls = <String>[];
      var fail = true;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            profileClipboardWriterProvider.overrideWithValue((url) async {
              urls.add(url);
              if (fail) throw StateError('unavailable');
            }),
          ],
          child: MaterialApp(
            theme: referenceTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showProfileShare(
                    context,
                    userId: 'Sam Lee',
                    name: 'Sam Lee',
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('OPEN'));
      await t.pumpAndSettle();
      final qr = t.widget<QrImageView>(find.byType(QrImageView));
      expect(
        qr.semanticsLabel,
        'Profile QR code: ${profilePreviewUrl('Sam Lee')}',
      );
      await t.ensureVisible(find.byTooltip('Copy link'));
      await t.tap(find.byTooltip('Copy link'));
      await t.pumpAndSettle();
      expect(find.text('Could not copy. Try again.'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      fail = false;
      await t.tap(find.byTooltip('Copy link'));
      await t.pumpAndSettle();
      expect(find.text('Profile link copied'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(urls, [
        profilePreviewUrl('Sam Lee'),
        profilePreviewUrl('Sam Lee'),
      ]);
      await t.ensureVisible(find.byTooltip('Close profile link'));
      await t.tap(find.byTooltip('Close profile link'));
      await t.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      await t.tap(find.text('OPEN'));
      await t.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Profile link copied'), findsNothing);
      expect(find.text('Could not copy. Try again.'), findsNothing);
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'profile share controls width$width text$scale remain usable',
        (t) async {
          await t.binding.setSurfaceSize(Size(width, 844));
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
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showProfileShare(
                        context,
                        userId: 'Alex',
                        name: 'Alex',
                      ),
                      child: const Text('OPEN'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.tap(find.text('OPEN'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await t.ensureVisible(find.byTooltip('Share link'));
          await t.tap(find.byTooltip('Share link'));
          await t.pumpAndSettle();
          expect(find.text('Share profile'), findsOneWidget);
          expect(find.text(profilePreviewUrl('Alex')), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
