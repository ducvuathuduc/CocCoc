import 'lesson_journal.dart';
import 'lesson_journal_platform_stub.dart'
    if (dart.library.io) 'lesson_journal_platform_native.dart'
    as platform;

LessonJournal createDurableLessonJournal({required String namespace}) =>
    platform.createDurableLessonJournal(namespace: namespace);
