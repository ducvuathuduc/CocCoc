import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cocenglish/features/vocabulary/application/notebook_controller.dart';
import 'package:cocenglish/features/vocabulary/data/notebook_repository.dart';
import 'package:cocenglish/features/vocabulary/domain/vocabulary_card.dart';
import 'package:cocenglish/features/vocabulary/presentation/notebook_screen.dart';
import 'package:cocenglish/features/learning/application/learning_controller.dart';
import 'package:cocenglish/features/learning/data/learning_repository.dart';
import 'package:cocenglish/features/learning/domain/learning_models.dart';
import 'package:cocenglish/features/learning/presentation/lesson_screen.dart';

void main() {
  testWidgets(
    'lesson exposes save after feedback and prefills authored phrase',
    (tester) async {
      String? disk;
      final repo = NotebookRepository(
        read: () async => disk,
        write: (v) async {
          disk = v;
        },
      );
      final container = ProviderContainer(
        overrides: [
          notebookRepositoryProvider.overrideWith((ref) async => repo),
          learningRepositoryProvider.overrideWithValue(
            MockLearningRepository(delay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(lessonControllerProvider.notifier);
      await controller.start(
        exercises: const [
          Exercise(
            id: 'saved-phrase',
            kind: ExerciseKind.textTranslation,
            title: 'Translate',
            prompt: 'Xin chào',
            correctText: 'Hello',
            meaning: 'Xin chào',
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LessonScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SAVE TO MY VOCABULARY'), findsNothing);
      controller.updateText('Hello');
      final checked = controller.check();
      await tester.pumpAndSettle();
      await checked;
      await tester.tap(find.text('SAVE TO MY VOCABULARY'));
      await tester.pumpAndSettle();
      expect(find.text('Save vocabulary'), findsOneWidget);
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect((await repo.load()).single.term, 'Hello');
      expect((await repo.load()).single.meaning, 'Xin chào');
      expect(tester.takeException(), isNull);
    },
  );
  for (final correct in [true, false]) {
    testWidgets(
      'review ${correct ? 'correct advances' : 'wrong resets'} without a hint',
      (tester) async {
        String? disk;
        final repo = NotebookRepository(
          read: () async => disk,
          write: (v) async {
            disk = v;
          },
        );
        final old = VocabularyCard(
          id: 'hello',
          term: 'Hello',
          meaning: 'Xin chào',
          example: '',
          stage: 2,
          dueAt: DateTime.utc(2020),
        );
        await repo.save(old);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notebookRepositoryProvider.overrideWith((ref) async => repo),
            ],
            child: MaterialApp(home: VocabularyReviewScreen(cards: [old])),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          correct ? 'Xin chào' : 'wrong',
        );
        await tester.tap(find.text('CHECK'));
        await tester.pumpAndSettle();
        final stored = (await repo.load()).single;
        expect(stored.stage, correct ? 3 : 0);
        final today = DateTime.now().toUtc();
        expect(
          stored.dueAt,
          DateTime.utc(today.year, today.month, today.day + (correct ? 7 : 1)),
        );
        expect(find.text('CHECK'), findsNothing);
      },
    );
  }
  testWidgets(
    'empty notebook, validate add, persist and remove at text scale 2',
    (tester) async {
      String? disk;
      final repo = NotebookRepository(
        read: () async => disk,
        write: (v) async {
          disk = v;
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notebookRepositoryProvider.overrideWith((ref) async => repo),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const NotebookScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Your notebook is empty'), findsOneWidget);
      await tester.tap(find.text('ADD WORD OR PHRASE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a word/phrase and its meaning.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Hello');
      await tester.enterText(find.byType(TextField).at(1), 'Xin chào');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect((await repo.load()).single.term, 'Hello');
      await tester.ensureVisible(find.byTooltip('Remove Hello'));
      await tester.tap(find.byTooltip('Remove Hello'));
      await tester.pumpAndSettle();
      expect(await repo.load(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'hinted correct review resets stage, saves once and shows example',
    (tester) async {
      String? disk;
      final repo = NotebookRepository(
        read: () async => disk,
        write: (v) async {
          disk = v;
        },
      );
      final old = VocabularyCard(
        id: 'hello',
        term: 'Hello',
        meaning: 'Xin chào',
        example: 'Hello, Sam!',
        stage: 3,
        dueAt: DateTime.utc(2020),
      );
      await repo.save(old);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notebookRepositoryProvider.overrideWith((ref) async => repo),
          ],
          child: MaterialApp(home: VocabularyReviewScreen(cards: [old])),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('HINT'));
      await tester.enterText(find.byType(TextField), 'Xin chào');
      await tester.tap(find.text('CHECK'));
      await tester.pumpAndSettle();
      expect((await repo.load()).single.stage, 0);
      expect(find.textContaining('Hello, Sam!'), findsOneWidget);
      expect(find.text('CHECK'), findsNothing);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No XP awarded'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('load error offers retry without exposing empty success state', (
    tester,
  ) async {
    final repo = NotebookRepository(
      read: () async => throw StateError('disk'),
      write: (_) async {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notebookRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: const MaterialApp(home: NotebookScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cannot load notebook. Retry'), findsOneWidget);
    expect(find.textContaining('Your notebook is empty'), findsNothing);
  });
}
