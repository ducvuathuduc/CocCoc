import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'drift_lesson_journal.dart';
import 'lesson_journal.dart';

LessonJournal createDurableLessonJournal({required String namespace}) =>
    DriftLessonJournal(
      namespace: namespace,
      executor: driftDatabase(
        name: 'cocenglish_lesson_journal',
        native: const DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
        ),
      ),
      legacy: PreferencesLegacyLessonJournalSource(namespace: namespace),
    );
