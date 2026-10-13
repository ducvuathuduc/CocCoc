import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'lesson_audio_store.dart';

/// Whether this isolate runs under `flutter test` (no audio plugin there).
bool get runningUnderFlutterTest =>
    Platform.environment.containsKey('FLUTTER_TEST');

/// `<application support>/lesson_audio/<sha256>.aac`; nothing is cached when
/// the platform has no support directory (e.g. widget tests).
class LessonAudioDiskCache implements LessonAudioCache {
  Future<Directory?>? _dir;

  Future<Directory?> _directory() => _dir ??= () async {
    try {
      final base = await getApplicationSupportDirectory();
      return await Directory('${base.path}/lesson_audio')
          .create(recursive: true);
    } on Object {
      return null;
    }
  }();

  @override
  Future<CachedClip?> read(String sha256) async {
    final dir = await _directory();
    if (dir == null) return null;
    final file = File('${dir.path}/$sha256.aac');
    try {
      return await file.exists()
          ? CachedClip(file.path, await file.readAsBytes())
          : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> write(String sha256, Uint8List bytes) async {
    final dir = await _directory();
    if (dir == null) return null;
    final file = File('${dir.path}/$sha256.aac');
    final temp = File('${file.path}.part');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      return file.path;
    } on Object {
      return null;
    }
  }
}
