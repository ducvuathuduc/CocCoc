import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:cocenglish/core/design/reference_widgets.dart';
import 'package:cocenglish/core/cache/snapshot_cache.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/practice/application/mistake_history_controller.dart';
import 'package:cocenglish/features/practice/data/mistake_history_repository.dart';
import 'package:cocenglish/features/practice/presentation/practice_screens.dart';

class WaitingHistory extends MistakeHistoryRepository {
  WaitingHistory(this.result) : super(store: MemorySnapshotStore());
  final Future<MistakeHistory> result;
  @override
  Future<MistakeHistory> load() => result;
}

void main() {
  testWidgets(
    'persisted questions open a capped demo review at text scale two',
    (tester) async {
      final history = MistakeHistoryRepository(store: MemorySnapshotStore());
      await history.record('original', [
        for (var i = 0; i < 25; i++)
          MistakeEvidence(
            Exercise(
              id: 'saved-$i',
              kind: ExerciseKind.textTranslation,
              title: 'Translate',
              prompt: 'Question $i',
              correctText: 'Hello',
            ),
            correct: false,
            assisted: false,
          ),
      ], review: false);
      final container = ProviderContainer(
        overrides: [mistakeRepositoryProvider.overrideWithValue(history)],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/practice/mistakes',
        routes: [
          GoRoute(
            path: '/practice/mistakes',
            builder: (_, _) => const PracticeDetailScreen(kind: 'mistakes'),
          ),
          GoRoute(
            path: '/lesson/practice',
            builder: (_, _) => const Scaffold(body: Text('REVIEW OPEN')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('25 questions to review'), findsOneWidget);
      await tester.ensureVisible(find.text('REVIEW MISTAKES'));
      await tester.tap(find.text('REVIEW MISTAKES'));
      await tester.pumpAndSettle();
      expect(find.text('REVIEW OPEN'), findsOneWidget);
      final lesson = container.read(lessonControllerProvider);
      expect(lesson.exercises, hasLength(20));
      expect(lesson.guest, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('loading is distinct from empty and storage errors offer retry', (
    tester,
  ) async {
    final result = Completer<MistakeHistory>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mistakeRepositoryProvider.overrideWithValue(
            WaitingHistory(result.future),
          ),
        ],
        child: const MaterialApp(home: PracticeDetailScreen(kind: 'mistakes')),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No mistakes to review'), findsNothing);
    result.completeError(StateError('disk'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load saved mistakes. Please retry.'),
      findsOneWidget,
    );
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('No mistakes to review'), findsNothing);
  });
  testWidgets(
    'empty history offers learning and offline data stays clearly marked',
    (tester) async {
      final history = MistakeHistoryRepository(store: MemorySnapshotStore());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mistakeRepositoryProvider.overrideWithValue(history)],
          child: const MaterialApp(
            home: PracticeDetailScreen(kind: 'mistakes'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CONTINUE LEARNING'), findsOneWidget);
      expect(find.text('REVIEW MISTAKES'), findsNothing);
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('offline'),
          overrides: [
            mistakeRepositoryProvider.overrideWithValue(
              WaitingHistory(
                Future.value(
                  MistakeHistory([
                    SavedMistake(
                      id: 'server',
                      skill: 'greeting',
                      count: 1,
                      at: DateTime.utc(2026),
                    ),
                  ], offline: true),
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: PracticeDetailScreen(kind: 'mistakes'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline copy.'), findsOneWidget);
      final button = tester.widget<ReferenceButton>(
        find.byWidgetPredicate(
          (w) => w is ReferenceButton && w.label == 'REVIEW MISTAKES',
        ),
      );
      expect(find.text('REVIEW MISTAKES'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Offline CTA must not navigate, even when tapped.
      await tester.tap(find.text('REVIEW MISTAKES'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline copy.'), findsOneWidget);
      expect(button.onPressed, isNull);
    },
  );
}
