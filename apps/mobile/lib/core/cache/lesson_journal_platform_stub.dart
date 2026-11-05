import 'lesson_journal.dart';

LessonJournal createDurableLessonJournal({required String namespace}) =>
    const UnavailableLessonJournal(JournalFailure.storageUnavailable);
