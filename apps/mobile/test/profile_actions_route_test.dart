import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/progress/application/profile_actions_controller.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> profile(WidgetTester t, String id) async {
  await t.pumpWidget(
    MainApp(
      initial: OnboardingState(
        step: OnboardingStep.lessonEntry,
        language: 'English',
      ),
    ),
  );
  await t.pumpAndSettle();
  final context = t.element(find.byTooltip('Practice'));
  final container = ProviderScope.containerOf(context);
  GoRouter.of(context).push('/profile/$id');
  await t.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('unknown profile is unavailable and cannot mutate social state', (
    t,
  ) async {
    final c = await profile(t, 'sample-0');
    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(find.byTooltip('Profile options'), findsNothing);
    expect(find.text('FOLLOW'), findsNothing);
    expect(c.read(previewControllerProvider).following, isEmpty);
    expect(c.read(profileActionsProvider).blocked, isEmpty);
  });
  testWidgets(
    'League profile uses the same identity for block, report and following',
    (t) async {
      await t.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      );
      await t.pumpAndSettle();
      ProviderScope.containerOf(t.element(find.byTooltip('Practice')))
          .read(previewControllerProvider.notifier)
          .optIntoLeague();
      await t.tap(find.byTooltip('League'));
      await t.pumpAndSettle();
      await t.tap(find.text('Alex'));
      await t.pumpAndSettle();
      final c = ProviderScope.containerOf(
        t.element(find.byTooltip('Profile options')),
      );
      await t.tap(find.text('FOLLOW'));
      await t.pumpAndSettle();
      expect(c.read(previewControllerProvider).following, contains('Alex'));
      await t.tap(find.byTooltip('Profile options'));
      await t.pumpAndSettle();
      await t.tap(find.text('Block user'));
      await t.pumpAndSettle();
      await t.tap(find.text('BLOCK'));
      await t.pumpAndSettle();
      expect(find.text('UNBLOCK USER'), findsOneWidget);
      expect(c.read(profileActionsProvider).blocked, contains('Alex'));
      expect(
        c.read(previewControllerProvider).following,
        isNot(contains('Alex')),
      );
    },
  );
  testWidgets(
    'report cancellation retains following; confirm blocks once and unblock does not refollow',
    (t) async {
      final c = await profile(t, 'Alex');
      c.read(previewControllerProvider.notifier).follow('Alex');
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Profile options'));
      await t.pumpAndSettle();
      await t.tap(find.text('Report user'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(c.read(profileActionsProvider).reports, isEmpty);
      expect(c.read(previewControllerProvider).following, contains('Alex'));
      await t.tap(find.byTooltip('Profile options'));
      await t.pumpAndSettle();
      await t.tap(find.text('Report user'));
      await t.pumpAndSettle();
      await t.tap(find.text('Spam'));
      await t.pumpAndSettle();
      await t.tap(find.text('REPORT'));
      await t.pumpAndSettle();
      expect(c.read(profileActionsProvider).reports, {'Alex': 'Spam'});
      expect(find.text('UNBLOCK USER'), findsOneWidget);
      await t.tap(find.text('UNBLOCK USER'));
      await t.pumpAndSettle();
      expect(c.read(profileActionsProvider).blocked, isEmpty);
      expect(
        c.read(previewControllerProvider).following,
        isNot(contains('Alex')),
      );
    },
  );
  testWidgets(
    'own profile link copies actual local URL then closes back to profile',
    (t) async {
      final urls = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            urls.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await profile(t, 'me');
      await t.tap(find.byTooltip('Profile link'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Copy link'));
      await t.pumpAndSettle();
      expect(urls, [profilePreviewUrl('me')]);
      await t.tap(find.byTooltip('Close profile link'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Settings'), findsOneWidget);
    },
  );
}
