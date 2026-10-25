import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/core/design/reference_widgets.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/appearance/application/appearance_controller.dart';
import 'package:cocenglish/features/appearance/data/appearance_repository.dart';
import 'package:cocenglish/features/appearance/domain/appearance_preference.dart';
import 'package:cocenglish/features/billing/application/billing_controller.dart';
import 'package:cocenglish/features/billing/domain/billing_models.dart';
import 'package:cocenglish/features/learning/presentation/learning_path.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/features/quests/domain/upgrade_chest.dart';
import 'package:cocenglish/features/quests/presentation/upgrade_chest_screen.dart';
import 'package:cocenglish/features/shell/presentation/app_bottom_nav.dart';
import 'package:cocenglish/features/super_features/presentation/super_features_screen.dart';
import 'package:cocenglish/features/super_trial/presentation/android_super_flow.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

class _Appearance implements AppearanceRepository {
  AppearancePreference value = AppearancePreference.system;
  @override
  Future<AppearancePreference> load() async => value;
  @override
  Future<void> save(AppearancePreference preference) async {
    value = preference;
  }
}

class _Active extends BillingController {
  @override
  BillingState build() => BillingState(
    loaded: true,
    snapshot: BillingSnapshot(
      selection: 'individual',
      activeUntil: DateTime.utc(2099),
    ),
  );
}

class _App extends ConsumerWidget {
  const _App(this.router);
  final GoRouter router;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: referenceTheme(),
    darkTheme: referenceTheme(brightness: Brightness.dark),
    themeMode: ref.watch(appearanceControllerProvider).themeMode,
    routerConfig: router,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android non-payment source flows, dark dialog, chest animation and Super',
    (t) async {
      await binding.convertFlutterSurfaceToImage();
      final appearance = _Appearance();
      final container = ProviderContainer(
        overrides: [
          appearanceRepositoryProvider.overrideWithValue(appearance),
          snapshotStoreProvider.overrideWithValue(MemorySnapshotStore()),
          billingControllerProvider.overrideWith(_Active.new),
        ],
      );
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const PreferencesScreen(),
          ),
          GoRoute(path: '/super', builder: (_, _) => const AndroidSuperFlow()),
          GoRoute(
            path: '/super/tour',
            builder: (_, _) => const AndroidSuperWelcome(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) =>
                const Scaffold(body: Text('Acceptance destination')),
          ),
          GoRoute(
            path: '/chest',
            builder: (_, _) => const UpgradeChestScreen(
              reward: UpgradeChestReward(
                receiptId: 'server-fixture',
                tiers: [
                  ChestRarity.common,
                  ChestRarity.rare,
                  ChestRarity.rare,
                  ChestRarity.epic,
                ],
                gems: 20,
              ),
            ),
          ),
          GoRoute(
            path: '/mega',
            builder: (_, _) => const UpgradeChestScreen(
              reward: UpgradeChestReward(
                receiptId: 'mega-fixture',
                tiers: [
                  ChestRarity.common,
                  ChestRarity.rare,
                  ChestRarity.epic,
                  ChestRarity.mega,
                ],
                gems: 40,
              ),
            ),
          ),
        ],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: container, child: _App(router)),
      );
      await t.pumpAndSettle();
      await ReferenceArt.preloadFiles([
        'android-super-02',
        'android-super-08',
        'android-super-09',
        'android-super-10',
        'android-chest-common',
        'chest-rare-source',
        'chest-epic-source',
        'chest-reward-source',
      ]);
      await binding.takeScreenshot('android-completion-settings-light');
      await t.tap(find.byKey(const ValueKey('dark-mode-setting')));
      await t.pumpAndSettle();
      await binding.takeScreenshot('android-completion-dark-dialog');
      await t.tap(find.byKey(const ValueKey('dark-mode-dark')));
      await t.pumpAndSettle();
      expect(appearance.value, AppearancePreference.dark);
      expect(
        Theme.of(t.element(find.byType(PreferencesScreen))).brightness,
        Brightness.dark,
      );
      await binding.takeScreenshot('android-completion-settings-dark');

      router.go('/chest');
      await t.pumpAndSettle();
      await binding.takeScreenshot('android-completion-chest-common');
      await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
      await t.pump(const Duration(milliseconds: 110));
      await binding.takeScreenshot('android-completion-chest-motion');
      await t.pumpAndSettle();
      expect(find.text('RARE'), findsOneWidget);
      await binding.takeScreenshot('android-completion-chest-rare');
      await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
      await t.pumpAndSettle();
      expect(find.text('EPIC'), findsOneWidget);
      await binding.takeScreenshot('android-completion-chest-epic');
      await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
      await t.pumpAndSettle();
      expect(find.text('+20 gems'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
      expect(
        t
            .widget<ReferenceButton>(
              find.widgetWithText(ReferenceButton, 'CONTINUE'),
            )
            .onPressed,
        isNotNull,
      );
      await binding.takeScreenshot('android-completion-chest-reward');
      router.go('/mega');
      await t.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byKey(const ValueKey('upgrade-chest-tap')));
        await t.pumpAndSettle();
      }
      expect(find.text('MEGA'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
      await binding.takeScreenshot('android-completion-chest-mega');

      router.go('/super');
      await t.pumpAndSettle();
      await binding.takeScreenshot('android-completion-super-comparison');
      await t.tap(find.byKey(const ValueKey('android-super-next')));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 500));
      await t.pump();
      await binding.takeScreenshot('android-completion-super-reminder');
      await t.tap(find.byKey(const ValueKey('android-super-next')));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 500));
      await t.pump();
      await binding.takeScreenshot('android-completion-super-plans');
      await t.scrollUntilVisible(
        find.text('VIEW ALL PLANS'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('VIEW ALL PLANS'));
      await t.pumpAndSettle();
      await binding.takeScreenshot('android-completion-super-all-plans');
      await t.ensureVisible(find.text('GO BACK'));
      await t.tap(find.text('GO BACK'));
      await t.pumpAndSettle();

      // Direct verified-entitlement fixture; checkout/store billing is excluded.
      router.go('/super/tour');
      await t.pumpAndSettle();
      expect(find.text('Super is ready!'), findsOneWidget);
      await binding.takeScreenshot('android-completion-super-confirmed');
      await t.tap(find.text('NEXT'));
      await t.pumpAndSettle();
      await binding.takeScreenshot('android-completion-super-welcome');
      await t.tap(find.text('CONTINUE'));
      await t.pump(const Duration(milliseconds: 100));
      await binding.takeScreenshot('android-completion-super-brand');
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(find.text('Acceptance destination'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
    },
  );
  testWidgets('real Android dark home and paid coachmark destination', (
    t,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    final appearance = _Appearance()..value = AppearancePreference.dark;
    final container = ProviderContainer(
      overrides: [
        appearanceRepositoryProvider.overrideWithValue(appearance),
        snapshotStoreProvider.overrideWithValue(MemorySnapshotStore()),
        billingControllerProvider.overrideWith(_Active.new),
      ],
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'English',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await ReferenceArt.preloadFiles(
      t
          .widgetList<ReferenceArt>(find.byType(ReferenceArt))
          .map((a) => a.region.file)
          .toSet(),
    );
    await t.pumpAndSettle();
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(
      Theme.of(t.element(find.byType(AppBottomNav))).brightness,
      Brightness.dark,
    );
    await binding.takeScreenshot('android-completion-home-dark');
    final router = GoRouter.of(t.element(find.byType(LearningPath)));
    router.go('/home?superWelcome=1');
    await t.pumpAndSettle();
    expect(find.text('Super lives here now!'), findsOneWidget);
    await binding.takeScreenshot('android-completion-super-coachmark');
    await t.tap(find.byTooltip('Super features'));
    await t.pumpAndSettle();
    expect(find.byType(SuperFeaturesScreen), findsOneWidget);
    expect(
      GoRouterState.of(t.element(find.byType(SuperFeaturesScreen))).uri.path,
      SuperFeaturesScreen.route,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    container.dispose();
  });
}
