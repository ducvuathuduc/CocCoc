import 'dart:typed_data';

import 'lesson_audio_store.dart';

/// Web build: never under `flutter test`.
bool get runningUnderFlutterTest => false;

/// Web build: no file cache, so only clips shipped with the app play.
class LessonAudioDiskCache implements LessonAudioCache {
  @override
  Future<CachedClip?> read(String sha256) async => null;

  @override
  Future<String?> write(String sha256, Uint8List bytes) async => null;
}
