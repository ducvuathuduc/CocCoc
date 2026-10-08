import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/design/reference_theme.dart';
import 'features/onboarding/application/onboarding_controller.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/domain/onboarding_state.dart';
import 'features/learning/presentation/learning_path.dart';
import 'features/learning/presentation/sections_screen.dart';
import 'features/progress/presentation/energy_screen.dart';
import 'features/progress/presentation/super_screen.dart';
import 'features/progress/presentation/max_screen.dart';
import 'features/progress/presentation/timer_boost_screen.dart';
import 'features/progress/application/extended_controller.dart';
import 'features/learning/presentation/lesson_screen.dart';
import 'features/learning/presentation/explanation_screen.dart';
import 'features/learning/presentation/lesson_results.dart';
import 'features/learning/presentation/session_entry.dart';
import 'features/progress/presentation/hub_screens.dart';
import 'features/progress/presentation/learning_shell.dart';
import 'features/progress/presentation/streak_screen.dart';
import 'features/progress/presentation/streak_widgets_screen.dart';
import 'features/progress/presentation/year_review_screen.dart';
import 'features/progress/presentation/league_result_screen.dart';
import 'features/progress/presentation/family_subscription_screen.dart';
import 'features/progress/presentation/achievements_screen.dart';
import 'features/progress/presentation/social_screens.dart';
import 'features/account/presentation/account_screens.dart';
import 'features/account/presentation/course_management_screen.dart';
import 'features/account/presentation/password_change_screen.dart';
import 'features/practice/presentation/practice_screens.dart';
import 'features/practice/presentation/journey_screens.dart';
import 'features/practice/presentation/challenge_intro.dart';
import 'features/practice/presentation/adventure_screen.dart';
import 'features/practice/presentation/story_library.dart';
import 'features/practice/presentation/clash_screen.dart';
import 'features/onboarding/presentation/login_entry_screen.dart';
import 'features/onboarding/presentation/onboarding_flow.dart';
import 'features/onboarding/presentation/splash_screen.dart';
import 'features/account/presentation/avatar_builder_screen.dart';
import 'features/onboarding/presentation/welcome_screen.dart';
import 'features/progress/presentation/profile_lists_screen.dart';
import 'features/progress/application/profile_lists_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: ReferenceColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final repository = PreferencesOnboardingRepository(SharedPreferencesAsync());
  runApp(
    AppBootstrap(
      repository: repository,
      delay:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 500),
    ),
  );
}

final _bootstrapDelayProvider = Provider<Duration>((ref) => Duration.zero);
final _bootstrapProvider = FutureProvider<OnboardingState>((ref) async {
  final repository = ref.watch(onboardingRepositoryProvider);
  final delay = ref.watch(_bootstrapDelayProvider);
  final results = await Future.wait([
    repository.load(),
    Future<void>.delayed(delay),
  ]);
  return results.first as OnboardingState;
});

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({
    required this.repository,
    this.delay = Duration.zero,
    super.key,
  });
  final OnboardingRepository repository;
  final Duration delay;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      onboardingRepositoryProvider.overrideWithValue(repository),
      _bootstrapDelayProvider.overrideWithValue(delay),
    ],
    child: const _BootstrapView(),
  );
}

class _BootstrapView extends ConsumerWidget {
  const _BootstrapView();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_bootstrapProvider)
      .when(
        data: (initial) => MainApp(
          repository: ref.read(onboardingRepositoryProvider),
          initial: initial,
        ),
        loading: () => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: referenceTheme(),
          home: const SplashScreen(),
        ),
        error: (error, stack) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: referenceTheme(),
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Couldn’t load your choices.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => ref.invalidate(_bootstrapProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class MainApp extends StatelessWidget {
  const MainApp({this.repository, this.initial, super.key});
  final OnboardingRepository? repository;
  final OnboardingState? initial;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      onboardingControllerProvider.overrideWith(OnboardingController.new),
      persistenceErrorProvider.overrideWith(PersistenceError.new),
      finalSaveBusyProvider.overrideWith(PersistenceError.new),
      if (repository != null)
        onboardingRepositoryProvider.overrideWithValue(repository!),
      if (initial != null)
        initialOnboardingProvider.overrideWithValue(initial!),
    ],
    child: const _App(),
  );
}

class _App extends ConsumerStatefulWidget {
  const _App();
  @override
  ConsumerState<_App> createState() => _AppState();
}

class _AppState extends ConsumerState<_App> {
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    final initial = ref.read(onboardingControllerProvider);
    _router = GoRouter(
      initialLocation: _location(initial.step),
      errorBuilder: (context, state) => const RecoveryScreen(),
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => WelcomeScreen(
            onStart: () =>
                ref.read(onboardingControllerProvider.notifier).advance(),
            onLogin: () => context.push('/login'),
          ),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingFlow(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginEntryScreen(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => LoginEntryScreen(
            recoveryUserId: state.uri.queryParameters['userId'] ?? '',
            recoverySecret: state.uri.queryParameters['secret'] ?? '',
          ),
        ),
        GoRoute(path: '/lesson', redirect: (context, state) => '/home'),
        GoRoute(
          path: '/stories',
          builder: (context, state) => const StoryLibraryScreen(),
        ),
        GoRoute(
          path: '/explanation',
          builder: (context, state) => const ExplanationScreen(),
        ),
        GoRoute(
          path: '/nodes/:id',
          builder: (context, state) =>
              SessionEntryScreen(nodeId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/placement',
          builder: (context, state) =>
              const SessionEntryScreen(nodeId: 'placement', placement: true),
        ),
        GoRoute(
          path: '/onboarding/demo',
          builder: (context, state) =>
              const SessionEntryScreen(nodeId: 'demo', guest: true),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              LearningShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) =>
                      const SafeArea(child: LearningPath()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/practice',
                  builder: (context, state) => const PracticeHubScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/quests',
                  builder: (context, state) => const QuestsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/league',
                  builder: (context, state) => const LeagueScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile/me',
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/lesson/:id',
          builder: (context, state) => const LessonScreen(),
        ),
        GoRoute(
          path: '/results/:completionId',
          builder: (context, state) => const LessonResults(),
        ),
        GoRoute(
          path: '/courses',
          builder: (context, state) => const CoursesScreen(),
        ),
        GoRoute(
          path: '/units/:id/guide',
          builder: (context, state) => const UnitGuideScreen(),
        ),
        GoRoute(
          path: '/score',
          builder: (context, state) => const ScoreScreen(),
        ),
        GoRoute(
          path: '/sections',
          builder: (context, state) => const SectionsScreen(),
        ),
        GoRoute(
          path: '/sections/:section',
          builder: (context, state) => SectionDetailScreen(
            section: (int.tryParse(state.pathParameters['section'] ?? '') ?? 1)
                .clamp(1, 4),
          ),
        ),
        GoRoute(
          path: '/energy',
          builder: (context, state) => const EnergyScreen(),
        ),
        GoRoute(
          path: '/super',
          builder: (context, state) => const SuperScreen(),
        ),
        GoRoute(
          path: '/super/tour',
          builder: (context, state) => const SuperTourScreen(),
        ),
        GoRoute(
          path: '/max',
          redirect: (context, state) =>
              ref.read(extendedControllerProvider).isMax ? '/max/tour' : null,
          builder: (context, state) => const MaxScreen(),
        ),
        GoRoute(
          path: '/max/tour',
          builder: (context, state) => const MaxTourScreen(),
        ),
        GoRoute(
          path: '/subscription',
          builder: (context, state) => const SubscriptionScreen(),
        ),
        GoRoute(
          path: '/subscription/cancel',
          builder: (context, state) => const CancelSubscriptionScreen(),
        ),
        GoRoute(
          path: '/subscription/family',
          builder: (context, state) => const FamilySubscriptionScreen(),
        ),
        GoRoute(
          path: '/subscription/family/invite',
          builder: (context, state) => const FamilyPlanScreen(),
        ),
        GoRoute(
          path: '/streak',
          builder: (context, state) => const StreakScreen(),
        ),
        GoRoute(
          path: '/streak/widgets',
          builder: (context, state) => const StreakWidgetsScreen(),
        ),
        GoRoute(
          path: '/year-review',
          builder: (context, state) => const YearReviewScreen(),
        ),
        GoRoute(
          path: '/league/results',
          builder: (context, state) => LeagueResultScreen(
            onFinished: () =>
                context.canPop() ? context.pop() : context.go('/league'),
          ),
        ),
        GoRoute(
          path: '/streak/invite',
          builder: (context, state) => const FriendStreakInviteScreen(),
        ),
        GoRoute(
          path: '/achievements',
          builder: (context, state) => AchievementsScreen(
            profileId: state.uri.queryParameters['profile'],
          ),
        ),
        GoRoute(
          path: '/achievements/:id',
          builder: (context, state) => AchievementDetailScreen(
            achievementId: state.pathParameters['id']!,
            profileId: state.uri.queryParameters['profile'],
          ),
        ),
        GoRoute(
          path: '/badges',
          builder: (context, state) => const MonthlyBadgesScreen(),
        ),
        GoRoute(
          path: '/clash',
          builder: (context, state) => const ClashScreen(),
        ),
        GoRoute(path: '/shop', builder: (context, state) => const ShopScreen()),
        GoRoute(
          path: '/timer-boost/success',
          builder: (context, state) => TimerBoostSuccessScreen(
            challenge: state.uri.queryParameters['return'] == 'challenge',
          ),
        ),
        GoRoute(
          path: '/friends',
          builder: (context, state) => const FriendsScreen(),
        ),
        GoRoute(
          path: '/activity',
          builder: (context, state) => const FeedScreen(),
        ),
        GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
        GoRoute(
          path: '/feed/learning',
          builder: (context, state) => const FeedLearningScreen(),
        ),
        GoRoute(
          path: '/profile/courses',
          builder: (context, state) => const ProfileCoursesScreen(),
        ),
        GoRoute(
          path: '/profile/friends',
          builder: (context, state) => ProfileFriendsScreen(
            initialTab: state.uri.queryParameters['tab'] == 'followers'
                ? ProfileFriendsTab.followers
                : ProfileFriendsTab.following,
          ),
        ),
        GoRoute(
          path: '/profile/:userId',
          builder: (context, state) =>
              ProfileScreen(userId: state.pathParameters['userId']!),
        ),
        GoRoute(
          path: '/practice/:kind',
          builder: (context, state) =>
              PracticeDetailScreen(kind: state.pathParameters['kind']!),
        ),
        GoRoute(
          path: '/journeys/:kind',
          builder: (context, state) =>
              JourneyEntryScreen(kind: state.pathParameters['kind']!),
        ),
        GoRoute(
          path: '/challenges/:kind',
          builder: (context, state) => ChallengeIntroScreen(
            kind: state.pathParameters['kind'] == 'legendary'
                ? 'legendary'
                : 'rapid',
          ),
        ),
        GoRoute(
          path: '/adventures/passport',
          builder: (context, state) => const AdventureScreen(),
        ),
        GoRoute(
          path: '/journeys/:kind/session',
          builder: (context, state) =>
              JourneyScreen(kind: state.pathParameters['kind']!),
        ),
        GoRoute(
          path: '/journeys/roleplay/feedback',
          builder: (context, state) => const RoleplayFeedbackScreen(),
        ),
        GoRoute(
          path: '/speaking/record',
          builder: (context, state) => const SpeakingRecordScreen(),
        ),
        GoRoute(
          path: '/speaking/call',
          builder: (context, state) => const SpeakingCallScreen(),
        ),
        GoRoute(
          path: '/speaking/result/:id',
          builder: (context, state) => const SpeakingResultScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (context, state) => const RegistrationScreen(),
        ),
        GoRoute(
          path: '/auth/verify',
          builder: (context, state) => const VerificationScreen(),
        ),
        GoRoute(path: '/auth/login', redirect: (context, state) => '/login'),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/courses',
          builder: (context, state) => const CourseManagementScreen(),
        ),
        GoRoute(
          path: '/settings/profile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/settings/avatar',
          builder: (context, state) => const AvatarBuilderScreen(),
        ),
        GoRoute(
          path: '/settings/password',
          builder: (context, state) => const PasswordChangeScreen(),
        ),
        GoRoute(
          path: '/settings/reminders',
          builder: (context, state) => const ReminderScreen(),
        ),
        GoRoute(
          path: '/account/delete',
          builder: (context, state) => const DeleteAccountScreen(),
        ),
        GoRoute(path: '/sync', builder: (context, state) => const SyncScreen()),
        GoRoute(
          path: '/recovery',
          builder: (context, state) => const RecoveryScreen(),
        ),
      ],
    );
  }

  String _location(OnboardingStep step) => switch (step) {
    OnboardingStep.welcome => '/welcome',
    OnboardingStep.lessonEntry => '/home',
    _ => '/onboarding',
  };
  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onboardingControllerProvider, (previous, next) {
      if (previous?.step != next.step &&
          _location(previous?.step ?? OnboardingStep.welcome) !=
              _location(next.step)) {
        _router.go(_location(next.step));
      }
    });
    return MaterialApp.router(
      title: 'CocEnglish',
      debugShowCheckedModeBanner: false,
      theme: referenceTheme(),
      routerConfig: _router,
    );
  }
}
