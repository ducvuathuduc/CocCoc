import 'dart:io';
import 'dart:ui' as ui;

import 'package:cocenglish/core/design/reference_art.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:cocenglish/features/account/application/registration_controller.dart';
import 'package:cocenglish/features/account/presentation/account_screens.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/learning_path.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';
import 'package:cocenglish/features/learning/presentation/lesson_results.dart';
import 'package:cocenglish/features/learning/presentation/session_entry.dart';
import 'package:cocenglish/features/practice/presentation/practice_screens.dart';
import 'package:cocenglish/features/progress/application/preview_controller.dart';
import 'package:cocenglish/features/progress/presentation/hub_screens.dart';
import 'package:cocenglish/features/progress/presentation/streak_screen.dart';
import 'package:cocenglish/features/onboarding/domain/onboarding_state.dart';
import 'package:cocenglish/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_comparison.dart';

const capture = bool.fromEnvironment('CAPTURE_UI');
typedef Setup = Future<void> Function(ProviderContainer);
typedef Fixture = ({
  String name,
  Widget screen,
  Setup? setup,
  String? source,
  int? number,
});
Future<void> ranked(ProviderContainer c) async =>
    c.read(previewControllerProvider.notifier).optIntoLeague();
Future<void> friends(ProviderContainer c) async =>
    c.read(previewControllerProvider.notifier).follow('Alex');
Future<void> deletion(ProviderContainer c) async =>
    c.read(previewControllerProvider.notifier).requestDeletion();
Future<void> questHub(ProviderContainer c) async =>
    c.read(previewControllerProvider.notifier).dismissQuestIntro();
Fixture page(
  String name,
  Widget screen, {
  Setup? setup,
  String? source,
  int? number,
}) =>
    (name: name, screen: screen, setup: setup, source: source, number: number);
List<Fixture> fixtures() => [
  page(
    'path',
    const Scaffold(body: SafeArea(child: LearningPath())),
    source: 'lesson',
    number: 1,
  ),
  page('guide', const UnitGuideScreen(), source: 'guide', number: 2),
  page('practice', const PracticeHubScreen(), source: 'practice', number: 4),
  for (final kind in ['words', 'mistakes', 'listen', 'speak'])
    page('practice-$kind', PracticeDetailScreen(kind: kind)),
  page('record', const SpeakingRecordScreen()),
  page('call', const SpeakingCallScreen()),
  page('speech-result', const SpeakingResultScreen()),
  page('quests', const QuestsScreen(), source: 'quests', number: 2),
  page(
    'quests-hub',
    const QuestsScreen(),
    setup: questHub,
    source: 'quests',
    number: 3,
  ),
  page('league-locked', const LeagueScreen(), source: 'league', number: 2),
  page(
    'league-ranked',
    const LeagueScreen(),
    setup: ranked,
    source: 'league',
    number: 5,
  ),
  page('profile', const ProfileScreen(), source: 'profile', number: 6),
  page('public-profile', const ProfileScreen(userId: 'Alex')),
  page('friends', const FriendsScreen(), source: 'friends', number: 2),
  page('activity-empty', const ActivityScreen()),
  page('activity', const ActivityScreen(), setup: friends),
  page('shop', const ShopScreen(), source: 'shop', number: 2),
  page('courses', const CoursesScreen()),
  page('score', const ScoreScreen()),
  page('streak', const StreakScreen()),
  page('register-age', const RegistrationScreen(), source: 'signup', number: 2),
  for (var step = 1; step <= 3; step++)
    page(
      'register-$step',
      const RegistrationScreen(),
      setup: (c) async {
        final vm = c.read(registrationControllerProvider.notifier);
        vm.edit(age: '25');
        await vm.next();
        if (step > 1) {
          vm.edit(first: 'Sam', last: 'Lee');
          await vm.next();
        }
        if (step > 2) {
          vm.edit(email: 'sam@example.test');
          await vm.next();
        }
      },
      source: 'signup',
      number: [0, 4, 6, 9][step],
    ),
  page('verify', const VerificationScreen()),
  page('settings', const SettingsScreen(), source: 'settings', number: 2),
  page('edit-profile', const EditProfileScreen()),
  page('reminder', const ReminderScreen()),
  page('sync', const SyncScreen()),
  page('recovery', const RecoveryScreen()),
  page('delete', const DeleteAccountScreen(), source: 'delete', number: 4),
  page(
    'delete-receipt',
    const DeleteAccountScreen(),
    setup: deletion,
    source: 'delete',
    number: 6,
  ),
  page(
    'placement',
    const SessionEntryScreen(nodeId: 'placement', placement: true),
  ),
  page('demo', const SessionEntryScreen(nodeId: 'demo', guest: true)),
  page('locked-node', const SessionEntryScreen(nodeId: 'node-7')),
  for (final exercise in [...mockEnglishExercises, ...mockPracticeExercises])
    page(
      'exercise-${exercise.kind.name}',
      const LessonScreen(),
      setup: (c) => c
          .read(lessonControllerProvider.notifier)
          .start(exercises: [exercise]),
      source: exercise.kind == ExerciseKind.imageChoice ? 'lesson' : null,
      number: exercise.kind == ExerciseKind.imageChoice ? 3 : null,
    ),
  for (var step = 0; step < 7; step++)
    page(
      'results-$step',
      const LessonResults(),
      setup: (c) async {
        final vm = c.read(lessonControllerProvider.notifier);
        await vm.start(exercises: [mockEnglishExercises[0]]);
        vm.select('woman');
        await vm.check();
        await vm.next();
        if (step > 0) {
          await vm.claim();
          for (var i = 0; i < step; i++) {
            vm.nextResult();
          }
        }
      },
    ),
];

void main() {
  for (final size in const [Size(360, 800), Size(430, 932)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'all frontend states render at ${size.width.toInt()} / text $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          for (final f in fixtures()) {
            final c = ProviderContainer(
              overrides: [
                learningRepositoryProvider.overrideWithValue(
                  MockLearningRepository(delay: Duration.zero),
                ),
              ],
            );
            if (f.setup != null) {
              await tester.runAsync(() => f.setup!(c));
            }
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: c,
                child: MaterialApp(
                  theme: referenceTheme(),
                  home: f.screen,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: f.name);
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
            c.dispose();
          }
        },
      );
    }
  }
  testWidgets(
    'five tabs preserve path, words reveal, and shop rejects insufficient funds',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MainApp(
          initial: OnboardingState(
            step: OnboardingStep.lessonEntry,
            language: 'French',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Shop'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('GET FOR 200 GEMS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GET FOR 200 GEMS'));
      await tester.pumpAndSettle();
      expect(find.text('Not enough gems'), findsOneWidget);
      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Practice'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Words'));
      await tester.tap(find.text('Words'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START PRACTICE'));
      await tester.pumpAndSettle();
      expect(find.text('REVEAL ANSWER'), findsOneWidget);
      await tester.tap(find.text('REVEAL ANSWER'));
      await tester.pumpAndSettle();
      expect(find.text('I REMEMBER THIS'), findsOneWidget);
      await tester.tap(find.text('I REMEMBER THIS'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Use basic phrases'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('monthly quest introduction continues once into daily quests', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    Widget app() => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: referenceTheme(), home: const QuestsScreen()),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Earn 30 quest points this month\nto claim your October Badge!',
      ),
      findsOneWidget,
    );
    expect(find.text('Earn 20 XP'), findsNothing);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Earn 20 XP'));
    expect(find.text('Earn 20 XP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('capture analyzed frontend states with original fonts', (
    tester,
  ) async {
    if (!capture) return;
    final comparisons = <String, UiComparison>{};
    tester.view.physicalSize = const Size(1180, 2556);
    tester.view.devicePixelRatio = 1180 / 390;
    tester.view.padding = const FakeViewPadding(
      top: 59 * 1180 / 390,
      bottom: 34 * 1180 / 390,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.runAsync(() async {
      await (FontLoader('DuolingoSans')
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans.ttf'))
            ..addFont(rootBundle.load('assets/fonts/DuolingoSans-Bold.ttf')))
          .load();
      await (FontLoader(
        'Feather',
      )..addFont(rootBundle.load('assets/fonts/Feather.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await ReferenceArt.preload();
      await ReferenceArt.preloadFiles([
        'lesson-01',
        'lesson-03',
        'lesson-05',
        'lesson-07',
        'lesson-12',
        'lesson-16',
        'lesson-18',
        'lesson-20',
        'lesson-21',
        'results-02',
        'results-03',
        'guide-02',
        'practice-01',
        'practice-04',
        'practice-05',
        'quests-02',
        'quests-03',
        'league-02',
        'league-05',
        'profile-06',
        'shop-02',
        'signup-15',
        'delete-06',
      ]);
    });
    for (final f in fixtures()) {
      var width = 1180.0, height = 2556.0;
      if (f.source != null) {
        final bytes = await tester.runAsync(
          () => File(
            '../../docs/design/references/${f.source}/${f.number!.toString().padLeft(2, '0')}.png',
          ).readAsBytes(),
        );
        final header = ByteData.sublistView(bytes!);
        width = header.getUint32(16).toDouble();
        height = header.getUint32(20).toDouble();
      }
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = width / 390;
      tester.view.padding = FakeViewPadding(
        top: 59 * width / 390,
        bottom: 34 * width / 390,
      );
      final c = ProviderContainer(
        overrides: [
          learningRepositoryProvider.overrideWithValue(
            MockLearningRepository(delay: Duration.zero),
          ),
        ],
      );
      if (f.setup != null) {
        await tester.runAsync(() => f.setup!(c));
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: referenceTheme(),
              debugShowCheckedModeBanner: false,
              home: f.name == 'path'
                  ? MainApp(
                      initial: OnboardingState(
                        step: OnboardingStep.lessonEntry,
                        language: 'French',
                      ),
                    )
                  : f.screen,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: f.name);
      await tester.runAsync(
        () => ReferenceArt.preloadFiles(
          tester
              .widgetList<ReferenceArt>(find.byType(ReferenceArt))
              .map((art) => art.region.file),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final img = await render.toImage(pixelRatio: width / 390),
            data = (await img.toByteData(format: ui.ImageByteFormat.png))!;
        final file = File('../../docs/design/qa/frontend/${f.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data.buffer.asUint8List());
        if (f.source != null) {
          final comp = comparisons.putIfAbsent(
            f.source!,
            () => UiComparison(flow: f.source!),
          );
          await comp.compare(f.number!, img);
        }
        img.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      c.dispose();
    }
    await tester.runAsync(() async {
      for (final entry in comparisons.entries) {
        await Directory('../../docs/design/qa/${entry.key}')
            .create(recursive: true);
        await entry.value.write();
      }
    });
  });
}
