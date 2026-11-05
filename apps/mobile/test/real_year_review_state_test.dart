import 'dart:async';

import 'package:cocenglish/core/config/app_config.dart';
import 'package:cocenglish/features/progress/application/year_review_controller.dart';
import 'package:cocenglish/features/progress/domain/year_review.dart';
import 'package:cocenglish/features/progress/presentation/year_review_screen.dart';
import 'package:cocenglish/core/design/reference_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingReview implements YearReviewRepository {
  final pending = Completer<YearReviewSnapshot>();
  @override
  Future<YearReviewSnapshot> load() => pending.future;
}

class _RetryReview implements YearReviewRepository {
  bool fail = true;
  @override
  Future<YearReviewSnapshot> load() async {
    if (fail) throw StateError('offline');
    return historical2025;
  }
}

void main() {
  testWidgets(
    'an unavailable real review shows retry without the demo slides',
    (tester) async {
      final repository = _RetryReview();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          yearReviewRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: referenceTheme(),
            home: const YearReviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(yearReviewControllerProvider).hasSnapshot, isFalse);
      expect(find.text('RETRY'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      repository.fail = false;
      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();
      expect(container.read(yearReviewControllerProvider).hasSnapshot, isTrue);
      expect(find.byType(PageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('real review cannot share historical demo data while loading or after failure', () async {
    final repository = _PendingReview();
    final copied = <String>[];
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(dataSource: DataSource.api),
        ),
        yearReviewRepositoryProvider.overrideWithValue(repository),
        yearReviewClipboardWriterProvider.overrideWithValue(
          (text) async => copied.add(text),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(yearReviewControllerProvider, (_, _) {});
    final controller = container.read(yearReviewControllerProvider.notifier);
    expect(await controller.share(), isFalse);
    expect(copied, isEmpty);
    repository.pending.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(await controller.share(), isFalse);
    expect(copied, isEmpty);
  });

  test(
    'sharing a small real XP total does not throw or fabricate digits',
    () async {
      final repository = _PendingReview();
      String? copied;
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(dataSource: DataSource.api),
          ),
          yearReviewRepositoryProvider.overrideWithValue(repository),
          yearReviewClipboardWriterProvider.overrideWithValue(
            (text) async => copied = text,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(yearReviewControllerProvider, (_, _) {});
      repository.pending.complete(
        YearReviewSnapshot(
          year: 2025,
          course: 'English',
          lessons: 5,
          totalXp: 90,
          percentile: 0,
          studentTopPercent: 0,
          league: '',
          leagueWeeks: 0,
          englishScore: 0,
          longestStreak: 2,
          minutesSpent: 3,
          asOf: DateTime(2025, 12, 31),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        await container.read(yearReviewControllerProvider.notifier).share(),
        isTrue,
      );
      expect(copied, contains('90 XP'));
      expect(copied, isNot(contains('12,949')));
    },
  );
}
